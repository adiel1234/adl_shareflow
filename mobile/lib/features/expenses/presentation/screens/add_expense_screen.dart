import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../providers/expenses_provider.dart';
import '../../../../providers/groups_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/currency_provider.dart';
import '../../../groups/domain/group_model.dart';
import '../../../ocr/presentation/screens/ocr_scan_screen.dart';
import '../../../ocr/domain/ocr_result_model.dart';
import '../../../ocr/data/ocr_repository.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../ui/widgets/currency_conversion_chip.dart';
import '../../../../theme/app_colors.dart';
import '../../../../ui/widgets/app_button.dart';
import '../../../../services/feedback_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../features/currency/data/currency_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/currency_format.dart';
import '../widgets/participants_selector.dart';

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
  late String _expenseDate;
  bool _loading = false;
  String? _scannedReceiptId;
  String? _receiptImageUrl;
  final _ocrRepo = OcrRepository();
  final _picker = ImagePicker();
  double _exchangeRate = 1.0;
  Set<String> _selectedParticipantIds = {};

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
    _expenseDate = DateTime.now().toIso8601String().split('T')[0];
    final uid = ref.read(authProvider).userId;
    _paidBy = uid.isNotEmpty ? uid : null;
    _amountCtrl.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(conversionProvider);
    });
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
      if (mounted) {
        setState(() => _exchangeRate = 1.0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('שגיאה בהמרת מטבע — בדקו את החיבור')),
        );
      }
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
      _receiptImageUrl = resolveMediaUrl(result.imageUrl);
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
                ? 'קבלה נסרקה. סכום: ${result.amount} ₪'
                : 'הקבלה נסרקה, בדוק את הנתונים',
          ),
          backgroundColor: AppColors.positive,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<ImageSource?> _pickReceiptSource() async {
    final l = AppLocalizations.of(context)!;
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l.takePhoto),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.pickFromGallery),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (action == 'camera') return ImageSource.camera;
    if (action == 'gallery') return ImageSource.gallery;
    return null;
  }

  Future<void> _attachReceipt() async {
    try {
      final source = await _pickReceiptSource();
      if (source == null || !mounted) return;

      if (source == ImageSource.camera && kIsWeb) return;

      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (file == null || !mounted) return;

      setState(() => _loading = true);
      final bytes = await file.readAsBytes();
      final result = await _ocrRepo.attachReceipt(
        imageBytes: bytes,
        filename: file.name,
        groupId: widget.group.id,
      );

      if (!mounted) return;
      setState(() {
        _scannedReceiptId = result.receiptId;
        _receiptImageUrl = resolveMediaUrl(result.imageUrl);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('קבלה צורפה להוצאה'),
          backgroundColor: AppColors.positive,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('שגיאה בצירוף הקבלה')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedParticipantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.atLeastOneParticipant)),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);

    // Resolve FX on save — never send rate=1 for foreign currency by accident.
    var rate = _exchangeRate;
    if (_currency != widget.group.baseCurrency) {
      try {
        final result = await CurrencyRepository().convert(
          from: _currency,
          to: widget.group.baseCurrency,
          amount: 1.0,
        );
        rate = result.rate;
        if (mounted) setState(() => _exchangeRate = rate);
      } catch (_) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('לא ניתן להמיר מטבע כרגע. נסו שוב.'),
            ),
          );
        }
        return;
      }
    } else {
      rate = 1.0;
    }

    final participants = _selectedParticipantIds
        .map((uid) => {'user_id': uid})
        .toList();

    try {
      await ref.read(expenseRepositoryProvider).createExpense(
            groupId: widget.group.id,
            title: _titleCtrl.text.trim(),
            amount: double.parse(_amountCtrl.text),
            currency: _currency,
            paidBy: _paidBy ?? ref.read(authProvider).userId,
            exchangeRate: rate,
            category: _category,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            participants: participants,
            receiptId: _scannedReceiptId,
            expenseDate: _expenseDate,
          );
      await FeedbackService.newExpense();
      ref.invalidate(groupDetailProvider(widget.group.id));
      ref.invalidate(groupsProvider);
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_scannedReceiptId != null) ...[
                _OcrBanner(
                  onRescan: _scanReceipt,
                  onRemove: () => setState(() {
                    _scannedReceiptId = null;
                    _receiptImageUrl = null;
                  }),
                ),
                const SizedBox(height: 12),
              ] else ...[
                _FieldSection(
                  title: AppLocalizations.of(context)!.scanReceipt,
                  required: false,
                  child: _ScanCta(
                    onScan: _scanReceipt,
                    onAttachOnly: _attachReceipt,
                  ),
                ),
              ],

              _FieldSection(
                title: AppLocalizations.of(context)!.category,
                required: false,
                child: SizedBox(
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
                              color: selected
                                  ? null
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? catColor
                                    : AppColors.border,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  cat.$2,
                                  size: 24,
                                  color: selected ? Colors.white : catColor,
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
              ),

              _FieldSection(
                title: AppLocalizations.of(context)!.expenseDescription,
                required: true,
                child: TextFormField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    hintText:
                        AppLocalizations.of(context)!.expenseDescriptionHint,
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? AppLocalizations.of(context)!.descriptionRequired
                      : null,
                ),
              ),

              _FieldSection(
                title: AppLocalizations.of(context)!.amount,
                required: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              filled: true,
                              fillColor: AppColors.background,
                            ),
                            validator: (v) {
                              final l = AppLocalizations.of(context)!;
                              if (v == null || v.isEmpty) {
                                return l.amountRequired;
                              }
                              if (double.tryParse(v) == null ||
                                  double.parse(v) <= 0) {
                                return l.invalidAmount;
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _currency,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: AppColors.background,
                            ),
                            items: AppConstants.supportedCurrencies
                                .map((c) {
                              final he = Localizations.localeOf(context)
                                      .languageCode ==
                                  'he';
                              return DropdownMenuItem(
                                value: c,
                                child: Text(
                                  currencyPickerLabel(c, hebrew: he),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) => _onCurrencyChanged(
                                v ?? widget.group.baseCurrency),
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
                    Text(
                      AppLocalizations.of(context)!.date,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.tryParse(_expenseDate) ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _expenseDate =
                                picked.toIso8601String().split('T')[0];
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
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
                  ],
                ),
              ),

              membersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                ),
                error: (_, __) => Text(
                    AppLocalizations.of(context)!.errorLoadingMembers),
                data: (members) {
                  if (_selectedParticipantIds.isEmpty && members.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        _selectedParticipantIds =
                            members.map((m) => m.userId).toSet();
                      });
                    });
                  }

                  final validPaidBy =
                      members.any((m) => m.userId == _paidBy)
                          ? _paidBy
                          : null;
                  if (validPaidBy != _paidBy) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => setState(() => _paidBy = validPaidBy),
                    );
                  }

                  return Column(
                    children: [
                      _FieldSection(
                        title: AppLocalizations.of(context)!.paidBy,
                        required: true,
                        child: DropdownButtonFormField<String>(
                          value: validPaidBy,
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: AppColors.background,
                          ),
                          hint: Text(
                              AppLocalizations.of(context)!.paidByHint),
                          items: members
                              .map((m) => DropdownMenuItem(
                                    value: m.userId,
                                    child: Text(m.displayLabel),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _paidBy = v),
                          validator: (v) => v == null || v.isEmpty
                              ? AppLocalizations.of(context)!.paidByHint
                              : null,
                        ),
                      ),
                      _FieldSection(
                        title: AppLocalizations.of(context)!.participants,
                        required: true,
                        child: ParticipantsSelector(
                          members: members,
                          selectedIds: _selectedParticipantIds,
                          totalAmount: _currentAmount,
                          currency: _currency,
                          onChanged: (ids) => setState(
                              () => _selectedParticipantIds = ids),
                        ),
                      ),
                    ],
                  );
                },
              ),

              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    AppLocalizations.of(context)!.addExpenseMoreOptions,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  children: [
                    _FieldSection(
                      title: AppLocalizations.of(context)!.optionalNotes,
                      required: false,
                      child: TextFormField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.addNotesHint,
                          filled: true,
                          fillColor: AppColors.background,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              GradientButton(
                label: AppLocalizations.of(context)!.addExpenseBtn,
                onPressed: _loading ? null : _save,
                isLoading: _loading,
              ),
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
  final VoidCallback onScan;
  final VoidCallback onAttachOnly;
  const _ScanCta({required this.onScan, required this.onAttachOnly});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onScan,
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
                  child: const Icon(Icons.document_scanner_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.scanReceipt,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        l.scanReceiptDescription,
                        style: const TextStyle(
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
        ),
        const SizedBox(height: 8),
        Text(
          l.tipScanPrimary,
          style: const TextStyle(
            fontSize: 12,
            height: 1.35,
            color: AppColors.textSecondary,
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: onAttachOnly,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            child: Text(
              l.attachReceiptTitle,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OcrBanner extends StatelessWidget {
  final VoidCallback onRescan;
  final VoidCallback? onRemove;
  const _OcrBanner({required this.onRescan, this.onRemove});

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
          Icon(Icons.attach_file_rounded,
              color: AppColors.positive, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'קבלה מצורפת',
              style: const TextStyle(
                  color: AppColors.positive,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onRemove,
              tooltip: 'הסר קבלה',
            ),
          TextButton(
            onPressed: onRescan,
            child: const Text('החלף'),
          ),
        ],
      ),
    );
  }
}

class _FieldSection extends StatelessWidget {
  final String title;
  final bool required;
  final Widget child;

  const _FieldSection({
    required this.title,
    required this.required,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: required
                      ? AppColors.primary.withValues(alpha: 0.10)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  required ? l.fieldRequiredBadge : l.fieldOptionalBadge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: required
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
