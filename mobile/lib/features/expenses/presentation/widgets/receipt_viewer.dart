import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../theme/app_colors.dart';

/// Full-screen receipt image viewer (authenticated when [receiptId] is set).
class ReceiptViewerScreen extends StatefulWidget {
  final String? receiptId;
  final String? imageUrl;
  final String? title;

  const ReceiptViewerScreen({
    super.key,
    this.receiptId,
    this.imageUrl,
    this.title,
  });

  @override
  State<ReceiptViewerScreen> createState() => _ReceiptViewerScreenState();
}

class _ReceiptViewerScreenState extends State<ReceiptViewerScreen> {
  Uint8List? _bytes;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.receiptId != null) {
      _loadAuthenticated();
    }
  }

  Future<void> _loadAuthenticated() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiClient.instance.dio.get<List<int>>(
        '/ocr/receipts/${widget.receiptId}/image',
        options: Options(responseType: ResponseType.bytes),
      );
      if (!mounted) return;
      setState(() {
        _bytes = Uint8List.fromList(response.data ?? []);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title ?? 'קבלה'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: _buildImage(),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (widget.receiptId != null) {
      if (_loading) {
        return const CircularProgressIndicator(color: Colors.white54);
      }
      if (_error != null || _bytes == null || _bytes!.isEmpty) {
        return _errorContent();
      }
      return Image.memory(_bytes!, fit: BoxFit.contain);
    }

    final url = widget.imageUrl;
    if (url == null || url.isEmpty) return _errorContent();

    return CachedNetworkImage(
      imageUrl: resolveMediaUrl(url),
      fit: BoxFit.contain,
      httpHeaders: const {'Accept': 'image/*'},
      placeholder: (_, __) => const CircularProgressIndicator(
        color: Colors.white54,
      ),
      errorWidget: (_, __, ___) => _errorContent(),
    );
  }

  Widget _errorContent() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
        SizedBox(height: 8),
        Text('לא ניתן לטעון את הקבלה',
            style: TextStyle(color: Colors.white70)),
      ],
    );
  }
}

/// Compact receipt preview tile for expense edit screen.
class ReceiptPreviewTile extends StatelessWidget {
  final String? receiptId;
  final String imageUrl;
  final VoidCallback? onView;
  final VoidCallback? onRemove;

  const ReceiptPreviewTile({
    super.key,
    this.receiptId,
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
            child: ReceiptThumbnail(
              receiptId: receiptId,
              imageUrl: imageUrl,
              size: 56,
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

/// Small receipt thumbnail — prefers authenticated load via [receiptId].
class ReceiptThumbnail extends StatefulWidget {
  final String? receiptId;
  final String? imageUrl;
  final double size;

  const ReceiptThumbnail({
    super.key,
    this.receiptId,
    this.imageUrl,
    this.size = 56,
  });

  @override
  State<ReceiptThumbnail> createState() => _ReceiptThumbnailState();
}

class _ReceiptThumbnailState extends State<ReceiptThumbnail> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    if (widget.receiptId != null) _load();
  }

  Future<void> _load() async {
    try {
      final response = await ApiClient.instance.dio.get<List<int>>(
        '/ocr/receipts/${widget.receiptId}/image',
        options: Options(responseType: ResponseType.bytes),
      );
      if (!mounted) return;
      setState(() => _bytes = Uint8List.fromList(response.data ?? []));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (widget.receiptId != null && _bytes != null) {
      return Image.memory(
        _bytes!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
      );
    }

    final url = widget.imageUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: resolveMediaUrl(url),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: widget.size,
      height: widget.size,
      color: AppColors.surfaceVariant,
      child: const Icon(Icons.receipt_long_outlined),
    );
  }
}
