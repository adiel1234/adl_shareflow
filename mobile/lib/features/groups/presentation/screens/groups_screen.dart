import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/groups_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/deep_link_provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../features/groups/data/group_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/group_card.dart';
import 'create_group_screen.dart';
import 'qr_scanner_screen.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  @override
  void initState() {
    super.initState();
    // Show join sheet when a deep link arrives (app already open)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual<String?>(pendingInviteCodeProvider, (_, code) {
        if (code != null && mounted) {
          _handleDeepLinkCode(code);
        }
      }, fireImmediately: true);
    });
  }

  void _handleDeepLinkCode(String code) {
    ref.read(pendingInviteCodeProvider.notifier).state = null;
    _showJoinSheetWithCode(context, ref, code);
  }

  Future<void> _scanQr(BuildContext context, WidgetRef ref) async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (code != null && context.mounted) {
      _showJoinSheetWithCode(context, ref, code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);
    final auth = ref.watch(authProvider);
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.background,
            expandedHeight: 110,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.helloUser(auth.displayName.split(' ').first),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    l.myGroups,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_scanner,
                    color: AppColors.primary, size: 26),
                tooltip: l.scanQrCode,
                onPressed: () => _scanQr(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.group_add_outlined,
                    color: AppColors.primary, size: 26),
                tooltip: l.joinGroup,
                onPressed: () => _showJoinSheet(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.primary, size: 28),
                tooltip: l.createGroup,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateGroupScreen(),
                  ),
                ).then((_) => ref.invalidate(groupsProvider)),
              ),
              const SizedBox(width: 4),
            ],
          ),
          groupsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: _ErrorState(
                message: l.errorLoadingGroups,
                onRetry: () => ref.invalidate(groupsProvider),
              ),
            ),
            data: (groups) {
              if (groups.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(
                    onCreateGroup: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CreateGroupScreen()),
                    ).then((_) => ref.invalidate(groupsProvider)),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final group = groups[i];
                    return GroupCard(
                      group: group,
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/group-detail',
                        arguments: {'groupId': group.id},
                      ).then((_) => ref.invalidate(groupsProvider)),
                    );
                  },
                  childCount: groups.length,
                ),
              );
            },
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }
}

void _showJoinSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _JoinGroupSheet(onJoined: () => ref.invalidate(groupsProvider)),
  );
}

void _showJoinSheetWithCode(BuildContext context, WidgetRef ref, String code) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _JoinGroupSheet(
      onJoined: () => ref.invalidate(groupsProvider),
      initialCode: code,
    ),
  );
}

class _JoinGroupSheet extends StatefulWidget {
  final VoidCallback onJoined;
  final String? initialCode;
  const _JoinGroupSheet({required this.onJoined, this.initialCode});

  @override
  State<_JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends State<_JoinGroupSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  final _repo = GroupRepository();

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _ctrl.text = widget.initialCode!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _join());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() { _loading = true; _error = null; });

    try {
      // Step 1 — check invite & get expense count
      final info = await _repo.checkInvite(code);

      if (info['already_member'] == true) {
        setState(() { _error = AppLocalizations.of(context)!.alreadyMember; _loading = false; });
        return;
      }

      final expenseCount = info['expense_count'] as int? ?? 0;
      final groupName = (info['group'] as Map?)?.containsKey('name') == true
          ? info['group']['name'] as String
          : 'הקבוצה';

      // Step 2 — join (split mode is set by the inviter on the group)
      await _repo.joinGroup(code);
      widget.onJoined();
      if (mounted) Navigator.pop(context);

    } catch (e) {
      setState(() {
        _error = AppLocalizations.of(context)!.invalidCode;
        _loading = false;
      });
    }
  }

  Future<String?> _showSplitModeDialog(
    BuildContext context, {
    required String groupName,
    required int expenseCount,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx)!;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            l.splitExpenses,
            style: const TextStyle(fontWeight: FontWeight.w700),
            textAlign: TextAlign.right,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.groupExpensesCount(groupName, expenseCount),
                style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 12),
              Text(
                l.howToJoin,
                style: const TextStyle(fontWeight: FontWeight.w600),
                textAlign: TextAlign.right,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            _SplitOptionButton(
              icon: Icons.history,
              color: AppColors.primary,
              title: l.splitAll,
              subtitle: '${l.members}: $expenseCount',
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.joinGroup,
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
          Text(
            AppLocalizations.of(context)!.enterInviteCode,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _ctrl,
            textCapitalization: TextCapitalization.characters,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              hintText: 'ABC123',
              hintStyle: TextStyle(color: AppColors.border, letterSpacing: 4),
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => _join(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _join,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(AppLocalizations.of(context)!.join,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
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

class _EmptyState extends ConsumerWidget {
  final VoidCallback onCreateGroup;
  const _EmptyState({required this.onCreateGroup});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.group_add, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.noGroups,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.noGroupsDescription,
              style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onCreateGroup,
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context)!.createGroup),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showJoinSheet(context, ref),
              icon: const Icon(Icons.group_add_outlined),
              label: Text(AppLocalizations.of(context)!.joinWithCode),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: Text(AppLocalizations.of(context)!.tryAgain)),
        ],
      ),
    );
  }
}
