import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/groups_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../features/groups/data/group_repository.dart';
import '../widgets/group_card.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final auth = ref.watch(authProvider);

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
                    'שלום, ${auth.displayName.split(' ').first} 👋',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const Text(
                    'הקבוצות שלי',
                    style: TextStyle(
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
                icon: const Icon(Icons.group_add_outlined,
                    color: AppColors.primary, size: 26),
                tooltip: 'הצטרף לקבוצה',
                onPressed: () => _showJoinSheet(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.primary, size: 28),
                tooltip: 'קבוצה חדשה',
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
                message: 'שגיאה בטעינת הקבוצות',
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
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupDetailScreen(group: group),
                        ),
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

class _JoinGroupSheet extends StatefulWidget {
  final VoidCallback onJoined;
  const _JoinGroupSheet({required this.onJoined});

  @override
  State<_JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends State<_JoinGroupSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  final _repo = GroupRepository();

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
        setState(() { _error = 'כבר חבר בקבוצה זו'; _loading = false; });
        return;
      }

      final expenseCount = info['expense_count'] as int? ?? 0;
      final groupName = (info['group'] as Map?)?.containsKey('name') == true
          ? info['group']['name'] as String
          : 'הקבוצה';

      // Step 2 — if group has expenses, ask about split mode
      String splitMode = 'forward';
      if (expenseCount > 0 && mounted) {
        final choice = await _showSplitModeDialog(
          context,
          groupName: groupName,
          expenseCount: expenseCount,
        );
        if (choice == null) {
          // User cancelled
          setState(() => _loading = false);
          return;
        }
        splitMode = choice;
      }

      // Step 3 — join with chosen split mode
      await _repo.joinGroup(code, splitMode: splitMode);
      widget.onJoined();
      if (mounted) Navigator.pop(context);

    } catch (e) {
      setState(() {
        _error = 'קוד לא תקין — בדוק ונסה שוב';
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'חלוקת הוצאות',
          style: TextStyle(fontWeight: FontWeight.w700),
          textAlign: TextAlign.right,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'בקבוצה "$groupName" יש כבר $expenseCount הוצאות.',
              style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),
            const Text(
              'כיצד תרצה להצטרף?',
              style: TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          // Full retroactive
          _SplitOptionButton(
            icon: Icons.history,
            color: AppColors.primary,
            title: 'חלק את כל ההוצאות',
            subtitle: 'כולל $expenseCount הוצאות מהעבר',
            onTap: () => Navigator.pop(ctx, 'full'),
          ),
          const SizedBox(height: 8),
          // Forward only
          _SplitOptionButton(
            icon: Icons.arrow_forward,
            color: AppColors.secondary,
            title: 'רק מעכשיו והלאה',
            subtitle: 'לא מחויב בהוצאות עד כה',
            onTap: () => Navigator.pop(ctx, 'forward'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('ביטול',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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
          const SizedBox(height: 20),
          const Text(
            'הצטרף לקבוצה',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'הכנס את קוד ההזמנה שקיבלת',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                  : const Text('הצטרף',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
            const Text(
              'אין קבוצות עדיין',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'צור קבוצה חדשה עם חברים,\nשותפים לדירה, או בני משפחה',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onCreateGroup,
              icon: const Icon(Icons.add),
              label: const Text('קבוצה חדשה'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showJoinSheet(context, ref),
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('הצטרף עם קוד הזמנה'),
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
          TextButton(onPressed: onRetry, child: const Text('נסה שוב')),
        ],
      ),
    );
  }
}
