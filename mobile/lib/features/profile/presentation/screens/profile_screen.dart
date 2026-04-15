import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/locale_provider.dart';
import '../../../../providers/notifications_provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import 'reminder_settings_screen.dart';
import 'payment_details_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

          // Settings
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
            subtitle: 'Bit, PayBox, העברה בנקאית',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PaymentDetailsScreen()),
            ),
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
