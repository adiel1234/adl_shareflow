import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/balances/data/balance_repository.dart';
import '../../../../providers/balances_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/expenses_provider.dart';
import '../../../groups/domain/group_model.dart';
import '../../../groups/domain/period_report_model.dart';
import '../../../../providers/groups_provider.dart';
import '../../domain/balance_model.dart';
import '../../../../theme/app_colors.dart';
import '../../../../ui/widgets/amount_display.dart';
import '../../../../l10n/app_localizations.dart';
import 'event_summary_screen.dart';
import '../../../groups/presentation/screens/payment_options_screen.dart';

// ── Provider for period reports ──────────────────────────────────────────────

final periodReportsProvider = FutureProvider.autoDispose
    .family<List<PeriodReport>, String>((ref, groupId) async {
  return ref.read(groupRepositoryProvider).fetchPeriodReports(groupId);
});

// ── Main screen ──────────────────────────────────────────────────────────────

class BalancesScreen extends ConsumerStatefulWidget {
  final Group group;
  const BalancesScreen({super.key, required this.group});

  @override
  ConsumerState<BalancesScreen> createState() => _BalancesScreenState();
}

class _BalancesScreenState extends ConsumerState<BalancesScreen> {
  bool _settling = false;

  Future<void> _settlePeriod() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dl.settlePeriodDialogTitle),
          content: Text(dl.settlePeriodConfirmMsg),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(dl.cancel)),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(dl.settlePeriodBtn)),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _settling = true);
    try {
      await ref.read(groupRepositoryProvider).settlePeriod(widget.group.id);
      if (!mounted) return;
      ref.invalidate(balancesProvider(widget.group.id));
      ref.invalidate(periodReportsProvider(widget.group.id));
      ref.invalidate(expensesProvider(widget.group.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.settlePeriodSuccess)),
      );
    } catch (e) {
      if (!mounted) return;
      String msg = l.errorSettlingPeriod;
      if (e is DioException) {
        msg = (e.response?.data?['message'] as String?) ?? msg;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _settling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final auth = ref.watch(authProvider);

    if (auth.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final balancesAsync     = ref.watch(balancesProvider(group.id));
    final periodReportsAsync = ref.watch(periodReportsProvider(group.id));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(balancesProvider(group.id));
        ref.invalidate(periodReportsProvider(group.id));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // Total expenses summary card
          _TotalExpensesCard(group: group),
          const SizedBox(height: 12),

          // "סכם תקופה" button — admin, periodic groups
          if (group.isAdmin && group.isPeriodic)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: const Color(0xFF059669),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _settling ? null : _settlePeriod,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        _settling
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.calculate_outlined,
                                color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                  Text(AppLocalizations.of(context)!.settlePeriodBtn,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                              Text(
                                group.nextSettlementDate != null
                                    ? AppLocalizations.of(context)!.settlePeriodNext(_fmtDate(group.nextSettlementDate!))
                                    : AppLocalizations.of(context)!.settlePeriodCreateReport,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // "סכם אירוע" button — admin, non-periodic groups
          if (group.isAdmin && !group.isPeriodic)
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
                      builder: (_) => EventSummaryScreen(group: group),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.summarize_outlined,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  AppLocalizations.of(context)!.summarizeEvent,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              Text(
                                  AppLocalizations.of(context)!
                                      .sendSummaryToMembers,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // My balance card — current period
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

          // All balances — current period
          balancesAsync.when(
            loading: () => const _LoadingCard(),
            error: (_, __) =>
                Center(child: Text(AppLocalizations.of(context)!.errorLoadingBalances)),
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

          const SizedBox(height: 16),

          // Open debts transfer plan — prominent for closed groups
          Consumer(
            builder: (context, ref, _) {
              final group = widget.group;
              final planAsync = ref.watch(settlementPlanProvider(group.id));
              return planAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (suggestions) {
                  if (suggestions.isEmpty) return const SizedBox.shrink();
                  return _TransfersCard(
                    group: group,
                    suggestions: suggestions,
                  );
                },
              );
            },
          ),

          // Period reports history
          periodReportsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (reports) {
              if (reports.isEmpty) return const SizedBox.shrink();
              return _PeriodReportsHistory(
                  reports: reports,
                  currentUserId: auth.userId ?? '',
                  groupId: group.id,
                  ref: ref);
            },
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}

// ── Period reports history ───────────────────────────────────────────────────

class _PeriodReportsHistory extends StatelessWidget {
  final List<PeriodReport> reports;
  final String currentUserId;
  final String groupId;
  final WidgetRef ref;

  const _PeriodReportsHistory({
    required this.reports,
    required this.currentUserId,
    required this.groupId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.previousPeriodReports,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        ...reports.map((r) => _PeriodReportCard(
              report: r,
              currentUserId: currentUserId,
              groupId: groupId,
              ref: ref,
            )),
      ],
    );
  }
}

class _PeriodReportCard extends StatelessWidget {
  final PeriodReport report;
  final String currentUserId;
  final String groupId;
  final WidgetRef ref;

  const _PeriodReportCard({
    required this.report,
    required this.currentUserId,
    required this.groupId,
    required this.ref,
  });

  Future<void> _markPaid(BuildContext context, PeriodDebt debt) async {
    try {
      await ref.read(groupRepositoryProvider).markDebtPaid(debt.id);
      ref.invalidate(periodReportsProvider(groupId));
    } catch (e) {
      if (!context.mounted) return;
      String msg = 'שגיאה בסימון תשלום';
      if (e is DioException) {
        msg = (e.response?.data?['message'] as String?) ?? msg;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnpaid = report.hasUnpaidDebts;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasUnpaid ? const Color(0xFFEF4444).withOpacity(0.4) : AppColors.border,
          width: hasUnpaid ? 1.5 : 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(builder: (ctx) => Text(
                      AppLocalizations.of(ctx)!.periodLabel(report.periodNumber),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    )),
                    Text(
                      '${_fmtDate(report.periodStart)} – ${_fmtDate(report.periodEnd)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${report.totalExpenses.round()} ${report.currency}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  if (hasUnpaid)
                    Builder(builder: (ctx) => Text(
                      report.unpaidCount == 1
                          ? AppLocalizations.of(ctx)!.openDebtCount
                          : AppLocalizations.of(ctx)!.openDebtsCount(report.unpaidCount),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFEF4444)),
                    ))
                  else
                    Builder(builder: (ctx) => Text(
                      AppLocalizations.of(ctx)!.allDebtsPaid,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF059669)),
                    )),
                ],
              ),
            ],
          ),
          children: report.debts.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Builder(builder: (ctx) => Text(
                      AppLocalizations.of(ctx)!.noDebtsBalanced,
                      style: const TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    )),
                  ),
                ]
              : report.debts
                  .map((d) => _DebtRow(
                        debt: d,
                        currentUserId: currentUserId,
                        onMarkPaid: () => _markPaid(context, d),
                      ))
                  .toList(),
        ),
      ),
    );
  }

  static String _fmtDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}

