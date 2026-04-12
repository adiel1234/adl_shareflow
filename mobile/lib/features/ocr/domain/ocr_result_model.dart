class OcrResult {
  final String receiptId;
  final String imageUrl;
  final String? amount;
  final String? merchant;
  final String? date;
  final double confidence;
  final bool needsReview;

  const OcrResult({
    required this.receiptId,
    required this.imageUrl,
    this.amount,
    this.merchant,
    this.date,
    required this.confidence,
    required this.needsReview,
  });

  factory OcrResult.fromJson(Map<String, dynamic> json) {
    final extracted = json['extracted'] as Map<String, dynamic>? ?? {};
    return OcrResult(
      receiptId: json['receipt_id'] as String,
      imageUrl: json['image_url'] as String,
      amount: extracted['amount'] as String?,
      merchant: extracted['merchant'] as String?,
      date: extracted['date'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
      needsReview: json['needs_review'] as bool? ?? false,
    );
  }

  double? get amountAsDouble => amount != null ? double.tryParse(amount!) : null;

  String get confidenceLabel {
    if (confidence >= 0.85) return 'גבוהה';
    if (confidence >= 0.6) return 'בינונית';
    return 'נמוכה';
  }
}
