import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_config.dart';
import 'core/app_theme.dart';
import 'core/theme_controller.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // On Android the google-services plugin auto-initializes the default app from
  // google-services.json before Dart runs. That native app already has the
  // correct (Android) config, so if our explicit init collides with it we just
  // keep the existing one instead of crashing with [core/duplicate-app].
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
  await AppConfig.load();
  await NotificationService.init();
  await PushService.init();
  runApp(const UniShipApp());
}

class UniShipApp extends StatelessWidget {
  const UniShipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) => MaterialApp(
          title: 'UniShip',
          debugShowCheckedModeBanner: false,
          themeMode: theme.mode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const AuthGate(),
        ),
      ),
    );
  }
}