class _DebtRow extends StatelessWidget {
  final PeriodDebt debt;
  final String currentUserId;
  final VoidCallback onMarkPaid;

  const _DebtRow({
    required this.debt,
    required this.currentUserId,
    required this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    final isPaidColor = const Color(0xFF059669);
    final isCreditor = debt.toUserId == currentUserId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: debt.isPaid
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            debt.isPaid ? Icons.check_circle : Icons.schedule,
            size: 16,
            color: debt.isPaid ? isPaidColor : const Color(0xFFEF4444),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: debt.fromName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const TextSpan(
                    text: ' → ',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  TextSpan(
                    text: debt.toName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${debt.amount.round()} ${debt.currency}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: debt.isPaid ? isPaidColor : const Color(0xFFEF4444),
            ),
          ),
          // Only creditor can mark as paid
          if (!debt.isPaid && isCreditor) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onMarkPaid,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPaidColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Builder(builder: (ctx) => Text(
                  AppLocalizations.of(ctx)!.markAsPaid,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                )),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Open debts transfer card ─────────────────────────────────────────────────

class _TransfersCard extends ConsumerStatefulWidget {
  final Group group;
  final List<SettlementSuggestion> suggestions;

  const _TransfersCard({required this.group, required this.suggestions});

  @override
  ConsumerState<_TransfersCard> createState() => _TransfersCardState();
}

class _TransfersCardState extends ConsumerState<_TransfersCard> {
  void _openPayment(BuildContext context, SettlementSuggestion s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentOptionsScreen(
          recipientName: s.toDisplayName,
          amount: s.amountDouble,
          currency: s.currency,
          recipientPhone: s.toPaymentPhone,
          bankName: s.toBankName,
          bankBranch: s.toBankBranch,
          bankAccountNumber: s.toBankAccountNumber,
        ),
      ),
    );
  }

  Future<void> _scheduleReminder(BuildContext context, SettlementSuggestion s) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('he'),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !context.mounted) return;

