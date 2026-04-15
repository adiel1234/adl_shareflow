import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart'
    if (dart.library.html) 'package:adl_shareflow/core/stubs/apple_stub.dart';

import '../../../../theme/app_colors.dart';
import '../../../../services/auth_service.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../ui/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final l = AppLocalizations.of(context)!;
    try {
      final user = await _authService.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      ref.read(authProvider.notifier).setUser(user);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() { _error = _parseError(e, l); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _loginGoogle() async {
    setState(() { _loading = true; _error = null; });
    final l = AppLocalizations.of(context)!;
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) { setState(() { _loading = false; }); return; }
      final auth = await googleUser.authentication;
      final user = await _authService.loginWithGoogle(auth.idToken!);
      ref.read(authProvider.notifier).setUser(user);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() { _error = _parseError(e, l); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _loginApple() async {
    setState(() { _loading = true; _error = null; });
    final l = AppLocalizations.of(context)!;
    try {
      final cred = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      final displayName = [cred.givenName, cred.familyName]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');
      final user = await _authService.loginWithApple(
        identityToken: cred.identityToken!,
        displayName: displayName.isNotEmpty ? displayName : null,
      );
      ref.read(authProvider.notifier).setUser(user);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() { _error = _parseError(e, l); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  String _parseError(dynamic e, AppLocalizations l) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('Invalid email')) {
      return l.wrongCredentials;
    }
    return l.loginError;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),

              // Logo + Title
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset('assets/icons/app_icon.png'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l.welcomeTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.loginSubtitle,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        hintText: l.email,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return l.emailRequired;
                        if (!v.contains('@')) return l.invalidEmail;
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        hintText: l.password,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return l.passwordRequired;
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              // Forgot password
              Align(
                alignment: Alignment.centerLeft,
                    child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                  child: Text(l.forgotPassword),
                ),
              ),

              // Error
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Login button
              GradientButton(
                label: l.loginBtn,
                onPressed: _loading ? null : _loginEmail,
                isLoading: _loading,
              ),

              const SizedBox(height: 20),

              // Divider
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      l.orDivider,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 20),

              // Social login
              _SocialButton(
                label: l.continueWithGoogle,
                icon: 'assets/icons/google_icon.png',
                fallbackIcon: Icons.g_mobiledata,
                onPressed: _loading ? null : _loginGoogle,
              ),
              const SizedBox(height: 12),

              if (!kIsWeb) ...[
                _SocialButton(
                  label: l.continueWithApple,
                  icon: 'assets/icons/apple_icon.png',
                  fallbackIcon: Icons.apple,
                  onPressed: _loading ? null : _loginApple,
                  isDark: true,
                ),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 24),

              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l.dontHaveAccount,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    child: Text(l.register),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final String icon;
  final IconData fallbackIcon;
  final VoidCallback? onPressed;
  final bool isDark;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.fallbackIcon,
    this.onPressed,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: isDark ? AppColors.textPrimary : AppColors.surface,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
        side: BorderSide(
          color: isDark ? AppColors.textPrimary : AppColors.border,
          width: 1,
        ),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(fallbackIcon, size: 22),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
