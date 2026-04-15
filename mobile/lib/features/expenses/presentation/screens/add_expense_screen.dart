import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../../services/feedback_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../features/currency/data/currency_repository.dart';
import '../../../../l10n/app_localizations.dart';

// 3 professional icon colors — same palette as GroupCard
const _kCatBlue   = Color(0xFF1D4ED8);
const _kCatTeal   = Color(0xFF0D9488);
const _kCatPurple = Color(0xFF7C3AED);

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

  static const _categoryDefs = [
    ('food',          Icons.restaurant_rounded,      _kCatTeal,   _kCatBlue),
    ('travel',        Icons.flight_rounded,           _kCatBlue,   _kCatTeal),
    ('housing',       Icons.home_rounded,             _kCatTeal,   _kCatPurple),
    ('transport',     Icons.directions_car_rounded,   _kCatBlue,   _kCatPurple),
    ('entertainment', Icons.celebration_rounded,      _kCatPurple, _kCatBlue),
    ('shopping',      Icons.shopping_bag_rounded,     _kCatPurple, _kCatTeal),
    ('utilities',     Icons.bolt_rounded,             _kCatTeal,   _kCatBlue),
    ('other',         Icons.receipt_long_rounded,     _kCatBlue,   _kCatTeal),
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
      await FeedbackService.newExpense();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorAddingExpense)),
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
        title: Text(AppLocalizations.of(context)!.addExpense),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            onPressed: _loading ? null : _scanReceipt,
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: AppLocalizations.of(context)!.scanReceipt,
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
              _SectionLabel(AppLocalizations.of(context)!.category),
              const SizedBox(height: 10),
              SizedBox(
                height: 72,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _categoryDefs.map((cat) {
                    final selected = _category == cat.$1;
                    final catColor = cat.$3;
                    final catColor2 = cat.$4;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _category = cat.$1);
                        },
                        borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 72,
                          decoration: BoxDecoration(
                            gradient: selected
                                ? LinearGradient(
                                    colors: [catColor, catColor2],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: selected ? null : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? catColor
                                  : const Color(0xFFE2E8F0),
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                cat.$2,
                                size: 24,
                                color: selected
                                    ? Colors.white
                                    : catColor,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _catLabel(context, cat.$1),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
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
                decoration: InputDecoration(hintText: AppLocalizations.of(context)!.expenseDescriptionHint),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? AppLocalizations.of(context)!.descriptionRequired : null,
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
                            if (v == null || v.isEmpty) return AppLocalizations.of(context)!.amountRequired;
                            if (double.tryParse(v) == null ||
                                double.parse(v) <= 0) {
                              return AppLocalizations.of(context)!.invalidAmount;
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
              _SectionLabel(AppLocalizations.of(context)!.paidBy),
              const SizedBox(height: 8),
              membersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => Text(AppLocalizations.of(context)!.errorLoadingMembers),
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
                    hint: Text(AppLocalizations.of(context)!.paidByHint),
                    items: members
                        .map((m) => DropdownMenuItem(
                              value: m.userId,
                              child: Text(m.displayLabel),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _paidBy = v),
                    validator: (v) =>
                        v == null || v.isEmpty ? AppLocalizations.of(context)!.paidByHint : null,
                  );
                },
              ),

              const SizedBox(height: 16),

              // Notes
              _SectionLabel(AppLocalizations.of(context)!.optionalNotes),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(hintText: AppLocalizations.of(context)!.addNotesHint),
              ),

              const SizedBox(height: 32),

              GradientButton(
                label: AppLocalizations.of(context)!.addExpenseBtn,
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
                  Text(
                    AppLocalizations.of(context)!.scanReceipt,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.scanReceiptDescription,
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
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.receiptScanned,
              style: const TextStyle(
                  color: AppColors.positive,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: onRescan,
            child: Text(AppLocalizations.of(context)!.rescan),
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
