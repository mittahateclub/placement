import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runtime configuration. The Groq API key powers the AI resume builder
/// and the event link auto-fill.
///
/// Resolution order:
///  1. `--dart-define=GROQ_API_KEY=...` at build time (env.json)
///  2. Key cached on the device from a previous run
///  3. Shared `config/app` Firestore doc (same key the web app uses) —
///     fetched after sign-in, then cached, so installs without build
///     flags still work.
class AppConfig {
  AppConfig._();

  static const String _envKey = String.fromEnvironment('GROQ_API_KEY');
  static const String _prefsKey = 'groq_api_key';

  static String _storedKey = '';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Persist the build-time key so later runs launched WITHOUT
    // --dart-define-from-file (e.g. the IDE run button) still have it.
    if (_envKey.isNotEmpty && prefs.getString(_prefsKey) != _envKey) {
      await prefs.setString(_prefsKey, _envKey);
    }
    _storedKey = prefs.getString(_prefsKey) ?? '';
  }

  /// Call once the user is signed in. Pulls the shared key from Firestore
  /// when this install has none; seeds the doc when this install has the
  /// key and the doc doesn't exist yet (requires the `config` rules).
  static Future<void> syncRemoteKey() async {
    try {
      final ref =
          FirebaseFirestore.instance.collection('config').doc('app');
      final doc = await ref.get();
      final remote = (doc.data()?['groqApiKey'] as String?)?.trim() ?? '';
      if (remote.isNotEmpty) {
        if (!hasGroqKey) await setGroqApiKey(remote);
      } else if (hasGroqKey) {
        await ref.set({
          'groqApiKey': groqApiKey,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      // Doc missing or rules don't allow it yet — features that need the
      // key surface their own message.
    }
  }

  static String get groqApiKey =>
      _envKey.isNotEmpty ? _envKey : _storedKey;

  static bool get hasGroqKey => groqApiKey.isNotEmpty;

  static Future<void> setGroqApiKey(String key) async {
    _storedKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _storedKey);
  }
}
