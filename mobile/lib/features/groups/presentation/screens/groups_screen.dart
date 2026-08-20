import 'package:dio/dio.dart';
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
  final GlobalKey? coachScanKey;
  final GlobalKey? coachJoinKey;
  final GlobalKey? coachCreateKey;

  const GroupsScreen({
    super.key,
    this.coachScanKey,
    this.coachJoinKey,
    this.coachCreateKey,
  });

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
                key: widget.coachScanKey,
                icon: const Icon(Icons.qr_code_scanner,
                    color: AppColors.primary, size: 26),
                tooltip: l.scanQrCode,
                onPressed: () => _scanQr(context, ref),
              ),
              IconButton(
                key: widget.coachJoinKey,
                icon: const Icon(Icons.group_add_outlined,
                    color: AppColors.primary, size: 26),
                tooltip: l.joinGroup,
                onPressed: () => _showJoinSheet(context, ref),
              ),
              IconButton(
                key: widget.coachCreateKey,
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
                    onJoin: () => _showJoinSheet(context, ref),
                    onScanQr: () => _scanQr(context, ref),
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

  /// Sentinel: user dismissed the guest-match dialog — abort join.
  static const _kJoinCancelled = '__cancelled__';

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
      // Step 1 — בדיקת קוד ההזמנה + אורחים דומים לשם המצטרף
      final info = await _repo.checkInvite(code);

      if (info['already_member'] == true) {
        setState(() { _error = AppLocalizations.of(context)!.alreadyMember; _loading = false; });
        return;
      }

      final groupData = info['group'] as Map<String, dynamic>?;
      final splitMode = (groupData?['invite_split_mode'] as String?) ?? 'forward';
      final joinerName = (info['joiner_display_name'] as String?) ?? '';
      final similarRaw = info['similar_guests'] as List<dynamic>? ?? const [];
      final similarGuests = similarRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // Step 1b — אם יש אורח עם שם דומה: האם זה אותו אדם או משתמש חדש?
      String? linkGuestId;
      if (similarGuests.isNotEmpty && mounted) {
        linkGuestId = await _askIfJoinerIsGuest(
          similarGuests: similarGuests,
          joinerName: joinerName,
        );
        if (!mounted) return;
        // null from dialog dismiss → cancel join
        if (linkGuestId == _kJoinCancelled) {
          setState(() => _loading = false);
          return;
        }
      }

      // Step 2 — הצטרפות (+ קישור אורח אם נבחר)
      await _repo.joinGroup(
        code,
        splitMode: splitMode,
        linkGuestUserId: linkGuestId,
      );
      widget.onJoined();
      if (mounted) Navigator.pop(context);

    } catch (e) {
      String msg = AppLocalizations.of(context)!.invalidCode;
      if (e is DioException) {
        final server = e.response?.data?['message'] as String?;
        if (server != null && server.trim().isNotEmpty) msg = server;
      } else {
        final raw = e.toString();
        if (raw.isNotEmpty && !raw.startsWith('Exception:')) {
          msg = raw;
        }
      }
      setState(() {
        _error = msg;
        _loading = false;
      });
    }
  }

  /// Returns guest user_id to link, null for "new member", or [_kJoinCancelled].
  Future<String?> _askIfJoinerIsGuest({
    required List<Map<String, dynamic>> similarGuests,
    required String joinerName,
  }) async {
    final l = AppLocalizations.of(context)!;
    Map<String, dynamic> guest = similarGuests.first;

    if (similarGuests.length > 1) {
      final picked = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  l.joinGuestPickTitle,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              ...similarGuests.map((g) {
                final name = (g['display_name'] as String?) ?? '';
                return ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(name),
                  onTap: () => Navigator.pop(ctx, g),
                );
              }),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1),
                title: Text(l.joinGuestMatchNo),
                onTap: () => Navigator.pop(ctx, <String, dynamic>{}),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (picked == null) return _kJoinCancelled;
      if (picked.isEmpty) return null; // new member
      guest = picked;
    }

    final guestName = (guest['display_name'] as String?) ?? '';
    final guestId = guest['user_id'] as String?;
    if (guestId == null || guestId.isEmpty) return null;
    if (!mounted) return _kJoinCancelled;

    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l.joinGuestMatchTitle),
        content: Text(l.joinGuestMatchBody(guestName, joinerName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'new'),
            child: Text(l.joinGuestMatchNo),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'link'),
            child: Text(l.joinGuestMatchYes),
          ),
        ],
      ),
    );

    if (choice == null) return _kJoinCancelled;
    if (choice == 'link') return guestId;
    return null;
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

class _EmptyState extends ConsumerWidget {
  final VoidCallback onCreateGroup;
  final VoidCallback onJoin;
  final VoidCallback onScanQr;
  const _EmptyState({
    required this.onCreateGroup,
    required this.onJoin,
    required this.onScanQr,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
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
              l.noGroups,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.noGroupsDescription,
              style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l.emptyGroupsChecklistTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _ChecklistLine(text: l.emptyGroupsStep1),
            _ChecklistLine(text: l.emptyGroupsStep2),
            _ChecklistLine(text: l.emptyGroupsStep3),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: onCreateGroup,
              icon: const Icon(Icons.add),
              label: Text(l.createGroup),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onJoin,
              icon: const Icon(Icons.group_add_outlined),
              label: Text(l.joinWithCode),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onScanQr,
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: Text(l.scanQrCta),
            ),
            const SizedBox(height: 6),
            Text(
              l.tipJoinWithCode,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistLine extends StatelessWidget {
  final String text;
  const _ChecklistLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
