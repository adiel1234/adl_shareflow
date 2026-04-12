import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/groups_provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../ui/widgets/app_button.dart';
import '../../../../core/constants/app_constants.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _currency = 'ILS';
  String? _category;
  String _groupType = 'event';   // 'event' | 'ongoing'
  bool _loading = false;

  static const _categories = [
    ('apartment', '🏠', 'דירה'),
    ('trip', '✈️', 'טיול'),
    ('vehicle', '🚗', 'רכב'),
    ('event', '🎉', 'אירוע'),
    ('other', '👥', 'אחר'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(groupRepositoryProvider).createGroup(
            name: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            baseCurrency: _currency,
            category: _category,
            groupType: _groupType,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('שגיאה ביצירת הקבוצה')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('קבוצה חדשה'),
        backgroundColor: AppColors.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group type selector (אירוע / שוטף)
              const Text(
                'סוג פעילות',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _TypeCard(
                    title: 'אירוע',
                    subtitle: '7 ימים',
                    emoji: '🎯',
                    selected: _groupType == 'event',
                    onTap: () => setState(() => _groupType = 'event'),
                  ),
                  const SizedBox(width: 10),
                  _TypeCard(
                    title: 'שוטף',
                    subtitle: 'חודשי',
                    emoji: '🔄',
                    selected: _groupType == 'ongoing',
                    onTap: () => setState(() => _groupType = 'ongoing'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _groupType == 'event'
                      ? 'מתאים לטיולים, אירועים, ומפגשים — עד 25 משתתפים'
                      : 'מתאים לדירות שותפים, משרדים — חיוב חודשי',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 24),

              // Category picker
              const Text(
                'קטגוריה',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final selected = _category == cat.$1;
                  return InkWell(
                    onTap: () => setState(() => _category = cat.$1),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cat.$2,
                              style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text(
                            cat.$3,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Name
              const _Label('שם הקבוצה'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: 'לדוגמה: דירה ברחוב הרצל'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'נדרש שם לקבוצה';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Description
              const _Label('תיאור (אופציונלי)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    hintText: 'הוסף תיאור קצר...'),
              ),

              const SizedBox(height: 16),

              // Currency
              const _Label('מטבע בסיס'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _currency,
                decoration: const InputDecoration(),
                items: AppConstants.supportedCurrencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _currency = v ?? 'ILS'),
              ),

              const SizedBox(height: 32),

              GradientButton(
                label: 'צור קבוצה',
                onPressed: _loading ? null : _create,
                isLoading: _loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withOpacity(0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      );
}
