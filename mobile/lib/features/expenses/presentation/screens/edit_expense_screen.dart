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
import '../../../../l10n/app_localizations.dart';

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

  static const _kBlue   = Color(0xFF1D4ED8);
  static const _kTeal   = Color(0xFF0D9488);
  static const _kPurple = Color(0xFF7C3AED);

  static const _categoryDefs = [
    ('food',          Icons.restaurant_rounded,      _kTeal,   _kBlue),
    ('travel',        Icons.flight_rounded,           _kBlue,   _kTeal),
    ('housing',       Icons.home_rounded,             _kTeal,   _kPurple),
    ('transport',     Icons.directions_car_rounded,   _kBlue,   _kPurple),
    ('entertainment', Icons.celebration_rounded,      _kPurple, _kBlue),
    ('shopping',      Icons.shopping_bag_rounded,     _kPurple, _kTeal),
    ('utilities',     Icons.bolt_rounded,             _kTeal,   _kBlue),
    ('other',         Icons.receipt_long_rounded,     _kBlue,   _kTeal),
  ];

  String _catLabel(BuildContext context, String key) {
    final l = AppLocalizations.of(context)!;
    switch (key) {
      case 'food':          return l.catFood;
      case 'travel':        return l.catTravel;
      case 'housing':       return l.catHousing;
      case 'transport':     return l.catTransport;
      case 'entertainment': return l.catEntertainment;
      case 'shopping':      return l.catShopping;
      case 'utilities':     return l.catUtilities;
      default:              return l.catOther;
    }
  }

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
          SnackBar(content: Text(AppLocalizations.of(context)!.errorUpdatingExpense)),
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
        title: Text(AppLocalizations.of(context)!.editExpense),
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
              _SectionLabel(AppLocalizations.of(context)!.category),
              const SizedBox(height: 10),
              SizedBox(
                height: 72,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _categoryDefs.map((cat) {
                    final selected = _category == cat.$1;
                    final color = cat.$3;
                    final color2 = cat.$4;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: InkWell(
                        onTap: () => setState(() => _category = cat.$1),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 72,
                          decoration: BoxDecoration(
                            gradient: selected
                                ? LinearGradient(
                                    colors: [color, color2],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: selected ? null : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? color : AppColors.border,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(cat.$2,
                                  size: 22,
                                  color: selected ? Colors.white : color),
                              const SizedBox(height: 4),
                              Text(
                                _catLabel(context, cat.$1),
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
              _SectionLabel(AppLocalizations.of(context)!.expenseDescription),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(hintText: AppLocalizations.of(context)!.expenseHint),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? AppLocalizations.of(context)!.expenseTitleRequired : null,
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
                        _SectionLabel(AppLocalizations.of(context)!.amount),
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
                            final l = AppLocalizations.of(context)!;
                            if (v == null || v.isEmpty) return l.amountRequired;
                            if (double.tryParse(v) == null ||
                                double.parse(v) <= 0) {
                              return l.invalidAmount;
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
                        _SectionLabel(AppLocalizations.of(context)!.currency),
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
              _SectionLabel(AppLocalizations.of(context)!.date),
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
              _SectionLabel(AppLocalizations.of(context)!.paidBy),
              const SizedBox(height: 8),
              membersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => Text(AppLocalizations.of(context)!.errorLoadingMembers),
                data: (members) {
                  final l = AppLocalizations.of(context)!;
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
                        v == null || v.isEmpty ? l.selectPaidBy : null,
                  );
                },
              ),

              const SizedBox(height: 16),

              // Notes
              _SectionLabel(AppLocalizations.of(context)!.notes),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration:
                    InputDecoration(hintText: AppLocalizations.of(context)!.notesHint),
              ),

              const SizedBox(height: 32),

              GradientButton(
                label: AppLocalizations.of(context)!.saveChanges,
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
