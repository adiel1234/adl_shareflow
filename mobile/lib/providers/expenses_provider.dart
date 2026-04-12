import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/expenses/data/expense_repository.dart';
import '../features/expenses/domain/expense_model.dart';
import 'auth_provider.dart';

final expenseRepositoryProvider = Provider((_) => ExpenseRepository());

final expensesProvider =
    FutureProvider.autoDispose.family<List<Expense>, String>(
  (ref, groupId) async {
    // Watch auth so this provider re-executes the moment auth finishes loading.
    // This guarantees expense data is always fetched with a valid userId in scope.
    final auth = ref.watch(authProvider);
    if (auth.isLoading) return <Expense>[];
    return ref.watch(expenseRepositoryProvider).fetchExpenses(groupId);
  },
);
