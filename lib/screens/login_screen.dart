import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/theme_controller.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';

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
    final isDark = theme.isDark;

    return Scaffold(
      body: Stack(
        children: [
          // A single faint halo behind the logo — only on true-black dark.
          if (isDark)
            Positioned(
              top: -140,
              left: 0,
              right: 0,
              child: Center(
                child: _GlowBlob(
                  color: Colors.white.withValues(alpha: 0.07),
                  size: 420,
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
                      FadeSlideIn(
                        child: Column(
                          children: [
                            Image.asset(
                              isDark
                                  ? 'assets/logo_dark.png'
                                  : 'assets/logo.png',
                              width: 96,
                              height: 96,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'UniShip',
                              style: AppTheme.display(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.1,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Your placement journey, all in one place',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 90),
                        child: SurfaceCard(
                          padding: const EdgeInsets.all(22),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_error.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: AppColors.danger
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded,
                                            size: 16, color: AppColors.danger),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(_error,
                                              style: const TextStyle(
                                                  fontSize: 12.5,
                                                  color: AppColors.danger,
                                                  fontWeight: FontWeight.w500)),
                                        ),
                                      ],
                                    ),
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
                                    prefixIcon: Icon(Icons.mail_outline_rounded,
                                        size: 18),
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
                                GradientButton(
                                  label: 'Sign In',
                                  icon: Icons.arrow_forward_rounded,
                                  loading: _loading,
                                  onPressed: _loading ? null : _login,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 180),
                        child: Text(
                          'POWERED BY UNISHIP',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2.5,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface.withValues(alpha: 0.3),
                          ),
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
                tooltip: isDark ? 'Light mode' : 'Dark mode',
                onPressed: theme.toggle,
                icon: Icon(
                  isDark
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

/// Soft circular gradient glow used as ambient background light.
class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
