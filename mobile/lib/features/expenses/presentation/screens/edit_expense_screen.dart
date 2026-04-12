import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/expenses_provider.dart';
import '../../../../providers/groups_provider.dart';
import '../../../groups/domain/group_model.dart';
import '../../domain/expense_model.dart';
import '../../../../ui/widgets/currency_conversion_chip.dart';
import '../../../../theme/app_colors.dart';
import '../../../../ui/widgets/app_button.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../features/currency/data/currency_repository.dart';

class EditExpenseScreen extends ConsumerStatefulWidget {
  final Group group;
  final Expense expense;

  const EditExpenseScreen({
    super.key,
    required this.group,
    required this.expense,
  });

  @override
  ConsumerState<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends ConsumerState<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _notesCtrl;

  late String _currency;
  String? _category;
  late String _paidBy;
  late String _expenseDate;
  bool _loading = false;
  late double _exchangeRate;

  double get _currentAmount => double.tryParse(_amountCtrl.text) ?? 0;
  bool get _showConversion =>
      _currency != widget.group.baseCurrency && _currentAmount > 0;

  static const _categories = [
    ('food', '🍔', 'אוכל'),
    ('travel', '✈️', 'טיול'),
    ('housing', '🏠', 'דיור'),
    ('transport', '🚌', 'תחבורה'),
    ('entertainment', '🎬', 'בידור'),
    ('shopping', '🛍️', 'קניות'),
    ('utilities', '💡', 'חשבונות'),
    ('other', '💳', 'אחר'),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _titleCtrl = TextEditingController(text: e.title);
    _amountCtrl = TextEditingController(text: e.originalAmount);
    _notesCtrl = TextEditingController(text: e.notes ?? '');
    _currency = e.originalCurrency;
    _exchangeRate = double.tryParse(e.exchangeRate) ?? 1.0;
    _category = e.category;
    _paidBy = e.paidById;
    _expenseDate = e.expenseDate ?? DateTime.now().toIso8601String().split('T')[0];
    _amountCtrl.addListener(() => setState(() {}));
  }

  Future<void> _onCurrencyChanged(String newCurrency) async {
    setState(() => _currency = newCurrency);
    if (newCurrency == widget.group.baseCurrency) {
      setState(() => _exchangeRate = 1.0);
      return;
    }
    try {
      final result = await CurrencyRepository().convert(
        from: newCurrency,
        to: widget.group.baseCurrency,
        amount: 1.0,
      );
      if (mounted) setState(() => _exchangeRate = result.rate);
    } catch (_) {
      if (mounted) setState(() => _exchangeRate = 1.0);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await ref.read(expenseRepositoryProvider).updateExpense(
            expenseId: widget.expense.id,
            title: _titleCtrl.text.trim(),
            amount: double.parse(_amountCtrl.text),
            currency: _currency,
            paidBy: _paidBy,
            exchangeRate: _exchangeRate,
            category: _category,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            expenseDate: _expenseDate,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('שגיאה בעדכון ההוצאה')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersProvider(widget.group.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('עריכת הוצאה'),
        backgroundColor: AppColors.background,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category picker
              const _SectionLabel('קטגוריה'),
              const SizedBox(height: 10),
              SizedBox(
                height: 72,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _categories.map((cat) {
                    final selected = _category == cat.$1;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: InkWell(
                        onTap: () => setState(() => _category = cat.$1),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 72,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(cat.$2,
                                  style: const TextStyle(fontSize: 24)),
                              const SizedBox(height: 4),
                              Text(
                                cat.$3,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // Title
              const _SectionLabel('תיאור ההוצאה'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(hintText: 'לדוגמה: ארוחת ערב'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'נדרש תיאור' : null,
              ),

              const SizedBox(height: 16),

              // Amount + Currency
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel('סכום'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration:
                              const InputDecoration(hintText: '0.00'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'נדרש סכום';
                            if (double.tryParse(v) == null ||
                                double.parse(v) <= 0) {
                              return 'סכום לא תקין';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel('מטבע'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _currency,
                          decoration: const InputDecoration(),
                          items: AppConstants.supportedCurrencies
                              .map((c) => DropdownMenuItem(
                                  value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) =>
                              _onCurrencyChanged(v ?? widget.group.baseCurrency),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (_showConversion) ...[
                const SizedBox(height: 10),
                CurrencyConversionChip(
                  fromCurrency: _currency,
                  toCurrency: widget.group.baseCurrency,
                  amount: _currentAmount,
                ),
              ],

              const SizedBox(height: 16),

              // Date
              const _SectionLabel('תאריך'),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(_expenseDate) ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _expenseDate = picked.toIso8601String().split('T')[0];
                    });
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Text(
                        _expenseDate,
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Paid by
              const _SectionLabel('שילם'),
              const SizedBox(height: 8),
              membersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('שגיאה בטעינת חברים'),
                data: (members) {
                  final validPaidBy =
                      members.any((m) => m.userId == _paidBy)
                          ? _paidBy
                          : members.first.userId;
                  return DropdownButtonFormField<String>(
                    value: validPaidBy,
                    decoration: const InputDecoration(),
                    items: members
                        .map((m) => DropdownMenuItem(
                              value: m.userId,
                              child: Text(m.displayLabel),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _paidBy = v ?? _paidBy),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'בחר מי שילם' : null,
                  );
                },
              ),

              const SizedBox(height: 16),

              // Notes
              const _SectionLabel('הערות (אופציונלי)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration:
                    const InputDecoration(hintText: 'הוסף הערה...'),
              ),

              const SizedBox(height: 32),

              GradientButton(
                label: 'שמור שינויים',
                onPressed: _loading ? null : _save,
                isLoading: _loading,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

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
