import 'package:adl_shareflow/features/balances/domain/balance_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses total_expenses_paid as the paid-before-split amount', () {
    final balance = UserBalance.fromJson({
      'user_id': 'adiel',
      'display_name': 'Adiel',
      'net_amount': '200.00',
      'total_paid': '400.00',
      'total_owed': '200.00',
      'total_expenses_paid': '300.00',
      'status': 'creditor',
    });

    expect(balance.totalExpensesPaid, '300.00');
    expect(balance.totalExpensesPaidDouble, 300.0);
    expect(balance.netDouble, 200.0);
    expect(balance.totalPaid, '400.00');
  });

  test('defaults total_expenses_paid when the field is missing', () {
    final balance = UserBalance.fromJson({
      'user_id': 'yossi',
      'display_name': 'Yossi',
      'net_amount': '0.00',
      'total_paid': '0.00',
      'total_owed': '0.00',
      'status': 'settled',
    });

    expect(balance.totalExpensesPaid, '0.00');
    expect(balance.totalExpensesPaidDouble, 0.0);
  });
}
