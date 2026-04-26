import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/locale_provider.dart';
import '../../../../providers/notifications_provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import 'reminder_settings_screen.dart';
import 'payment_details_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
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
                CircleAvatar(
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
                    auth.isPro ? '✨ Pro' : 'Free',
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

          // Settings section
          _SectionHeader(label: l.appSection),
          _LanguageTile(),
          _SettingsTile(
            icon: Icons.currency_exchange,
            title: l.defaultCurrency,
            subtitle: '${auth.preferredCurrency} ${_currencySymbol(auth.preferredCurrency)}',
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

          const SizedBox(height: 20),

          // Pro Plan banner
          _ProPlanBanner(l: l),

          const SizedBox(height: 20),

          // About / Contact / ADL section
          _SectionHeader(label: l.adlProjects),
          _SettingsTile(
            icon: Icons.business_outlined,
            title: l.adlProjects,
            subtitle: l.adlProjectsSubtitle,
            onTap: () => _launchUrl('https://adlprojects.co.il'),
          ),
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
            onTap: () => _launchUrl(
                'mailto:info@adlprojects.co.il?subject=ADL%20ShareFlow%20Support'),
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
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) {
                  final dl = AppLocalizations.of(ctx)!;
                  return AlertDialog(
                    title: Text(dl.logout),
                    content: Text(dl.confirmLogout),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(dl.cancel)),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(dl.logout,
                              style: const TextStyle(color: AppColors.error))),
                    ],
                  );
                },
              );
              if (confirm == true) {
                await ref.read(authProvider.notifier).logout();
                ref.invalidate(notificationsProvider);
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (_) => false);
                }
              }
            },
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
              child: const Text('💸', style: TextStyle(fontSize: 40)),
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
  ('ILS', '₪', 'שקל'),
  ('USD', '\$', 'דולר'),
  ('EUR', '€', 'יורו'),
  ('GBP', '£', 'לירה שטרלינג'),
  ('JPY', '¥', 'ין יפני'),
  ('CAD', 'CA\$', 'דולר קנדי'),
  ('AUD', 'A\$', 'דולר אוסטרלי'),
  ('CHF', 'Fr', 'פרנק שוויצרי'),
];

String _currencySymbol(String code) {
  for (final c in _kCurrencies) {
    if (c.$1 == code) return c.$2;
  }
  return '';
}

void _pickCurrency(BuildContext context, WidgetRef ref, String current) {
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
            ..._kCurrencies.map((c) {
              final isSelected = c.$1 == current;
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
                      c.$2,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  '${c.$1} — ${c.$3}',
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
                      .setPreferredCurrency(c.$1);
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
          const Text('✨', style: TextStyle(fontSize: 24)),
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
