import 'package:adl_shareflow/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ShareFlow theme scaffold builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: Text('ShareFlow')),
      ),
    );

    expect(find.text('ShareFlow'), findsOneWidget);
  });
}
