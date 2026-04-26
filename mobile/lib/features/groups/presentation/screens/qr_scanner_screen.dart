import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_colors.dart';

/// Full-screen QR scanner. Returns the invite code string when a valid
/// shareflow:// deep link is scanned, or null if the user presses back.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _detected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue;
    if (raw == null || raw.isEmpty) return;

    final code = _extractCode(raw);
    if (code == null) {
      // Show error briefly and keep scanning
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.qrScanError),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    _detected = true;
    _controller.stop();
    Navigator.of(context).pop(code);
  }

  /// Extracts the invite code from a deep link or raw code.
  /// Accepts: "shareflow://join/ABC123", "https://.../join/ABC123", or just "ABC123"
  String? _extractCode(String raw) {
    final trimmed = raw.trim();

    // shareflow://join/<code>
    if (trimmed.startsWith('shareflow://join/')) {
      final code = trimmed.substring('shareflow://join/'.length);
      if (code.isNotEmpty) return code.toUpperCase();
    }

    // https://<host>/join/<code>
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final segs = uri.pathSegments;
      final joinIdx = segs.indexOf('join');
      if (joinIdx >= 0 && joinIdx + 1 < segs.length) {
        final code = segs[joinIdx + 1];
        if (code.isNotEmpty) return code.toUpperCase();
      }
    }

    // Bare invite code (all alphanumeric, 6–12 chars)
    if (RegExp(r'^[A-Z0-9]{6,12}$').hasMatch(trimmed.toUpperCase())) {
      return trimmed.toUpperCase();
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l.scanQrCode,
            style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Torch toggle
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (_, state, __) => Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on
                    : Icons.flash_off,
                color: Colors.white,
              ),
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Overlay with scanning frame
          _ScanOverlay(subtitle: l.scanQrSubtitle),
        ],
      ),
    );
  }
}

/// Semi-transparent overlay with a clear square in the center.
class _ScanOverlay extends StatelessWidget {
  final String subtitle;
  const _ScanOverlay({required this.subtitle});

  @override
  Widget build(BuildContext context) {
    const frameSize = 240.0;
    const cornerLen = 24.0;
    const cornerThick = 3.5;
    const cornerRadius = 6.0;

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final left = (w - frameSize) / 2;
      final top = (h - frameSize) / 2.5;

      return Stack(
        children: [
          // Dark overlay
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.55),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Positioned(
                  left: left,
                  top: top,
                  child: Container(
                    width: frameSize,
                    height: frameSize,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(cornerRadius),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Corner markers
          Positioned(
            left: left,
            top: top,
            child: _Corners(
              size: frameSize,
              len: cornerLen,
              thick: cornerThick,
              radius: cornerRadius,
            ),
          ),

          // Subtitle text below frame
          Positioned(
            left: 0,
            right: 0,
            top: top + frameSize + 24,
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _Corners extends StatelessWidget {
  final double size;
  final double len;
  final double thick;
  final double radius;

  const _Corners({
    required this.size,
    required this.len,
    required this.thick,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
          len: len,
          thick: thick,
          radius: radius,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final double len;
  final double thick;
  final double radius;
  final Color color;

  _CornerPainter({
    required this.len,
    required this.thick,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thick
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, radius)
        ..arcToPoint(Offset(radius, 0), radius: Radius.circular(radius))
        ..lineTo(len, 0),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(w - len, 0)
        ..lineTo(w - radius, 0)
        ..arcToPoint(Offset(w, radius), radius: Radius.circular(radius))
        ..lineTo(w, len),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, h - len)
        ..lineTo(0, h - radius)
        ..arcToPoint(Offset(radius, h), radius: Radius.circular(radius))
        ..lineTo(len, h),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(w - len, h)
        ..lineTo(w - radius, h)
        ..arcToPoint(Offset(w, h - radius), radius: Radius.circular(radius))
        ..lineTo(w, h - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}
