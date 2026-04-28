import 'package:flutter/material.dart';
import '../../../../features/balances/data/balance_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_colors.dart';

List<(String, String, String)> _frequencies(AppLocalizations l) => [
      ('none', l.freqNone, l.freqNoneDesc),
      ('manual', l.freqManual, l.freqManualDesc),
      ('daily', l.freqDaily, l.freqDailyDesc),
      ('every_2_days', l.freqEvery2Days, l.freqEvery2DaysDesc),
      ('weekly', l.freqWeekly, l.freqWeeklyDesc),
      ('biweekly', l.freqBiweekly, l.freqBiweeklyDesc),
    ];

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  bool _loading = true;
  bool _saving = false;

  String _frequency = 'manual';
  bool _platformApp = true;
  bool _platformWhatsApp = false;
  bool _enabled = true;
  // null = no preference (any hour), 0–23 = specific hour (Israel time)
  int? _preferredHour;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final data = await BalanceRepository().getReminderSettings();
      if (mounted) {
        final platforms = (data['platforms'] as List?)?.cast<String>() ?? ['app'];
        setState(() {
          _frequency = data['frequency'] as String? ?? 'manual';
          _platformApp = platforms.contains('app');
          _platformWhatsApp = platforms.contains('whatsapp');
          _enabled = data['enabled'] as bool? ?? true;
          _preferredHour = data['preferred_hour'] as int?;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    final platforms = [
      if (_platformApp) 'app',
      if (_platformWhatsApp) 'whatsapp',
    ];
    if (platforms.isEmpty) platforms.add('app');

    try {
      await BalanceRepository().updateReminderSettings(
        frequency: _frequency,
        platforms: platforms,
        enabled: _enabled,
        preferredHour: _preferredHour,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.settingsSaved)),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.settingsSaveError)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final freqs = _frequencies(l);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(l.paymentReminders,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l.save,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Enable toggle
                _SectionCard(
                  child: SwitchListTile(
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                    title: Text(l.enableReminders,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(l.enableRemindersSubtitle,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12)),
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),

                const SizedBox(height: 20),

                // Frequency section
                _SectionTitle(
                    icon: Icons.schedule,
                    title: l.reminderFrequency),
                const SizedBox(height: 10),
                _SectionCard(
                  child: Column(
                    children: freqs
                        .map((f) => _FrequencyTile(
                              value: f.$1,
                              title: f.$2,
                              subtitle: f.$3,
                              selected: _frequency == f.$1,
                              enabled: _enabled,
                              onTap: () =>
                                  setState(() => _frequency = f.$1),
                            ))
                        .toList(),
                  ),
                ),

                const SizedBox(height: 20),

                // Preferred hour section
                _SectionTitle(
                    icon: Icons.access_time,
                    title: 'שעת תזכורת מועדפת'),
                const SizedBox(height: 10),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        value: _preferredHour != null,
                        onChanged: _enabled
                            ? (v) => setState(
                                () => _preferredHour = v ? 9 : null)
                            : null,
                        title: const Text('קבע שעה קבועה',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _preferredHour != null
                              ? 'תזכורות ישלחו בשעה ${_preferredHour.toString().padLeft(2, "0")}:00'
                              : 'ללא העדפה — ישלח בכל שעה',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12),
                        ),
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_preferredHour != null) ...[
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 40,
                            perspective: 0.004,
                            diameterRatio: 2.5,
                            physics: const FixedExtentScrollPhysics(),
                            controller: FixedExtentScrollController(
                                initialItem: _preferredHour!),
                            onSelectedItemChanged: (i) =>
                                setState(() => _preferredHour = i),
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 24,
                              builder: (context, index) => Center(
                                child: Text(
                                  '${index.toString().padLeft(2, "0")}:00',
                                  style: TextStyle(
                                    fontSize: index == _preferredHour
                                        ? 20
                                        : 15,
                                    fontWeight: index == _preferredHour
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    color: index == _preferredHour
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Platform section
                _SectionTitle(
                    icon: Icons.send_outlined,
                    title: l.reminderPlatforms),
                const SizedBox(height: 10),
                _SectionCard(
                  child: Column(
                    children: [
                      CheckboxListTile(
                        value: _platformApp,
                        onChanged: _enabled
                            ? (v) =>
                                setState(() => _platformApp = v ?? true)
                            : null,
                        title: Text(l.inAppNotification),
                        subtitle: const Text(
                            'Push notification',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        secondary: const Icon(
                            Icons.notifications_outlined,
                            color: AppColors.primary),
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        value: _platformWhatsApp,
                        onChanged: _enabled
                            ? (v) => setState(
                                () => _platformWhatsApp = v ?? false)
                            : null,
                        title: const Text('WhatsApp'),
                        subtitle: Text(l.whatsappMessage,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        secondary: const Text('💬',
                            style: TextStyle(fontSize: 22)),
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.info.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ℹ️', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.reminderInfo,
                          style: const TextStyle(
                              color: AppColors.info,
                              fontSize: 12,
                              height: 1.5),
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

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary)),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _FrequencyTile extends StatelessWidget {
  final String value;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _FrequencyTile({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : AppColors.border,
                    width: 2),
                color: selected
                    ? AppColors.primary
                    : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check,
                      size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? AppColors.textPrimary
                              : AppColors.textDisabled,
                          fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
