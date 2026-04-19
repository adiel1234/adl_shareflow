import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/network/api_client.dart';
import '../../data/group_repository.dart';
import '../../domain/group_model.dart';
import '../../../../providers/expenses_provider.dart';
import '../../../../providers/balances_provider.dart';
import '../../../../providers/groups_provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../ui/widgets/amount_display.dart';
import '../../../../services/share_service.dart';
import '../../../expenses/presentation/screens/expenses_list_screen.dart';
import '../../../expenses/presentation/screens/add_expense_screen.dart';
import '../../../balances/presentation/screens/balances_screen.dart';
import '../widgets/group_state_banner.dart';
import 'members_tab_screen.dart';
import 'activation_screen.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final Group group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 130,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(56, 12, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          group.categoryEmoji,
                          style: const TextStyle(fontSize: 30),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
              child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              group.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (group.isClosed)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '🔒 סגורה',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              title: null,
              titlePadding: EdgeInsetsDirectional.zero,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.link, color: Colors.white),
                onPressed: () => _showInvite(context, group),
              ),
              if (group.isAdmin && !group.isClosed)
                IconButton(
                  icon: const Icon(Icons.lock_outline, color: Colors.white),
                  tooltip: AppLocalizations.of(context)!.closeGroup,
                  onPressed: () => _closeGroup(context, group),
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
                Tab(text: AppLocalizations.of(context)!.expenses),
                Tab(text: AppLocalizations.of(context)!.balances),
                Tab(text: AppLocalizations.of(context)!.members),
              ],
            ),
          ),
        ],
        body: Column(
          children: [
            GroupStateBanner(
              group: group,
              onActionTap: group.isAdmin && !group.isOperational
                  ? () => _openActivation(context, group)
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
      floatingActionButton: (group.isClosed || !group.isOperational)
          ? null
          : _NewExpenseFab(
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
                });
              },
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

  void _showInvite(BuildContext context, Group group) async {
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(groupRepositoryProvider);

    // Ask the inviter how the new member should split expenses
    final splitMode = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l.splitExpenses,
            style: const TextStyle(fontWeight: FontWeight.w700),
            textAlign: TextAlign.right),
        content: Text(l.howShouldNewMemberJoin,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.right),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          _SplitOptionButton(
            icon: Icons.history,
            color: AppColors.primary,
            title: l.splitAll,
            subtitle: l.includePastExpenses,
            onTap: () => Navigator.pop(ctx, 'full'),
          ),
          const SizedBox(height: 8),
          _SplitOptionButton(
            icon: Icons.arrow_forward,
            color: AppColors.secondary,
            title: l.fromNowOn,
            subtitle: l.notChargedPast,
            onTap: () => Navigator.pop(ctx, 'forward'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(l.cancel,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
    if (splitMode == null || !context.mounted) return;

    try {
      final data = await repo.fetchInviteLink(group.id, splitMode: splitMode);
      final code = data['invite_code'] as String;
      final link = data['invite_link'] as String;

      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _InviteSheet(
          code: code,
          link: link,
          groupId: group.id,
          groupName: group.name,
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.errorLoadingInvite)),
        );
      }
    }
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

  /// First try to close (without force) to detect debts upfront.
  Future<void> _preflight() async {
    try {
      await widget.repo.closeGroup(widget.group.id);
      if (mounted) {
        Navigator.pop(context);
        widget.onClosed();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.groupClosedSuccess)),
        );
      }
    } on DioException catch (e) {
      final body = e.response?.data as Map<String, dynamic>?;
      final list = (body?['errors']?['unsettled'] as List?)
          ?.cast<Map<String, dynamic>>();
      if (list != null && list.isNotEmpty) {
        if (mounted) setState(() { _unsettled = list; _phase = _ClosePhase.hasDebts; });
      } else {
        // Clean close — show simple confirm
        if (mounted) setState(() => _phase = _ClosePhase.confirm);
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
  const _InviteSheet({required this.code, required this.link, required this.groupId, required this.groupName});

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _emailController = TextEditingController();
  bool _sendingEmail = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.inviteFriends,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
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
