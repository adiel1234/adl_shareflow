import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/app_colors.dart';
import '../../../../services/auth_service.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../ui/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../social_auth.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await _authService.register(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        displayName: _nameCtrl.text.trim(),
      );
      ref.read(authProvider.notifier).setUser(user);
      if (mounted) Navigator.pushReplacementNamed(context, '/onboarding');
    } catch (e) {
      final l = AppLocalizations.of(context)!;
      setState(() {
        _error = e.toString().contains('already')
            ? l.emailAlreadyRegistered
            : l.registerError;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _registerGoogle() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _error = null;
    });
    final l = AppLocalizations.of(context)!;
    try {
      final user = await SocialAuth.signInWithGoogle();
      ref.read(authProvider.notifier).setUser(user);
      if (mounted) Navigator.pushReplacementNamed(context, '/onboarding');
    } catch (e) {
      if (!e.toString().contains('cancelled')) {
        setState(() => _error = l.registerError);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerApple() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _error = null;
    });
    final l = AppLocalizations.of(context)!;
    try {
      final user = await SocialAuth.signInWithApple();
      ref.read(authProvider.notifier).setUser(user);
      if (mounted) Navigator.pushReplacementNamed(context, '/onboarding');
    } catch (e) {
      final msg = e.toString();
      if (!msg.contains('canceled') && !msg.contains('cancelled')) {
        setState(() => _error = l.registerError);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.register),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                l.createAccount,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l.fillDetails,
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _SocialButton(
                label: l.continueWithGoogle,
                fallbackIcon: Icons.g_mobiledata,
                onPressed: _loading ? null : _registerGoogle,
              ),
              if (!kIsWeb && SocialAuth.isAppleAvailable) ...[
                const SizedBox(height: 12),
                _SocialButton(
                  label: l.continueWithApple,
                  fallbackIcon: Icons.apple,
                  onPressed: _loading ? null : _registerApple,
                  isDark: true,
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      l.orDivider,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        hintText: l.fullName,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return l.nameRequired;
                        }
                        if (v.trim().length < 2) return l.nameTooShort;
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
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
                        hintText: l.passwordHint,
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
                        if (v.length < 8) return l.passwordTooShort;
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: true,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        hintText: l.confirmPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (v) {
                        if (v != _passwordCtrl.text) return l.passwordMismatch;
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
              GradientButton(
                label: l.register,
                onPressed: _loading ? null : _register,
                isLoading: _loading,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l.alreadyHaveAccount,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.loginBtn),
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
  final IconData fallbackIcon;
  final VoidCallback? onPressed;
  final bool isDark;

  const _SocialButton({
    required this.label,
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
