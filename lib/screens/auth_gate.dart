import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../widgets/loading_dots.dart';
import 'home_shell.dart';
import 'login_screen.dart';

/// Routes between login and the role-specific home shell.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.loading) {
      return const Scaffold(body: CenteredLoader());
    }
    if (auth.user == null) {
      return const LoginScreen();
    }
    return HomeShell(key: ValueKey(auth.user!.uid));
  }
}
