import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';

const _kOnboardingDone = 'onboarding_done_v1';

/// Returns true if the user has already completed/skipped onboarding.
Future<bool> hasCompletedOnboarding() async {
  const s = FlutterSecureStorage();
  return await s.read(key: _kOnboardingDone) == 'true';
}

/// Mark onboarding as done so it is never shown again.
Future<void> markOnboardingDone() async {
  const s = FlutterSecureStorage();
  await s.write(key: _kOnboardingDone, value: 'true');
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;
  bool _saving = false;

  // Step 1 — Photo
  XFile? _pickedImage;
  bool _uploadingPhoto = false;

  // Step 2 — Payment details
  final _phoneCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();

  static const _totalPages = 3;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _phoneCtrl.dispose();
    _bankNameCtrl.dispose();
    _branchCtrl.dispose();
    _accountCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _totalPages - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _skip() async {
    await markOnboardingDone();
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      // Save payment details
      final phone = _phoneCtrl.text.trim();
      final bankName = _bankNameCtrl.text.trim();
      final branch = _branchCtrl.text.trim();
      final account = _accountCtrl.text.trim();

      if (phone.isNotEmpty ||
          bankName.isNotEmpty ||
          branch.isNotEmpty ||
          account.isNotEmpty) {
        final response = await ApiClient.instance.put('/users/me', data: {
          if (phone.isNotEmpty) 'payment_phone': phone,
          if (bankName.isNotEmpty) 'bank_name': bankName,
          if (branch.isNotEmpty) 'bank_branch': branch,
          if (account.isNotEmpty) 'bank_account_number': account,
        });
        final userData = response.data['data'] as Map<String, dynamic>;
        ref.read(authProvider.notifier).setUser(userData);
      }
    } catch (_) {}

    await markOnboardingDone();
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _pickPhoto() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('צלם תמונה'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('בחר מהגלריה'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    final src = action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: src, maxWidth: 600, maxHeight: 600, imageQuality: 80);
    if (picked == null || !mounted) return;

    setState(() {
      _pickedImage = picked;
      _uploadingPhoto = true;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .uploadAvatar(File(picked.path));
    } catch (_) {}
    if (mounted) setState(() => _uploadingPhoto = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final name = auth.displayName;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
              child: Row(
                children: List.generate(_totalPages, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(left: 6),
                    width: active ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primary
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _WelcomePage(name: name),
                  _PhotoPage(
                    auth: auth,
                    pickedImage: _pickedImage,
                    uploading: _uploadingPhoto,
                    onPickPhoto: _pickPhoto,
                  ),
                  _PaymentPage(
                    phoneCtrl: _phoneCtrl,
                    bankNameCtrl: _bankNameCtrl,
                    branchCtrl: _branchCtrl,
                    accountCtrl: _accountCtrl,
                  ),
                ],
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _saving ? null : _next,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : Text(
                              _page == _totalPages - 1
                                  ? 'התחל להשתמש'
                                  : 'הבא',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _saving ? null : _skip,
                    child: const Text(
                      'דלג — אשלים מאוחר יותר',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 0 — Welcome
// ---------------------------------------------------------------------------

class _WelcomePage extends StatelessWidget {
  final String name;
  const _WelcomePage({required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Center(
              child: Text('💸', style: TextStyle(fontSize: 44)),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'ברוך הבא${name.isNotEmpty ? ", $name" : ""}! 👋',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          const Text(
            'בכמה שלבים קצרים נגדיר את הפרופיל שלך\nכדי שחברים יוכלו לשלוח לך כסף בקלות.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5),
          ),
          const SizedBox(height: 32),
          _FeatureRow(
              icon: '📷', text: 'תמונת פרופיל שתזוהה בקבוצות'),
          const SizedBox(height: 12),
          _FeatureRow(
              icon: '💳',
              text: 'פרטי תשלום — Bit, PayBox, העברה בנקאית'),
          const SizedBox(height: 12),
          _FeatureRow(
              icon: '⚡', text: 'חברים יוכלו לשלם לך ישירות מהאפליקציה'),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
          ),
        ],
      );
}

// ---------------------------------------------------------------------------
// Page 1 — Profile Photo
// ---------------------------------------------------------------------------

class _PhotoPage extends StatelessWidget {
  final AuthState auth;
  final XFile? pickedImage;
  final bool uploading;
  final VoidCallback onPickPhoto;

  const _PhotoPage({
    required this.auth,
    required this.pickedImage,
    required this.uploading,
    required this.onPickPhoto,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar;

    if (uploading) {
      avatar = const CircleAvatar(
        radius: 54,
        backgroundColor: AppColors.surface,
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    } else if (pickedImage != null) {
      avatar = CircleAvatar(
        radius: 54,
        backgroundImage: FileImage(File(pickedImage!.path)),
      );
    } else if (auth.avatarUrl != null &&
        auth.avatarUrl!.startsWith('data:image')) {
      final b64 = auth.avatarUrl!.split(',').last;
      try {
        avatar = CircleAvatar(
          radius: 54,
          backgroundImage: MemoryImage(base64Decode(b64)),
        );
      } catch (_) {
        avatar = _defaultAvatar(auth);
      }
    } else {
      avatar = _defaultAvatar(auth);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'תמונת פרופיל',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'תמונה תעזור לחברים בקבוצה לזהות אותך.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4),
          ),
          const SizedBox(height: 36),
          GestureDetector(
            onTap: onPickPhoto,
            child: Stack(
              children: [
                avatar,
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: onPickPhoto,
            child: const Text(
              'בחר תמונה',
              style: TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '(שלב זה אופציונלי)',
            style: TextStyle(
                color: AppColors.textDisabled, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar(AuthState auth) => CircleAvatar(
        radius: 54,
        backgroundColor: AppColors.primary,
        child: Text(
          auth.displayName.isNotEmpty
              ? auth.displayName[0].toUpperCase()
              : '?',
          style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: Colors.white),
        ),
      );
}

// ---------------------------------------------------------------------------
// Page 2 — Payment Details
// ---------------------------------------------------------------------------

class _PaymentPage extends StatelessWidget {
  final TextEditingController phoneCtrl;
  final TextEditingController bankNameCtrl;
  final TextEditingController branchCtrl;
  final TextEditingController accountCtrl;

  const _PaymentPage({
    required this.phoneCtrl,
    required this.bankNameCtrl,
    required this.branchCtrl,
    required this.accountCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'פרטי תשלום',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'כשחבר בקבוצה ירצה להחזיר לך כסף,\nהפרטים האלה יוצגו לו ישירות.',
            style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4),
          ),
          const SizedBox(height: 24),

          // Bit / PayBox
          _SectionHeader(
              icon: '💙', title: 'Bit / PayBox — מספר טלפון'),
          const SizedBox(height: 8),
          _Field(
            controller: phoneCtrl,
            hint: '05X-XXXXXXX',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),

          // Bank
          _SectionHeader(icon: '🏦', title: 'העברה בנקאית'),
          const SizedBox(height: 8),
          _Field(
            controller: bankNameCtrl,
            hint: 'שם הבנק (לדוגמה: הפועלים)',
            prefixIcon: Icons.account_balance_outlined,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Field(
                  controller: branchCtrl,
                  hint: 'סניף',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.numbers,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _Field(
                  controller: accountCtrl,
                  hint: 'מספר חשבון',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.credit_card_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.info.withOpacity(0.2)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ℹ️', style: TextStyle(fontSize: 14)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ניתן לשנות את הפרטים בכל עת מהפרופיל.',
                    style: TextStyle(
                        color: AppColors.info,
                        fontSize: 12,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 15)),
        ],
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final IconData prefixIcon;

  const _Field({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    required this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(color: AppColors.textDisabled, fontSize: 13),
          prefixIcon: Icon(prefixIcon, size: 18),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: true,
        ),
      );
}
