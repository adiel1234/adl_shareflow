import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/expenses_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/currency_provider.dart';
import '../../../groups/domain/group_model.dart';
import '../../domain/expense_model.dart';
import '../../../../theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import 'edit_expense_screen.dart';

// iOS-style category icon helpers (same palette as GroupCard)
const _kExpBlue   = Color(0xFF1D4ED8);
const _kExpTeal   = Color(0xFF0D9488);
const _kExpPurple = Color(0xFF7C3AED);

IconData _expCategoryIcon(String? cat) {
  switch (cat) {
    case 'food':          return Icons.restaurant_rounded;
    case 'travel':        return Icons.flight_rounded;
    case 'housing':       return Icons.home_rounded;
    case 'transport':     return Icons.directions_car_rounded;
    case 'entertainment': return Icons.celebration_rounded;
    case 'shopping':      return Icons.shopping_bag_rounded;
    case 'utilities':     return Icons.bolt_rounded;
    default:              return Icons.receipt_long_rounded;
  }
}

LinearGradient _expCategoryGradient(String? cat) {
  switch (cat) {
    case 'food':          return const LinearGradient(colors: [_kExpTeal, _kExpBlue], begin: Alignment.topLeft, end: Alignment.bottomRight);
    case 'travel':        return const LinearGradient(colors: [_kExpBlue, _kExpTeal], begin: Alignment.topLeft, end: Alignment.bottomRight);
    case 'housing':       return const LinearGradient(colors: [_kExpTeal, _kExpPurple], begin: Alignment.topLeft, end: Alignment.bottomRight);
    case 'transport':     return const LinearGradient(colors: [_kExpBlue, _kExpPurple], begin: Alignment.topLeft, end: Alignment.bottomRight);
    case 'entertainment': return const LinearGradient(colors: [_kExpPurple, _kExpBlue], begin: Alignment.topLeft, end: Alignment.bottomRight);
    case 'shopping':      return const LinearGradient(colors: [_kExpPurple, _kExpTeal], begin: Alignment.topLeft, end: Alignment.bottomRight);
    case 'utilities':     return const LinearGradient(colors: [_kExpTeal, _kExpBlue], begin: Alignment.topLeft, end: Alignment.bottomRight);
    default:              return const LinearGradient(colors: [_kExpBlue, _kExpTeal], begin: Alignment.topLeft, end: Alignment.bottomRight);
  }
}

class ExpensesListScreen extends ConsumerWidget {
  final Group group;
  const ExpensesListScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    // Wait for auth to finish loading before rendering, so userId is always valid.
    if (auth.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final expensesAsync = ref.watch(expensesProvider(group.id));
    final prefCurrency = auth.preferredCurrency;

    // Fetch exchange rate: group base currency → user's preferred currency (once for whole list)
    final rateAsync = group.baseCurrency == prefCurrency
        ? null
        : ref.watch(conversionProvider(
            conversionParams(from: group.baseCurrency, to: prefCurrency, amount: 1.0)));

    return expensesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context)!.errorLoadingExpenses,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(expensesProvider(group.id)),
              child: Text(AppLocalizations.of(context)!.tryAgain),
            ),
          ],
        ),
      ),
      data: (expenses) {
        if (expenses.isEmpty) return _EmptyExpenses();

        // Rate = null when currencies match (rate = 1.0)
        final rate = rateAsync?.valueOrNull?.rate ?? 1.0;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(expensesProvider(group.id)),
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: expenses.length,
            itemBuilder: (context, i) {
              final expense = expenses[i];
              return _ExpenseItem(
                expense: expense,
                groupCurrency: group.baseCurrency,
                prefCurrency: prefCurrency,
                conversionRate: rate,
                onEdit: (expense.isCreator && !expense.isSystemExpense)
                    ? () async {
                        final edited = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditExpenseScreen(
                              group: group,
                              expense: expense,
                            ),
                          ),
                        );
                        if (edited == true && context.mounted) {
                          ref.invalidate(expensesProvider(group.id));
                        }
                      }
                    : null,
              );
            },
          ),
        );
      },
    );
  }
}

class _ExpenseItem extends StatelessWidget {
  final Expense expense;
  final String groupCurrency;
  final String prefCurrency;
  final double conversionRate;
  final VoidCallback? onEdit;

  const _ExpenseItem({
    required this.expense,
    required this.groupCurrency,
    required this.prefCurrency,
    required this.conversionRate,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    // Use server-computed flags to avoid client-side userId comparison race conditions
    final isPayer = expense.isPayer;
    // System expenses (platform payments) are never editable
    final isCreator = expense.isCreator && !expense.isSystemExpense;

    // Amounts in group base currency
    final convertedTotal =
        double.tryParse(expense.convertedAmount) ?? expense.amountDouble;
    final myShare = double.tryParse(expense.myShare) ?? 0.0;
    final net = isPayer ? (convertedTotal - myShare) : -myShare;
    final isPositive = net >= 0;

    // Convert to preferred currency
    final prefTotal = convertedTotal * conversionRate;
    final prefNet = net * conversionRate;
    final showConversion = prefCurrency != expense.originalCurrency;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isCreator ? onEdit : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                // Category icon — iOS style (gradient bg + white icon)
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: _expCategoryGradient(expense.category),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _expCategoryIcon(expense.category),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Title + payer
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              expense.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCreator)
                            const Icon(Icons.edit_outlined,
                                size: 14, color: AppColors.textDisabled),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isPayer
                            ? AppLocalizations.of(context)!.youPaid
                            : AppLocalizations.of(context)!.paidByPerson(expense.paidByName ?? ''),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      if (expense.createdAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _formatDateTime(expense.createdAt!),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textDisabled),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Right column: original big + conversion below
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // PRIMARY — original amount (what was actually paid)
                    Text(
                      '${expense.originalAmount} ${expense.originalCurrency}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 3),
                    // SECONDARY — conversion to preferred + user's share
                    if (showConversion)
                      Text(
                        '≈ ${prefTotal.round()} $prefCurrency',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textDisabled),
                      ),
                    Text(
                      '${AppLocalizations.of(context)!.yourShare} ${isPositive ? '+' : ''}${prefNet.round()} $prefCurrency',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isPositive
                            ? AppColors.positive
                            : AppColors.negative,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  final d = '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year}';
  final t = '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return '$d | $t';
}

class _EmptyExpenses extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 32,
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noExpenses,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)!.noExpensesHint,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