    final sendAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (sendAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הזמן שנבחר כבר עבר')),
      );
      return;
    }

    try {
      await BalanceRepository().scheduleReminder(
        groupId: widget.group.id,
        sendAt: sendAt,
        toUserId: s.fromUserId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'תזכורת נקבעה ל-${time.format(context)} ב-${date.day}/${date.month}',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('שגיאה בקביעת התזכורת')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authProvider).userId;
    final group = widget.group;
    final suggestions = widget.suggestions;
    final isClosed = group.isClosed;
    final headerColor = isClosed ? const Color(0xFFEF4444) : const Color(0xFF6366F1);
    final bgColor     = isClosed ? const Color(0xFFFEF2F2) : const Color(0xFFF0F0FF);
    final borderColor = isClosed
        ? const Color(0xFFEF4444).withOpacity(0.4)
        : const Color(0xFF6366F1).withOpacity(0.3);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isClosed ? Icons.warning_amber_rounded : Icons.swap_horiz_rounded,
                color: headerColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Builder(builder: (ctx) => Text(
                isClosed
                    ? AppLocalizations.of(ctx)!.openDebtsGroupClosed
                    : AppLocalizations.of(ctx)!.requiredTransfersTitle,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: headerColor,
                ),
              )),
            ],
          ),
          if (isClosed)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Builder(builder: (ctx) => Text(
                AppLocalizations.of(ctx)!.groupClosedUnpaidDebts,
                style: TextStyle(fontSize: 12, color: headerColor.withOpacity(0.8)),
              )),
            )
          else
            const SizedBox(height: 12),
          ...suggestions.map(
            (s) {
              final isMyDebt = s.fromUserId == currentUserId;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Builder(builder: (ctx) {
                        final dl = AppLocalizations.of(ctx)!;
                        final text = dl.transferNeeded(s.fromDisplayName, s.toDisplayName);
                        return Text(text, style: const TextStyle(fontSize: 13));
                      }),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: headerColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${s.amountDouble.round()} ${s.currency}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (isMyDebt) ...[
                      const SizedBox(width: 8),
                      Builder(builder: (ctx) {
                        final dl = AppLocalizations.of(ctx)!;
                        return TextButton(
                          onPressed: () => _openPayment(ctx, s),
                          style: TextButton.styleFrom(
                            foregroundColor: headerColor,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            dl.pay,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        );
                      }),
                    ],
                    if (!isMyDebt && s.toUserId == currentUserId) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.alarm_add_outlined,
                            size: 20, color: headerColor),
                        onPressed: () => _scheduleReminder(context, s),
                        tooltip: 'קבע תזכורת',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Existing widgets (unchanged) ─────────────────────────────────────────────

class _MyBalanceCard extends StatelessWidget {
  final UserBalance balance;
  final String currency;

  const _MyBalanceCard({required this.balance, required this.currency});

  @override
  Widget build(BuildContext context) {
    final gradient = balance.isPositive
        ? AppColors.positiveGradient
        : AppColors.negativeGradient;
    final l = AppLocalizations.of(context)!;
    final label = balance.isCreditor
        ? l.owesYouLabel
        : balance.isDebtor
            ? l.youOwe
            : l.balanceSettled;

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

  const _BalancesList({required this.balances, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.groupBalances,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        ...balances.map((b) => _MemberBalanceRow(balance: b, currency: currency)),
      ],
    );
  }
}

class _MemberBalanceRow extends StatelessWidget {
  final UserBalance balance;
  final String currency;

  const _MemberBalanceRow({required this.balance, required this.currency});

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
                    ? AppLocalizations.of(context)!.settled
                    : balance.isCreditor
                        ? AppLocalizations.of(context)!.owesHimLabel
                        : AppLocalizations.of(context)!.owesLabel,
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
        // Show only current-period expenses (no period_report_id)
        final currentExpenses =
            expenses.where((e) => e.periodReportId == null).toList();
        final count = currentExpenses.length;

        final currencyTotals = <String, double>{};
        for (final e in currentExpenses) {
          final c = e.originalCurrency;
          final a = double.tryParse(e.originalAmount) ?? 0;
          currencyTotals[c] = (currencyTotals[c] ?? 0) + a;
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
                    Text(
                      group.isPeriodic
                          ? AppLocalizations.of(context)!.currentPeriodExpenses
                          : AppLocalizations.of(context)!.groupTotalExpenses,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    if (currencyTotals.isEmpty)
                      const Text(
                        '0',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800),
                      )
                    else
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
                    if (group.isPeriodic && group.currentPeriodStart != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          AppLocalizations.of(context)!.periodSince(_fmtDate(group.currentPeriodStart!)),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                        ),
                      ),
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
                  Text(
                    AppLocalizations.of(context)!.expensesCountLabel,
                    style: const TextStyle(
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

  static String _fmtDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}
