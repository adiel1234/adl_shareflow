import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/expenses_provider.dart';
import '../../../../providers/groups_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../groups/domain/group_model.dart';
import '../../../ocr/presentation/screens/ocr_scan_screen.dart';
import '../../../ocr/domain/ocr_result_model.dart';
import '../../../../ui/widgets/currency_conversion_chip.dart';
import '../../../../theme/app_colors.dart';
import '../../../../ui/widgets/app_button.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../features/currency/data/currency_repository.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final Group group;
  const AddExpenseScreen({super.key, required this.group});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  late String _currency;
  String? _category;
  String? _paidBy;
  bool _loading = false;
  String? _scannedReceiptId;
  double _exchangeRate = 1.0;

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
    _currency = widget.group.baseCurrency;
    final uid = ref.read(authProvider).userId;
    _paidBy = uid.isNotEmpty ? uid : null;
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

  Future<void> _scanReceipt() async {
    final result = await Navigator.push<OcrResult>(
      context,
      MaterialPageRoute(
        builder: (_) => OcrScanScreen(groupId: widget.group.id),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _scannedReceiptId = result.receiptId;
      if (result.amount != null && result.amountAsDouble != null) {
        _amountCtrl.text = result.amountAsDouble!.toStringAsFixed(2);
      }
      if (result.merchant != null && _titleCtrl.text.isEmpty) {
        _titleCtrl.text = result.merchant!;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.amount != null
                ? 'קבלה נסרקה — סכום: ${result.amount} ₪'
                : 'הקבלה נסרקה, בדוק את הנתונים',
          ),
          backgroundColor: AppColors.positive,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await ref.read(expenseRepositoryProvider).createExpense(
            groupId: widget.group.id,
            title: _titleCtrl.text.trim(),
            amount: double.parse(_amountCtrl.text),
            currency: _currency,
            paidBy: _paidBy ?? ref.read(authProvider).userId,
            exchangeRate: _exchangeRate,
            category: _category,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('שגיאה בהוספת הוצאה')),
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
        title: const Text('הוצאה חדשה'),
        backgroundColor: AppColors.background,
        actions: [
          // OCR Scan button in app bar
          IconButton(
            onPressed: _loading ? null : _scanReceipt,
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'סרוק קבלה',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary.withOpacity(0.08),
              foregroundColor: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // OCR banner — if receipt was scanned
              if (_scannedReceiptId != null) ...[
                _OcrBanner(onRescan: _scanReceipt),
                const SizedBox(height: 16),
              ] else ...[
                // Scan CTA (prominent)
                _ScanCta(onTap: _scanReceipt),
                const SizedBox(height: 20),
              ],

              // Category
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
                            color:
                                selected ? AppColors.primary : AppColors.surface,
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
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) =>
                              _onCurrencyChanged(v ?? widget.group.baseCurrency),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Currency conversion chip
              if (_showConversion) ...[
                const SizedBox(height: 10),
                CurrencyConversionChip(
                  fromCurrency: _currency,
                  toCurrency: widget.group.baseCurrency,
                  amount: _currentAmount,
                ),
              ],

              const SizedBox(height: 16),

              // Paid by
              const _SectionLabel('שילם'),
              const SizedBox(height: 8),
              membersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('שגיאה בטעינת חברים'),
                data: (members) {
                  // Ensure _paidBy is valid — reset if not found in list
                  final validPaidBy = members.any((m) => m.userId == _paidBy)
                      ? _paidBy
                      : null;
                  if (validPaidBy != _paidBy) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => setState(() => _paidBy = validPaidBy),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    value: validPaidBy,
                    decoration: const InputDecoration(),
                    hint: const Text('בחר מי שילם'),
                    items: members
                        .map((m) => DropdownMenuItem(
                              value: m.userId,
                              child: Text(m.displayLabel),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _paidBy = v),
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
                label: 'הוסף הוצאה',
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _ScanCta extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.08),
              AppColors.secondary.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.document_scanner,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'סרוק קבלה',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'חסוך זמן — מלא אוטומטית מקבלה',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _OcrBanner extends StatelessWidget {
  final VoidCallback onRescan;
  const _OcrBanner({required this.onRescan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.positive.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.positive.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline,
              color: AppColors.positive, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'הקבלה נסרקה — ניתן לעדכן את הנתונים',
              style: TextStyle(
                  color: AppColors.positive,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: onRescan,
            child: const Text('סרוק שוב'),
          ),
        ],
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
