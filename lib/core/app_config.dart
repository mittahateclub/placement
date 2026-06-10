import 'package:shared_preferences/shared_preferences.dart';

/// Runtime configuration. The Groq API key powers the AI resume builder.
///
/// Resolution order:
///  1. `--dart-define=GROQ_API_KEY=...` at build time
///  2. Key pasted in-app (Settings sheet), stored locally on the device.
class AppConfig {
  AppConfig._();

  static const String _envKey = String.fromEnvironment('GROQ_API_KEY');
  static const String _prefsKey = 'groq_api_key';

  static String _storedKey = '';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _storedKey = prefs.getString(_prefsKey) ?? '';
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
