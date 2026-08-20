import '../../../core/network/api_client.dart';
import '../domain/expense_model.dart';

class ExpenseRepository {
  final _api = ApiClient.instance;

  Future<List<Expense>> fetchExpenses(String groupId, {int page = 1}) async {
    // Load every page so lists/totals stay correct beyond the first page.
    const perPage = 100;
    final all = <Expense>[];
    var currentPage = page;
    while (true) {
      final response = await _api.get(
        '/groups/$groupId/expenses',
        params: {'page': currentPage, 'per_page': perPage},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      final list = data['expenses'] as List<dynamic>;
      all.addAll(
        list.map((j) => Expense.fromJson(j as Map<String, dynamic>)),
      );
      final pagination = data['pagination'] as Map<String, dynamic>?;
      final total = (pagination?['total'] as num?)?.toInt() ?? all.length;
      if (all.length >= total || list.length < perPage) break;
      currentPage++;
    }
    return all;
  }

  Future<Expense> createExpense({
    required String groupId,
    required String title,
    required double amount,
    required String currency,
    required String paidBy,
    double exchangeRate = 1.0,
    String splitType = 'equal',
    String? category,
    String? notes,
    String? expenseDate,
    List<Map<String, dynamic>>? participants,
    String? receiptId,
  }) async {
    final response = await _api.post('/groups/$groupId/expenses', data: {
      'title': title,
      'original_amount': amount,
      'original_currency': currency,
      'paid_by': paidBy,
      'exchange_rate': exchangeRate,
      'split_type': splitType,
      if (category != null) 'category': category,
      if (notes != null) 'notes': notes,
      'expense_date': expenseDate ?? DateTime.now().toIso8601String().split('T')[0],
      if (participants != null) 'participants': participants,
      if (receiptId != null) 'receipt_id': receiptId,
    });
    return Expense.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Expense> updateExpense({
    required String expenseId,
    required String title,
    required double amount,
    required String currency,
    required String paidBy,
    String? category,
    String? notes,
    String? expenseDate,
    double exchangeRate = 1.0,
    List<Map<String, dynamic>>? participants,
    String? receiptId,
  }) async {
    final response = await _api.put('/expenses/$expenseId', data: {
      'title': title,
      'original_amount': amount,
      'original_currency': currency,
      'paid_by': paidBy,
      'exchange_rate': exchangeRate,
      if (category != null) 'category': category,
      'notes': notes ?? '',
      'expense_date':
          expenseDate ?? DateTime.now().toIso8601String().split('T')[0],
      if (participants != null) 'participants': participants,
      if (receiptId != null) 'receipt_id': receiptId,
    });
    return Expense.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteExpense(String expenseId) async {
    await _api.delete('/expenses/$expenseId');
  }
}
