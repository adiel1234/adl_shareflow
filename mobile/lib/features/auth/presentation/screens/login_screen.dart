import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../../theme/app_colors.dart';
import '../../../../services/auth_service.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../ui/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../social_auth.dart';

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
  bool _rememberMe = true;
  bool _offerShown = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Transparent: clear sticky Google session before the user taps the button.
      try {
        await SocialAuth.prepareGoogleSignIn();
      } catch (_) {}
      await _loadRemembered();
      await _maybeScreenshotAutoLogin();
    });
  }

  /// Store-prep only: `--dart-define=SCREENSHOT_EMAIL=... --dart-define=SCREENSHOT_PASSWORD=...`
  Future<void> _maybeScreenshotAutoLogin() async {
    const email = String.fromEnvironment('SCREENSHOT_EMAIL');
    const password = String.fromEnvironment('SCREENSHOT_PASSWORD');
    if (email.isEmpty || password.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _emailCtrl.text = email;
      _passwordCtrl.text = password;
      _rememberMe = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (mounted) await _loginEmail();
  }

  Future<void> _loadRemembered() async {
    final saved = await _authService.loadRememberedCredentials();
    if (!mounted || !saved.rememberMe || saved.email == null) return;

    if (_offerShown) return;
    _offerShown = true;

    setState(() {
      _rememberMe = true;
      _emailCtrl.text = saved.email!;
      if (saved.password != null) {
        _passwordCtrl.text = saved.password!;
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginEmail() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _error = null;
    });
    final l = AppLocalizations.of(context)!;
    try {
      final user = await _authService.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        rememberMe: _rememberMe,
      );
      ref.read(authProvider.notifier).setUser(user);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() {
        _error = _parseError(e, l);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loginGoogle() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _error = null;
    });
    final l = AppLocalizations.of(context)!;
    try {
      final user = await SocialAuth.signInWithGoogle();
      ref.read(authProvider.notifier).setUser(user);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!e.toString().contains('cancelled')) {
        setState(() => _error = _parseGoogleError(e, l));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginApple() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _error = null;
    });
    final l = AppLocalizations.of(context)!;
    try {
      final user = await SocialAuth.signInWithApple();
      ref.read(authProvider.notifier).setUser(user);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      final msg = e.toString();
      if (!msg.contains('canceled') && !msg.contains('cancelled')) {
        setState(() => _error = _parseError(e, l));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _parseError(dynamic e, AppLocalizations l) {
    String msg = e.toString();
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        msg = data['message'].toString();
      }
    }
    if (msg.contains('PILOT_ENDED')) {
      return l.pilotEndedLogin;
    }
    if (msg.contains('401') || msg.contains('Invalid email')) {
      return l.wrongCredentials;
    }
    return l.loginError;
  }

  /// Temporary Play diagnosis — show raw Google/network failure (session d50e8a).
  String _parseGoogleError(dynamic e, AppLocalizations l) {
    if (e is DioException) {
      final data = e.response?.data;
      final status = e.response?.statusCode;
      if (data is Map && data['message'] != null) {
        final m = data['message'].toString();
        if (m.contains('PILOT_ENDED')) return l.pilotEndedLogin;
        // #region agent log
        debugPrint(
          'SF_DBG_GOOGLE ${{'hypothesisId': 'C', 'message': 'dio', 'status': status, 'msg': m}}',
        );
        // #endregion
        return 'שרת ($status): $m';
      }
      return 'רשת: ${e.type.name}';
    }
    final raw = e.toString();
    // #region agent log
    debugPrint(
      'SF_DBG_GOOGLE ${{'hypothesisId': 'A', 'message': 'client', 'raw': raw}}',
    );
    // #endregion
    final short = raw.length > 160 ? '${raw.substring(0, 160)}…' : raw;
    return short;
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
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset('assets/icons/app_icon.png'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l.welcomeTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.loginSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      textInputAction: TextInputAction.next,
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
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_loading) _loginEmail();
                      },
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

              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () =>
                          setState(() => _rememberMe = !_rememberMe),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _rememberMe,
                              onChanged: (v) =>
                                  setState(() => _rememberMe = v ?? false),
                              activeColor: AppColors.primary,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l.rememberMe,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/forgot-password'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      l.forgotPassword,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Existing users: login is primary
              GradientButton(
                label: l.loginBtn,
                onPressed: _loading ? null : _loginEmail,
                isLoading: _loading,
              ),

              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.pushNamed(context, '/register'),
                child: Text(
                  '${l.dontHaveAccount} ${l.register}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),

              const SizedBox(height: 8),
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
              const SizedBox(height: 12),

              _GoogleSignInButton(
                label: l.continueWithGoogle,
                onPressed: _loading ? null : _loginGoogle,
              ),
              if (!kIsWeb && SocialAuth.isAppleAvailable) ...[
                const SizedBox(height: 10),
                _AppleSignInButton(
                  label: l.continueWithApple,
                  onPressed: _loading ? null : _loginApple,
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _GoogleSignInButton({
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F9FA),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF747775), width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CustomPaint(painter: _GoogleGPainter()),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F1F1F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppleSignInButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _AppleSignInButton({
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.black, width: 1),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.apple, size: 22, color: Colors.white),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Multicolor Google «G» (simplified brand mark).
class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = w * 0.22;
    final c = Offset(w / 2, size.height / 2);
    final r = w / 2 - stroke / 2;
    final oval = Rect.fromCircle(center: c, radius: r);

    void ring(Color color, double start, double sweep) {
      canvas.drawArc(
        oval,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt,
      );
    }

    // Angles: 0 = right, clockwise in Flutter drawArc is... actually
    // drawArc uses radians, 0 at right, positive = clockwise in Flutter? 
    // In Flutter, positive angles are clockwise.
    ring(_blue, -0.55, 1.85);
    ring(_green, 1.3, 0.95);
    ring(_yellow, 2.25, 0.85);
    ring(_red, 3.1, 1.05);

    // Horizontal bar of the G (blue)
    final barH = stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - stroke * 0.1, c.dy - barH / 2, w * 0.48, barH),
        Radius.circular(barH / 4),
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
