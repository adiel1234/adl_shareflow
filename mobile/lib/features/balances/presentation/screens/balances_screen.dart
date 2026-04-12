import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/balances_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/expenses_provider.dart';
import '../../../groups/domain/group_model.dart';
import '../../domain/balance_model.dart';
import '../../../../theme/app_colors.dart';
import '../../../../ui/widgets/amount_display.dart';
import 'event_summary_screen.dart';

class BalancesScreen extends ConsumerWidget {
  final Group group;
  const BalancesScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (auth.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final balancesAsync = ref.watch(balancesProvider(group.id));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(balancesProvider(group.id));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // Total expenses summary card
          _TotalExpensesCard(group: group),
          const SizedBox(height: 12),

          // "סכם אירוע" button — admin only
          if (group.isAdmin)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EventSummaryScreen(group: group),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.summarize_outlined,
                            color: Colors.white, size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text('סכם אירוע',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              Text('שלח סיכום וחלוקת עלויות לחברים',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // My balance card
          balancesAsync.when(
            loading: () => const _LoadingCard(),
            error: (_, __) => const SizedBox.shrink(),
            data: (data) {
              final balances =
                  (data['balances'] as List).cast<UserBalance>();
              final currency = data['currency'] as String;
              final myBalance = balances
                  .where((b) => b.userId == auth.userId)
                  .firstOrNull;
              if (myBalance == null) return const SizedBox.shrink();
              return _MyBalanceCard(
                  balance: myBalance, currency: currency);
            },
          ),

          const SizedBox(height: 16),

          // All balances
          balancesAsync.when(
            loading: () => const _LoadingCard(),
            error: (_, __) =>
                const Center(child: Text('שגיאה בטעינת יתרות')),
            data: (data) {
              final balances =
                  (data['balances'] as List).cast<UserBalance>();
              final currency = data['currency'] as String;
              return _BalancesList(
                balances: balances,
                currency: currency,
              );
            },
          ),

        ],
      ),
    );
  }
}

class _MyBalanceCard extends StatelessWidget {
  final UserBalance balance;
  final String currency;

  const _MyBalanceCard({required this.balance, required this.currency});

  @override
  Widget build(BuildContext context) {
    final gradient = balance.isPositive
        ? AppColors.positiveGradient
        : AppColors.negativeGradient;
    final label = balance.isCreditor
        ? 'חייבים לך'
        : balance.isDebtor
            ? 'אתה חייב'
            : 'מסודר ✅';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: balance.isSettled ? null : gradient,
        color: balance.isSettled ? AppColors.surfaceVariant : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: balance.isSettled ? AppColors.textSecondary : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          AmountDisplay(
            amount: balance.netDouble.abs().toStringAsFixed(2),
            currency: currency,
            isPositive: balance.isCreditor,
            isNegative: balance.isDebtor,
            fontSize: 40,
          ),
        ],
      ),
    );
  }
}

class _BalancesList extends StatelessWidget {
  final List<UserBalance> balances;
  final String currency;

  const _BalancesList({
    required this.balances,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'יתרות הקבוצה',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        ...balances.map((b) => _MemberBalanceRow(
              balance: b,
              currency: currency,
            )),
      ],
    );
  }
}

class _MemberBalanceRow extends StatelessWidget {
  final UserBalance balance;
  final String currency;

  const _MemberBalanceRow({
    required this.balance,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final net = balance.netDouble;
    final isPos = net >= 0;
    final color = balance.isSettled
        ? AppColors.neutral
        : isPos
            ? AppColors.positive
            : AppColors.negative;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceVariant,
            child: Text(
              balance.displayName.isNotEmpty
                  ? balance.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              balance.displayName,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPos ? '+' : ''}${net.round()} $currency',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: color,
                ),
              ),
              Text(
                balance.isSettled
                    ? 'מסודר'
                    : balance.isCreditor
                        ? 'חייבים לו'
                        : 'חייב',
                style: TextStyle(fontSize: 11, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _TotalExpensesCard extends ConsumerWidget {
  final Group group;
  const _TotalExpensesCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider(group.id));

    return expensesAsync.when(
      loading: () => const _LoadingCard(),
      error: (_, __) => const SizedBox.shrink(),
      data: (expenses) {
        final count = expenses.length;

        // Group totals by original currency
        final currencyTotals = <String, double>{};
        for (final e in expenses) {
          final currency = e.originalCurrency;
          final amount = double.tryParse(e.originalAmount) ?? 0;
          currencyTotals[currency] = (currencyTotals[currency] ?? 0) + amount;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text('💳', style: TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'סך הוצאות הקבוצה',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    ...currencyTotals.entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '${entry.value.round()} ${entry.key}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'הוצאות',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
