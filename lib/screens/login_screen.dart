import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/theme_controller.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';
import '../widgets/loading_dots.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _error = '';
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await context
          .read<AuthService>()
          .signIn(_email.text.trim(), _password.text);
      // AuthGate reacts to the auth state change.
    } on FirebaseAuthException catch (e) {
      setState(() => _error = switch (e.code) {
            'too-many-requests' =>
              'Too many attempts. Please try again later.',
            'network-request-failed' =>
              'Network error. Check your connection.',
            _ => 'Invalid email or password.',
          });
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = context.watch<ThemeController>();

    return Scaffold(
      body: Stack(
        children: [
          // Subtle radial accent glow behind the card.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 1.1,
                  colors: [
                    AppColors.accent.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Container(
                        width: 76,
                        height: 76,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.25)),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.18),
                              blurRadius: 24,
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: Image.asset('assets/logo.png',
                            fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'UNISHIP',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sign in to your Uniship account',
                        style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurface.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(height: 28),
                      SurfaceCard(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_error.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.all(11),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppColors.danger
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(_error,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.danger,
                                          fontWeight: FontWeight.w500)),
                                ),
                                const SizedBox(height: 16),
                              ],
                              const FieldLabel('Email'),
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  hintText: 'you@university.edu',
                                  prefixIcon:
                                      Icon(Icons.mail_outline_rounded, size: 18),
                                ),
                                validator: (v) =>
                                    (v == null || !v.contains('@'))
                                        ? 'Enter a valid email'
                                        : null,
                              ),
                              const SizedBox(height: 16),
                              const FieldLabel('Password'),
                              TextFormField(
                                controller: _password,
                                obscureText: _obscure,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) => _login(),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                      size: 18),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Enter your password'
                                    : null,
                              ),
                              const SizedBox(height: 22),
                              FilledButton(
                                onPressed: _loading ? null : _login,
                                child: _loading
                                    ? const SizedBox(
                                        height: 20, child: LoadingDots(size: 6))
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text('SIGN IN'),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward_rounded,
                                              size: 16),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'POWERED BY UNISHIP',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Theme toggle
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton(
                tooltip: theme.isDark ? 'Light mode' : 'Dark mode',
                onPressed: theme.toggle,
                icon: Icon(
                  theme.isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
