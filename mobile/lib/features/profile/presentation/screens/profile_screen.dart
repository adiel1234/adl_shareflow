import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/app_config.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/locale_provider.dart';
import '../../../../providers/notifications_provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/currency_format.dart';
import 'reminder_settings_screen.dart';
import 'payment_details_screen.dart';
import '../../../home/presentation/widgets/home_howto.dart';
import '../../../home/presentation/screens/main_shell.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final VoidCallback? onReplayTour;
  const ProfileScreen({super.key, this.onReplayTour});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _version = '';
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      final build = AppConfig.displayBuildNumber(info.buildNumber);
      setState(() => _version = '${info.version} ($build)');
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final nav = Navigator.of(context, rootNavigator: true);
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final dl = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dl.logout),
          content: Text(dl.confirmLogout),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(dl.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                dl.logout,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
    if (confirm != true || !mounted) return;
    try {
      await ref.read(authProvider.notifier).logout();
      ref.invalidate(notificationsProvider);
    } finally {
      if (nav.mounted) {
        nav.pushNamedAndRemoveUntil('/login', (_) => false);
      }
    }
  }

  Future<void> _pickAvatar() async {
    final hasAvatar = ref.read(authProvider).avatarUrl != null;
    // 'camera', 'gallery', 'delete', or null (dismissed)
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
            if (hasAvatar)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('הסר תמונה',
                    style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;

    if (action == 'delete') {
      setState(() => _uploadingAvatar = true);
      try {
        await ref.read(authProvider.notifier).deleteAvatar();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('תמונת הפרופיל הוסרה')),
          );
        }
      } finally {
        if (mounted) setState(() => _uploadingAvatar = false);
      }
      return;
    }

    final source =
        action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      await ref.read(authProvider.notifier).uploadAvatar(File(picked.path));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('תמונת הפרופיל עודכנה ✓')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('שגיאה בהעלאת התמונה')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Widget _buildAvatar(AuthState auth) {
    final url = auth.avatarUrl;
    if (url != null && url.startsWith('data:image')) {
      // Base64 data URL
      final b64 = url.split(',').last;
      try {
        return CircleAvatar(
          radius: 40,
          backgroundImage: MemoryImage(base64Decode(b64)),
        );
      } catch (_) {}
    } else if (url != null && url.startsWith('http')) {
      return CircleAvatar(
        radius: 40,
        backgroundImage: NetworkImage(url),
      );
    }
    return CircleAvatar(
      radius: 40,
      backgroundColor: AppColors.primary,
      child: Text(
        auth.displayName.isNotEmpty
            ? auth.displayName[0].toUpperCase()
            : '?',
        style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.profile),
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar + name
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      _buildAvatar(auth),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: _uploadingAvatar
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.camera_alt,
                                  size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  auth.displayName,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  auth.email,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    auth.isPro ? 'Pro' : 'Free',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          if (ref.watch(profileIncompleteProvider)) ...[
            Material(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PaymentDetailsScreen()),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          color: Colors.orange.shade800),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.paymentMissingBannerTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.orange.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l.paymentMissingBannerBody,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        l.paymentMissingBannerCta,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Settings section
          _SectionHeader(label: l.appSection),
          _LanguageTile(),
          _SettingsTile(
            icon: Icons.currency_exchange,
            title: l.defaultCurrency,
            subtitle: currencyPickerLabel(
              auth.preferredCurrency,
              hebrew: Localizations.localeOf(context).languageCode == 'he',
            ),
            onTap: () => _pickCurrency(context, ref, auth.preferredCurrency),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: l.paymentReminders,
            subtitle: l.setReminderFrequency,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ReminderSettingsScreen()),
            ),
          ),
          _SettingsTile(
            icon: Icons.account_balance_wallet_outlined,
            title: l.paymentDetails,
            subtitle: l.paymentMethodSubtitle,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PaymentDetailsScreen()),
            ),
          ),
          _SettingsTile(
            icon: Icons.touch_app_outlined,
            title: l.profileTourTitle,
            subtitle: l.profileTourSubtitle,
            onTap: () {
              if (widget.onReplayTour != null) {
                widget.onReplayTour!();
              }
            },
          ),
          _SettingsTile(
            icon: Icons.menu_book_outlined,
            title: l.profileHowToTitle,
            subtitle: l.profileHowToSubtitle,
            onTap: () => showHomeHowTo(context, markDone: false),
          ),

          const SizedBox(height: 20),

          // Pro Plan banner
          _ProPlanBanner(l: l),

          const SizedBox(height: 20),

          _SettingsTile(
            icon: Icons.lightbulb_outline,
            title: l.suggestions,
            subtitle: l.suggestionsSubtitle,
            onTap: () => _launchUrl(
                'mailto:info@adlprojects.co.il?subject=ADL%20ShareFlow%20Suggestion'),
          ),
          _SettingsTile(
            icon: Icons.mail_outline,
            title: l.contactUs,
            subtitle: l.contactSubtitle,
            onTap: () => _showContactTopics(context, l),
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            title: l.aboutTitle,
            subtitle: _version.isNotEmpty ? l.aboutVersion(_version) : '',
            onTap: () => _showAbout(context, l),
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.logout,
            title: l.logout,
            iconColor: AppColors.error,
            titleColor: AppColors.error,
            onTap: () => _logout(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(url)),
        );
      }
    }
  }

  Future<void> _showContactTopics(BuildContext context, AppLocalizations l) async {
    final topics = <(String, String)>[
      (l.contactTopicBug, 'ADL ShareFlow — Bug'),
      (l.contactTopicBalances, 'ADL ShareFlow — Balances'),
      (l.contactTopicInvite, 'ADL ShareFlow — Invite/Group'),
      (l.contactTopicOther, 'ADL ShareFlow — Support'),
    ];
    final subject = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  l.contactChooseTopic,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ...topics.map(
                (t) => ListTile(
                  leading: const Icon(Icons.chevron_left),
                  title: Text(t.$1),
                  onTap: () => Navigator.pop(ctx, t.$2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (subject == null || !mounted) return;
    final encoded = Uri.encodeComponent(subject);
    await _launchUrl('mailto:info@adlprojects.co.il?subject=$encoded');
  }

  void _showAbout(BuildContext context, AppLocalizations l) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'ADL ShareFlow',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              l.aboutVersion(_version),
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '© 2025 ADL Projects',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
        ],
      ),
    );
  }
}

