import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/network/api_client.dart';
import '../../data/group_repository.dart';
import '../../domain/group_model.dart';
import '../../../../providers/expenses_provider.dart';
import '../../../../providers/balances_provider.dart';
import '../../../../providers/groups_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/currency_provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../ui/widgets/amount_display.dart';
import '../../../../core/utils/currency_format.dart';
import '../../../../services/share_service.dart';
import '../../../expenses/presentation/screens/expenses_list_screen.dart';
import '../../../expenses/presentation/screens/add_expense_screen.dart';
import '../../../balances/presentation/screens/balances_screen.dart';
import '../widgets/group_state_banner.dart';
import '../widgets/invite_sheet.dart';
import 'members_tab_screen.dart';
import 'activation_screen.dart';
import '../../../home/presentation/widgets/group_coach.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final Group group;
  final int initialTabIndex;
  final bool openInviteOnStart;
  /// Re-run group button tour even if already completed.
  final bool forceCoach;
  /// After the tour ends (close/done), pop back to the previous screen (home).
  final bool popOnCoachEnd;
  /// Continues a unified home+group tour counter (e.g. steps 6–10 of 10).
  final int coachStepOffset;
  final int? coachTotalSteps;
  const GroupDetailScreen({
    super.key,
    required this.group,
    this.initialTabIndex = 0,
    this.openInviteOnStart = false,
    this.forceCoach = false,
    this.popOnCoachEnd = false,
    this.coachStepOffset = 0,
    this.coachTotalSteps,
  });

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _inviteKey = GlobalKey();
  final _expensesTabKey = GlobalKey();
  final _balancesTabKey = GlobalKey();
  final _membersTabKey = GlobalKey();
  final _fabKey = GlobalKey();
  bool _groupCoachStarted = false;
  bool _inviteOpened = false;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTabIndex.clamp(0, 2);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabIndex = initialIndex;
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() => _tabIndex = _tabController.index);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeShowGroupCoach();
      await _maybeOpenInvite();
    });
  }

  Future<void> _maybeOpenInvite() async {
    if (_inviteOpened || !widget.openInviteOnStart || !mounted) return;
    _inviteOpened = true;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final group = ref.read(groupDetailProvider(widget.group.id)).maybeWhen(
          data: (g) => g,
          orElse: () => widget.group,
        );
    if (group.isClosed || !group.isOperational) return;
    _showInvite(context, group);
  }

  Future<void> _maybeShowGroupCoach() async {
    if (_groupCoachStarted || !mounted) return;
    _groupCoachStarted = true;
    if (!widget.forceCoach && await isGroupCoachDone()) return;
    // Let header + FAB layout settle.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final group = ref.read(groupDetailProvider(widget.group.id)).maybeWhen(
          data: (g) => g,
          orElse: () => widget.group,
        );
    if (group.isClosed || !group.isOperational) {
      if (!widget.forceCoach) await markGroupCoachDone();
      return;
    }

    final l = AppLocalizations.of(context)!;
    final groupTargets = buildGroupCoachTargets(
      l: l,
      inviteKey: _inviteKey,
      expensesTabKey: _expensesTabKey,
      fabKey: _fabKey,
      balancesTabKey: _balancesTabKey,
      membersTabKey: _membersTabKey,
      tabController: _tabController,
    );
    await showGroupCoach(
      context,
      markDone: !widget.forceCoach,
      stepOffset: widget.coachStepOffset,
      totalSteps: widget.coachTotalSteps ?? groupTargets.length,
      targets: groupTargets,
    );
    if (widget.popOnCoachEnd && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailProvider(widget.group.id));
    final group = groupAsync.maybeWhen(data: (g) => g, orElse: () => widget.group);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            // Tall header: hero title, gap, totals, then tabs — no overlap.
            expandedHeight: 300,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            // Name is laid out explicitly below (not FlexibleSpaceBar.title),
            // so it cannot collide with the totals card.
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 52),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Clear the toolbar icon row (back + actions).
                        const SizedBox(height: 44),
                        Text(
                          '${group.categoryEmoji} ${group.name}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 18),
                        _buildGroupTotalsBar(context, group),
                        if (group.isClosed) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '🔒 סגורה',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                key: _inviteKey,
                icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                tooltip: AppLocalizations.of(context)!.inviteFriends,
                onPressed: () => _showInvite(context, group),
              ),
              if (group.isAdmin && !group.isClosed)
                IconButton(
                  icon: const Icon(Icons.lock_outline, color: Colors.white),
                  tooltip: AppLocalizations.of(context)!.closeGroupShortHint,
                  onPressed: () => _closeGroup(context, group),
                ),
              if (group.isAdmin)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'delete') _deleteGroup(context, group);
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 10),
                          Text(AppLocalizations.of(ctx)!.deleteGroup,
                              style: const TextStyle(color: Color(0xFFEF4444))),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 2.5,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
              tabs: [
                Tab(key: _expensesTabKey, text: AppLocalizations.of(context)!.expenses),
                Tab(key: _balancesTabKey, text: AppLocalizations.of(context)!.balances),
                Tab(key: _membersTabKey, text: AppLocalizations.of(context)!.members),
              ],
            ),
          ),
        ],
        body: Column(
          children: [
            GroupStateBanner(
              group: group,
              onActionTap: group.isAdmin
                  ? () {
                      if (group.isClosed) {
                        _showRestoreOptions(context, group);
                      } else if (!group.isOperational ||
                          group.tierUpgradeRequired) {
                        _openActivation(context, group);
                      }
                    }
                  : null,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  ExpensesListScreen(group: group),
                  BalancesScreen(group: group),
                  MembersTabScreen(group: group),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: (group.isClosed || !group.isOperational || _tabIndex != 0)
          ? null
          : KeyedSubtree(
              key: _fabKey,
              child: _NewExpenseFab(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddExpenseScreen(group: group),
                    ),
                  ).then((_) {
                    ref.invalidate(expensesProvider(group.id));
                    ref.invalidate(balancesProvider(group.id));
                    ref.invalidate(groupDetailProvider(group.id));
                    ref.invalidate(groupsProvider);
                  });
                },
              ),
            ),
    );
  }

  void _openActivation(BuildContext context, Group group) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ActivationScreen(group: group)),
    );
    if (result == true) {
      ref.invalidate(groupsProvider);
      ref.invalidate(expensesProvider(group.id));
      ref.invalidate(balancesProvider(group.id));
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _showRestoreOptions(BuildContext context, Group group) async {
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final dl = AppLocalizations.of(ctx)!;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            dl.restoreGroupDialogTitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
            textAlign: TextAlign.right,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SplitOptionButton(
                  icon: Icons.history,
                  color: AppColors.primary,
                  title: dl.restoreGroupOptionReopen,
                  subtitle: dl.restoreGroupOptionReopenSubtitle,
                  onTap: () => Navigator.pop(ctx, 'reopen'),
                ),
                const SizedBox(height: 8),
                _SplitOptionButton(
                  icon: Icons.copy_all_outlined,
                  color: AppColors.secondary,
                  title: dl.restoreGroupOptionDuplicate,
                  subtitle: dl.restoreGroupOptionDuplicateSubtitle,
                  onTap: () => Navigator.pop(ctx, 'duplicate'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(dl.cancel,
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        );
      },
    );

    if (choice == null || !mounted) return;
    if (choice == 'reopen') {
      await _reopenGroup(context, group);
    } else if (choice == 'duplicate') {
      await _duplicateGroup(context, group);
    }
  }

  Future<void> _reopenGroup(BuildContext context, Group group) async {
    final l = AppLocalizations.of(context)!;
    try {
      final reopened = await ref.read(groupRepositoryProvider).reopenGroup(group.id);
      if (!mounted) return;
      ref.invalidate(groupsProvider);
      ref.invalidate(groupDetailProvider(group.id));
      ref.invalidate(expensesProvider(group.id));
      ref.invalidate(balancesProvider(group.id));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GroupDetailScreen(group: reopened),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.reopenGroupSuccess)),
      );
    } catch (e) {
      if (!mounted) return;
      String msg = l.errorReopeningGroup;
      if (e is DioException) {
        msg = (e.response?.data?['message'] as String?) ?? msg;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _duplicateGroup(BuildContext context, Group group) async {
    final l = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: '${group.name} (2)');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dl.duplicateGroupDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                dl.duplicateGroupDialogBody,
                style: const TextStyle(
                    color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: dl.duplicateGroupNameHint,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(dl.cancel)),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(dl.duplicateGroupBtn),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final newName = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (newName.isEmpty) return;

    try {
      final (newGroup, limitReached) = await ref
          .read(groupRepositoryProvider)
          .duplicateGroup(group.id, name: newName);
      if (!mounted) return;
      ref.invalidate(groupsProvider);

      if (limitReached && !newGroup.isOperational) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(l.freeGroupLimitReachedTitle),
            content: Text(l.freeGroupLimitReachedBody),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupDetailScreen(group: newGroup),
                    ),
                  );
                },
                child: Text(l.laterBtn),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupDetailScreen(group: newGroup),
                    ),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActivationScreen(group: newGroup),
                    ),
                  );
                },
                child: Text(l.activateGroupBtn),
              ),
            ],
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GroupDetailScreen(group: newGroup),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.duplicateGroupSuccess)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      String msg = l.errorDuplicatingGroup;
      if (e is DioException) {
        msg = (e.response?.data?['message'] as String?) ?? msg;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _deleteGroup(BuildContext context, Group group) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dl.deleteGroupDialogTitle,
              style: const TextStyle(color: Color(0xFFEF4444))),
          content: Text(dl.deleteGroupConfirm(group.name)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(dl.cancel)),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white),
              child: Text(dl.deleteGroupPermanently),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    await _doDeleteGroup(context, group, force: false);
  }

  Future<void> _doDeleteGroup(
    BuildContext context,
    Group group, {
    required bool force,
  }) async {
    final l = AppLocalizations.of(context)!;
    try {
      await ref
          .read(groupRepositoryProvider)
          .deleteGroup(group.id, force: force);
      if (!mounted) return;
      ref.invalidate(groupsProvider);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.groupDeletedSuccess)),
      );
    } catch (e) {
      if (!mounted) return;
      String msg = l.errorDeletingGroup;
      int? statusCode;
      if (e is DioException) {
        statusCode = e.response?.statusCode;
        msg = (e.response?.data?['message'] as String?) ?? msg;
      }
      if (statusCode == 409) {
        // Open debts exist — ask admin to force-confirm
        final forceConfirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('קיימים חובות פתוחים',
                  style: TextStyle(color: Color(0xFFEF4444))),
              content: Text(msg),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(AppLocalizations.of(ctx)!.cancel)),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white),
                  child: const Text('מחק בכל זאת'),
                ),
              ],
            );
          },
        );
        if (forceConfirmed == true && mounted) {
          await _doDeleteGroup(context, group, force: true);
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _closeGroup(BuildContext context, Group group) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CloseGroupDialog(
        group: group,
        repo: ref.read(groupRepositoryProvider),
        onClosed: () {
          ref.invalidate(groupsProvider);
          Navigator.pop(context); // pop group detail screen
        },
      ),
    );
  }

  Widget _buildGroupTotalsBar(BuildContext context, Group group) {
    final l = AppLocalizations.of(context)!;
    final auth = ref.watch(authProvider);
    final prefCurrency = auth.preferredCurrency;
    final expenses =
        ref.watch(expensesProvider(group.id)).valueOrNull ?? const [];

    final currentExpenses =
        expenses.where((e) => e.periodReportId == null).toList();

    // Periodic groups: header total = current period only (not lifetime).
    var displayTotal = group.isPeriodic
        ? currentExpenses.fold<double>(
            0,
            (sum, e) => sum + (double.tryParse(e.convertedAmount) ?? 0),
          )
        : (double.tryParse(group.totalExpensesAmount) ?? 0);
    var displayCurrency = group.baseCurrency;
    if (prefCurrency != group.baseCurrency) {
      final convAsync = ref.watch(conversionProvider(
        conversionParams(
          from: group.baseCurrency,
          to: prefCurrency,
          amount: displayTotal,
        ),
      ));
      final conv = convAsync.valueOrNull;
      if (conv != null) {
        displayTotal = conv.convertedAmount;
        displayCurrency = prefCurrency;
      }
    } else {
      displayCurrency = prefCurrency;
    }

    final currencyTotals = <String, double>{};
    for (final e in currentExpenses) {
      final a = double.tryParse(e.originalAmount) ?? 0;
      if (a == 0) continue;
      currencyTotals[e.originalCurrency] =
          (currencyTotals[e.originalCurrency] ?? 0) + a;
    }
    if (currencyTotals.isEmpty && displayTotal > 0 && !group.isPeriodic) {
      currencyTotals[displayCurrency] = displayTotal;
    }
    final breakdown = currencyTotals.entries
        .map((e) => formatAmountWithCurrency(e.value, e.key))
        .join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.groupTotalExpenses,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatAmountWithCurrency(displayTotal, displayCurrency),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                if (breakdown.isNotEmpty &&
                    (currencyTotals.length > 1 ||
                        currencyTotals.keys.first != displayCurrency)) ...[
                  const SizedBox(height: 4),
                  Text(
                    breakdown,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 1,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: Colors.white.withValues(alpha: 0.25),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${group.expenseCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l.expensesCountLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showInvite(BuildContext context, Group group) {
    openInviteFlow(
      context,
      groupId: group.id,
      groupName: group.name,
      isAdmin: group.isAdmin,
      expenseCountHint: group.expenseCount,
      onGuestAdded: () {
        ref.invalidate(groupMembersProvider(group.id));
        ref.invalidate(balancesProvider(group.id));
        ref.invalidate(expensesProvider(group.id));
        ref.invalidate(groupDetailProvider(group.id));
        ref.invalidate(groupsProvider);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Close-group dialog — single unified flow
// ---------------------------------------------------------------------------

enum _ClosePhase { loading, confirm, hasDebts, closing }

class _CloseGroupDialog extends StatefulWidget {
  final Group group;
  final GroupRepository repo;
  final VoidCallback onClosed;

  const _CloseGroupDialog({
    required this.group,
    required this.repo,
    required this.onClosed,
  });

  @override
  State<_CloseGroupDialog> createState() => _CloseGroupDialogState();
}

class _CloseGroupDialogState extends State<_CloseGroupDialog> {
  _ClosePhase _phase = _ClosePhase.loading;
  List<Map<String, dynamic>> _unsettled = [];
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _preflight();
  }

  /// Check unsettled debts without closing (dry_run) — always require confirm.
  Future<void> _preflight() async {
    try {
      await widget.repo.closeGroup(widget.group.id, dryRun: true);
      if (mounted) setState(() => _phase = _ClosePhase.confirm);
    } on DioException catch (e) {
      final body = e.response?.data as Map<String, dynamic>?;
      final list = (body?['errors']?['unsettled'] as List?)
          ?.cast<Map<String, dynamic>>();
      if (list != null && list.isNotEmpty) {
        if (mounted) {
          setState(() {
            _unsettled = list;
            _phase = _ClosePhase.hasDebts;
          });
        }
      } else if (mounted) {
        setState(() => _phase = _ClosePhase.confirm);
      }
    } catch (_) {
      if (mounted) setState(() => _phase = _ClosePhase.confirm);
    }
  }

  Future<void> _doClose({bool force = false}) async {
    setState(() => _closing = true);
    try {
      await widget.repo.closeGroup(widget.group.id, force: force);
      if (mounted) {
        Navigator.pop(context);
        widget.onClosed();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.groupClosedSuccess)),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _closing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorClosingGroup)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.negative.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline,
                  color: AppColors.negative, size: 30),
            ),
            const SizedBox(height: 16),
            Builder(builder: (ctx) {
              final l = AppLocalizations.of(ctx)!;
              return Text(
              _phase == _ClosePhase.hasDebts
                  ? l.unsettledDebts
                  : l.closeGroup,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            );}),
            const SizedBox(height: 12),

            // Body content
            if (_phase == _ClosePhase.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              )
            else if (_phase == _ClosePhase.confirm)
              Text(
                AppLocalizations.of(context)!.closeGroupConfirm,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
              )
            else ...[
              // Unsettled debts section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.negative.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.negative.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppColors.negative, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          AppLocalizations.of(context)!.unsettledDebtsTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.negative),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ..._unsettled.map((u) {
                      final name = u['display_name'] ?? u['user_id'];
                      final amt = double.tryParse(u['net_amount'] ?? '0') ?? 0;
                      final currency =
                          u['currency'] ?? widget.group.baseCurrency;
                      final isDebtor = amt < 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  (isDebtor ? AppColors.negative : AppColors.positive)
                                      .withOpacity(0.12),
                              child: Text(
                                (name as String).isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDebtor
                                      ? AppColors.negative
                                      : AppColors.positive,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary),
                                  children: [
                                    TextSpan(
                                      text: name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    TextSpan(
                                        text: isDebtor ? ' חייב ' : ' זכאי ל'),
                                  ],
                                ),
                              ),
                            ),
                            Text(
                              '${amt.abs().round()} $currency',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isDebtor
                                    ? AppColors.negative
                                    : AppColors.positive,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(context)!.closeAnywayNote,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12, height: 1.4),
              ),
            ],

            const SizedBox(height: 20),

            // Buttons — only shown when not loading
            if (_phase != _ClosePhase.loading) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _closing
                      ? null
                      : () => _doClose(
                            force: _phase == _ClosePhase.hasDebts,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.negative,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _closing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          _phase == _ClosePhase.hasDebts
                              ? AppLocalizations.of(context)!.closeAnywayBtn
                              : AppLocalizations.of(context)!.closeGroup,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _closing
                      ? null
                      : () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InviteSheet extends StatefulWidget {
  final String code;
  final String link;
  final String groupId;
  final String groupName;
  final String splitMode;
  final int expenseCount;
  final bool isAdmin;
  final VoidCallback? onGuestAdded;
  const _InviteSheet({
    required this.code,
    required this.link,
    required this.groupId,
    required this.groupName,
    this.splitMode = 'forward',
    this.expenseCount = 0,
    this.isAdmin = false,
    this.onGuestAdded,
  });

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _emailController = TextEditingController();
  final _guestNameController = TextEditingController();
  bool _sendingEmail = false;
  bool _addingGuest = false;

  @override
  void dispose() {
    _emailController.dispose();
    _guestNameController.dispose();
    super.dispose();
  }

  Future<void> _addGuest() async {
    final name = _guestNameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _addingGuest = true);
    try {
      await GroupRepository().addGuest(
        widget.groupId,
        name,
        splitMode: widget.splitMode,
      );
      widget.onGuestAdded?.call();
      if (mounted) {
        _guestNameController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.guestAddedSuccess)),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        String msg = 'שגיאה בהוספת האורח';
        if (e is DioException) {
          msg = (e.response?.data?['message'] as String?) ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _addingGuest = false);
    }
  }

  Future<void> _sendEmailInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.invalidEmail)),
      );
      return;
    }
    setState(() => _sendingEmail = true);
    try {
      final api = ApiClient.instance;
      await api.post('/groups/${widget.groupId}/invite/email', data: {'email': email});
      if (mounted) {
        _emailController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.inviteSentTo(email))),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = AppLocalizations.of(context)!.errorSendingInvite;
        if (e is DioException) {
          msg = (e.response?.data?['message'] as String?) ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _sendingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Title row with close button
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.inviteFriends,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'סגור',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // QR Code
          _QrCodeCard(code: widget.code, link: widget.link),

          const SizedBox(height: 16),

          // Invite code text
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(AppLocalizations.of(context)!.inviteCode,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                Text(
                  widget.code,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.codeCopied)),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(AppLocalizations.of(context)!.copyCode),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.link));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.linkCopied)),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: Text(AppLocalizations.of(context)!.copyLink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => ShareService.shareViaWhatsApp(
                AppLocalizations.of(context)!.sendExpenseSplit(widget.groupName, widget.code, widget.link),
              ),
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: Text(AppLocalizations.of(context)!.sendViaWhatsApp),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              AppLocalizations.of(context)!.sendEmailInviteTitle,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: 'example@email.com',
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _sendingEmail
                  ? const SizedBox(
                      width: 42, height: 42,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton.filled(
                      onPressed: _sendEmailInvite,
                      icon: const Icon(Icons.send),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 8),

          // Guest section — admin only
          if (widget.isAdmin) ...[
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.addGuestTitle,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                // Info button — explains what a guest is
                GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (ctx) {
                      final l = AppLocalizations.of(ctx)!;
                      return AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: Row(
                          children: [
                            const Icon(Icons.person_outline,
                                color: Colors.purple, size: 20),
                            const SizedBox(width: 8),
                            Text(l.guestExplainTitle,
                                style: const TextStyle(fontSize: 15)),
                          ],
                        ),
                        content: Text(
                          l.guestExplainBody,
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: AppColors.textSecondary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('הבנתי'),
                          ),
                        ],
                      );
                    },
                  ),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.info_outline,
                        size: 18, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Explanatory subtitle
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purple.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: Colors.purple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.guestNoApp,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.purple,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _guestNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.addGuestHint,
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      prefixIcon: const Icon(Icons.person_outline, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _addingGuest
                    ? const SizedBox(
                        width: 42, height: 42,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton.filled(
                        onPressed: _addGuest,
                        icon: const Icon(Icons.person_add),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}


class _NewExpenseFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _NewExpenseFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF0D9488)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x441D4ED8),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.addExpense,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplitOptionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SplitOptionButton({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                          fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QR Code card widget
// ---------------------------------------------------------------------------

class _QrCodeCard extends StatelessWidget {
  final String code;
  final String link;
  const _QrCodeCard({required this.code, required this.link});

  String get _qrData => link;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            l.qrCodeTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.qrCodeSubtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          QrImageView(
            data: _qrData,
            version: QrVersions.auto,
            size: 200,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF1A1A2E),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }
}
