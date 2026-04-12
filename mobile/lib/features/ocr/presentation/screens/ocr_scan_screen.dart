import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/ocr_repository.dart';
import '../../domain/ocr_result_model.dart';
import '../../../../theme/app_colors.dart';
import '../../../../ui/widgets/app_button.dart';

/// מסך סריקת קבלה — מחזיר [OcrResult] ל-caller
class OcrScanScreen extends StatefulWidget {
  final String? groupId;
  const OcrScanScreen({super.key, this.groupId});

  @override
  State<OcrScanScreen> createState() => _OcrScanScreenState();
}

class _OcrScanScreenState extends State<OcrScanScreen> {
  final _repo = OcrRepository();
  final _picker = ImagePicker();

  bool _scanning = false;
  String? _error;
  OcrResult? _result;
  XFile? _pickedFile;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (file == null) return;
      setState(() {
        _pickedFile = file;
        _result = null;
        _error = null;
        _scanning = true;
      });
      await _scan(file);
    } catch (e) {
      setState(() {
        _error = 'שגיאה בבחירת תמונה: ${e.toString()}';
        _scanning = false;
      });
    }
  }

  Future<void> _scan(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final result = await _repo.scanReceipt(
        imageBytes: bytes,
        filename: file.name,
        groupId: widget.groupId,
      );
      setState(() {
        _result = result;
        _scanning = false;
      });
    } catch (e) {
      setState(() {
        _error = 'שגיאה בסריקה. נסה שוב.';
        _scanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('סריקת קבלה'),
        backgroundColor: AppColors.background,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _result != null
              ? _ResultView(
                  result: _result!,
                  onConfirm: () => Navigator.pop(context, _result),
                  onRescan: () => setState(() {
                    _result = null;
                    _pickedFile = null;
                    _error = null;
                  }),
                )
              : _ScanView(
                  scanning: _scanning,
                  pickedFile: _pickedFile,
                  error: _error,
                  onGallery: () => _pick(ImageSource.gallery),
                  onCamera: kIsWeb ? null : () => _pick(ImageSource.camera),
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scan view — select image
// ---------------------------------------------------------------------------
class _ScanView extends StatelessWidget {
  final bool scanning;
  final XFile? pickedFile;
  final String? error;
  final VoidCallback onGallery;
  final VoidCallback? onCamera;

  const _ScanView({
    required this.scanning,
    required this.pickedFile,
    required this.error,
    required this.onGallery,
    required this.onCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),

        // Illustration
        Container(
          height: 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withOpacity(0.1),
                AppColors.secondary.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: scanning
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'מנתח קבלה...',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.document_scanner_outlined,
                      size: 64,
                      color: AppColors.primary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'בחר תמונה של קבלה',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'המערכת תחלץ סכום, שם העסק ותאריך',
                      style: TextStyle(
                        color: AppColors.textSecondary.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 32),

        // Buttons
        if (!scanning) ...[
          OutlinedButton.icon(
            onPressed: onGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('בחר מהגלריה'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          if (onCamera != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('צלם קבלה'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ],

        if (error != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.error, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    error!,
                    style:
                        TextStyle(color: AppColors.error, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],

        const Spacer(),

        // Tip
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: AppColors.secondary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'טיפ: ודא שהקבלה מצולמת בצורה ישרה ובאור טוב לתוצאה הטובה ביותר',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Result view — show extracted data
// ---------------------------------------------------------------------------
class _ResultView extends StatelessWidget {
  final OcrResult result;
  final VoidCallback onConfirm;
  final VoidCallback onRescan;

  const _ResultView({
    required this.result,
    required this.onConfirm,
    required this.onRescan,
  });

  @override
  Widget build(BuildContext context) {
    final confidenceColor = result.confidence >= 0.85
        ? AppColors.positive
        : result.confidence >= 0.6
            ? AppColors.warning
            : AppColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Confidence badge
        Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.positive, size: 22),
            const SizedBox(width: 8),
            const Text(
              'הסריקה הושלמה',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: confidenceColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'דיוק ${result.confidenceLabel}',
                style: TextStyle(
                  color: confidenceColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Extracted data
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _DataRow(
                icon: Icons.attach_money,
                label: 'סכום',
                value: result.amount != null
                    ? '${result.amount} ₪'
                    : 'לא זוהה',
                highlight: result.amount != null,
              ),
              const Divider(height: 24),
              _DataRow(
                icon: Icons.store_outlined,
                label: 'שם עסק',
                value: result.merchant ?? 'לא זוהה',
                highlight: result.merchant != null,
              ),
              const Divider(height: 24),
              _DataRow(
                icon: Icons.calendar_today_outlined,
                label: 'תאריך',
                value: result.date ?? 'לא זוהה',
                highlight: result.date != null,
              ),
            ],
          ),
        ),

        if (result.needsReview) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'מומלץ לבדוק את הנתונים לפני האישור',
                    style: TextStyle(
                        color: AppColors.warning, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        const Spacer(),

        GradientButton(
          label: 'אשר ומלא הוצאה',
          onPressed: onConfirm,
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRescan,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('סרוק שוב'),
        ),
      ],
    );
  }
}

class _DataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _DataRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: highlight
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 16,
                fontWeight:
                    highlight ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