const _kCurrencies = [
  'ILS', 'USD', 'EUR', 'GBP', 'JPY', 'AED', 'CAD', 'AUD', 'CHF',
];

void _pickCurrency(BuildContext context, WidgetRef ref, String current) {
  final hebrew = Localizations.localeOf(context).languageCode == 'he';
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.chooseCurrency,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ..._kCurrencies.map((code) {
              final isSelected = code == current;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      currencyFlag(code),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                title: Text(
                  '${currencyCountry(code, hebrew: hebrew)} · '
                  '${currencyName(code, hebrew: hebrew)} ($code)',
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle,
                        color: AppColors.primary)
                    : null,
                onTap: () {
                  ref
                      .read(authProvider.notifier)
                      .setPreferredCurrency(code);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      );
    },
  );
}

class _LanguageTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isHe = locale.languageCode == 'he';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _showLanguagePicker(context, ref, locale);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(
            children: [
              const Icon(Icons.language, color: AppColors.textSecondary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.language,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                    ),
                    Text(
                      isHe ? AppLocalizations.of(context)!.hebrew : AppLocalizations.of(context)!.english,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left,
                  color: AppColors.textDisabled, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref, Locale current) {
    final options = [
      (const Locale('he'), 'עברית', 'Hebrew', '🇮🇱'),
      (const Locale('en'), 'English', 'אנגלית', '🇺🇸'),
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.language,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...options.map((o) {
                final isSelected = o.$1 == current;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.1)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(o.$4, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  title: Text(
                    o.$2,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(o.$3,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle,
                          color: AppColors.primary)
                      : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(localeProvider.notifier).setLocale(o.$1);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 4, left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ProPlanBanner extends StatelessWidget {
  final AppLocalizations l;
  const _ProPlanBanner({required this.l});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C47FF), Color(0xFF9E72FF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.proPlanTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.proPlanSubtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              l.comingSoon,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: titleColor ?? AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left,
                  color: AppColors.textDisabled, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
