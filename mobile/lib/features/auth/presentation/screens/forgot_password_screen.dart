import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../services/auth_service.dart';
import '../../../../theme/app_colors.dart';
import '../../../../ui/widgets/app_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _auth = AuthService();

  /// 0 = enter email, 1 = enter code + new password
  int _step = 0;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    final l = AppLocalizations.of(context)!;
    try {
      await _auth.requestPasswordReset(_emailCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _step = 1;
        _info = l.resetCodeSent;
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      setState(() {
        _error = status == 503 ? l.resetEmailSendError : l.loginError;
      });
    } catch (_) {
      setState(() => _error = l.loginError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _error = null;
    });
    final l = AppLocalizations.of(context)!;
    try {
      await _auth.resetPassword(
        email: _emailCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
        newPassword: _passwordCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.passwordResetSuccess)),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] as String?)
          : null;
      setState(() {
        _error = (msg != null && msg.isNotEmpty) ? msg : l.invalidResetCode;
      });
    } catch (_) {
      setState(() => _error = l.invalidResetCode);
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
        title: Text(l.forgotPasswordTitle),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text(
                  l.forgotPasswordSubtitle,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _emailCtrl,
                  enabled: _step == 0,
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
                if (_step == 1) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: l.enterResetCode,
                      prefixIcon: const Icon(Icons.pin_outlined),
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v == null || v.length != 6) {
                        return l.resetCodeRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      hintText: l.newPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
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
                    obscureText: _obscure,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      hintText: l.confirmNewPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    validator: (v) {
                      if (v != _passwordCtrl.text) {
                        return l.passwordMismatch;
                      }
                      return null;
                    },
                  ),
                ],
                if (_info != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _info!,
                      style: const TextStyle(
                        color: AppColors.info,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                GradientButton(
                  label: _step == 0 ? l.sendResetCode : l.resetPasswordBtn,
                  onPressed: _loading
                      ? null
                      : (_step == 0 ? _sendCode : _resetPassword),
                  isLoading: _loading,
                ),
                if (_step == 1) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _step = 0;
                              _error = null;
                              _info = null;
                              _codeCtrl.clear();
                              _passwordCtrl.clear();
                              _confirmCtrl.clear();
                            }),
                    child: Text(l.wizardBack),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
