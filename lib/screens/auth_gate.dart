import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/loading_dots.dart';
import 'home_shell.dart';
import 'login_screen.dart';

/// Routes between login and the role-specific home shell.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _lastUid;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    // On sign-out, drop any scheduled reminders + in-app badge state.
    if (_lastUid != null && auth.user == null) {
      NotificationService.clear();
    }
    _lastUid = auth.user?.uid;

    if (auth.loading) {
      return const Scaffold(body: CenteredLoader());
    }
    if (auth.user == null) {
      return const LoginScreen();
    }
    return HomeShell(key: ValueKey(auth.user!.uid));
  }
}
