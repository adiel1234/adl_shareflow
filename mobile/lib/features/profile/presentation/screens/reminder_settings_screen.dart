import 'package:flutter/material.dart';
import '../../../../features/balances/data/balance_repository.dart';
import '../../../../theme/app_colors.dart';

const _kFrequencies = [
  ('none', 'ללא', 'לא לשלוח תזכורות אוטומטיות'),
  ('manual', 'ידנית בלבד', 'רק בלחיצת כפתור מהאפליקציה'),
  ('daily', 'כל יום', 'שליחה יומית'),
  ('every_2_days', 'כל יומיים', 'שליחה כל יומיים'),
  ('weekly', 'שבועי', 'פעם בשבוע'),
  ('biweekly', 'דו-שבועי', 'פעם בשבועיים'),
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
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
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
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('הגדרות נשמרו ✓')),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('שגיאה בשמירת ההגדרות')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('תזכורות תשלום',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('שמור',
                    style: TextStyle(
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
                    title: const Text('הפעל תזכורות אוטומטיות',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'קבל/שלח תזכורות על תשלומים פתוחים',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12)),
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),

                const SizedBox(height: 20),

                // Frequency section
                const _SectionTitle(
                    icon: Icons.schedule,
                    title: 'תדירות שליחה'),
                const SizedBox(height: 10),
                _SectionCard(
                  child: Column(
                    children: _kFrequencies
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

                // Platform section
                const _SectionTitle(
                    icon: Icons.send_outlined,
                    title: 'פלטפורמות'),
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
                        title: const Text('התראה באפליקציה'),
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
                        subtitle: const Text(
                            'הודעה ישירה ב-WhatsApp',
                            style: TextStyle(
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
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ℹ️', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'תזכורות אוטומטיות יישלחו לחייבים עד שהתשלום יסומן כבוצע.',
                          style: TextStyle(
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
