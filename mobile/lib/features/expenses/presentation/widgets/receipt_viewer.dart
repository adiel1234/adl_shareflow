import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';

/// Full-screen receipt image viewer.
class ReceiptViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String? title;

  const ReceiptViewerScreen({
    super.key,
    required this.imageUrl,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title ?? 'קבלה'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => const CircularProgressIndicator(
              color: Colors.white54,
            ),
            errorWidget: (_, __, ___) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined,
                    color: Colors.white54, size: 48),
                SizedBox(height: 8),
                Text('לא ניתן לטעון את הקבלה',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact receipt preview tile for expense edit screen.
class ReceiptPreviewTile extends StatelessWidget {
  final String imageUrl;
  final VoidCallback? onView;
  final VoidCallback? onRemove;

  const ReceiptPreviewTile({
    super.key,
    required this.imageUrl,
    this.onView,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 56,
                height: 56,
                color: AppColors.surfaceVariant,
                child: const Icon(Icons.receipt_long_outlined),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'קבלה מצורפת',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (onView != null)
            IconButton(
              icon: const Icon(Icons.visibility_outlined),
              tooltip: 'צפה בקבלה',
              onPressed: onView,
            ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.negative),
              tooltip: 'הסר קבלה',
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
