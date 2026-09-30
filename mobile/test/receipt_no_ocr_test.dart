import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expense screens do not trigger OCR scan', () {
    const paths = [
      'lib/features/expenses/presentation/screens/add_expense_screen.dart',
      'lib/features/expenses/presentation/screens/edit_expense_screen.dart',
      'lib/features/expenses/presentation/screens/expenses_list_screen.dart',
    ];
    for (final path in paths) {
      final source = File(path).readAsStringSync();
      expect(source.contains('/ocr/scan'), isFalse, reason: path);
      expect(source.contains('OcrScanScreen'), isFalse, reason: path);
      expect(source.contains('scanReceipt('), isFalse, reason: path);
    }

    final add = File(
      'lib/features/expenses/presentation/screens/add_expense_screen.dart',
    ).readAsStringSync();
    expect(add.contains('attachReceipt'), isTrue);
    expect(add.contains('ReceiptViewerScreen'), isTrue);
  });
}
