import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../providers/groups_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/balances_provider.dart';
import '../../../groups/domain/group_model.dart';
import '../../../balances/domain/balance_model.dart';
import '../../../../theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/share_service.dart';

class MembersTabScreen extends ConsumerWidget {
  final Group group;
  const MembersTabScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(groupMembersProvider(group.id));
    final balancesAsync = ref.watch(balancesProvider(group.id));
    final auth = ref.watch(authProvider);
    final isAdmin = group.isAdmin;

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(AppLocalizations.of(context)!.errorLoadingMembers)),
      data: (members) {
        // Build a map of userId → net balance for display
        final balanceMap = <String, String>{};
        final currencyLabel = balancesAsync.valueOrNull?['currency'] as String? ?? group.baseCurrency;
        if (balancesAsync.valueOrNull != null) {
          final balances = (balancesAsync.valueOrNull!['balances'] as List?)
                  ?.cast<UserBalance>() ??
              [];
          for (final b in balances) {
            final net = b.netDouble;
            balanceMap[b.userId] =
                '${net >= 0 ? '+' : ''}${net.round()} $currencyLabel';
          }
        }

        final guestMembers = members.where((m) => m.isGuest).toList();

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(groupMembersProvider(group.id));
            ref.invalidate(balancesProvider(group.id));
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            // +1 header slot when admin has guests
            itemCount: members.length + (isAdmin && guestMembers.isNotEmpty ? 1 : 0),
            itemBuilder: (context, i) {
              // First item: guest reminder banner for admin
              if (isAdmin && guestMembers.isNotEmpty && i == 0) {
                return _GuestReminderCard(
                  count: guestMembers.length,
                );
              }
              // Offset real index when banner is showing
              final memberIndex = (isAdmin && guestMembers.isNotEmpty) ? i - 1 : i;
              final m = members[memberIndex];
              final isSelf = m.userId == auth.userId;
              final balanceText = balanceMap[m.userId];
              // Parse net from the formatted string (or default 0)
              final netRaw = balanceText
                      ?.replaceAll(RegExp(r'[^\d\.\-]'), '')
                      .replaceFirst(RegExp(r'^\+'), '') ??
                  '0';
              final net = double.tryParse(netRaw) ?? 0;
              final netSigned = balanceText?.startsWith('+') == true ? net : (balanceText != null ? -net.abs() : 0.0);
              final balanceColor = netSigned > 0
                  ? AppColors.positive
                  : netSigned < 0
                      ? AppColors.negative
                      : AppColors.neutral;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: m.isGuest
                          ? Colors.purple.withOpacity(0.12)
                          : isSelf
                              ? AppColors.primary.withOpacity(0.12)
                              : AppColors.surfaceVariant,
                      child: m.isGuest
                          ? const Icon(Icons.person_outline,
                              size: 20, color: Colors.purple)
                          : Text(
                              (m.displayLabel.isNotEmpty
                                      ? m.displayLabel[0]
                                      : '?')
                                  .toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: isSelf
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),

                    // Name + role
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                m.displayLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              if (isSelf) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(AppLocalizations.of(context)!.youLabel,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                              if (m.isAdmin) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(AppLocalizations.of(context)!.adminLabel,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                              if (m.isGuest) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(AppLocalizations.of(context)!.guestBadge,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.purple,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ],
                          ),
                          if (balanceText != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              balanceText,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: balanceColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Guest actions (admin only)
                    if (isAdmin && m.isGuest)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.link, color: Colors.purple, size: 20),
                            tooltip: AppLocalizations.of(context)!.linkGuestTitle,
                            onPressed: () => _showLinkGuestSheet(context, ref, m, members),
                          ),
                          IconButton(
                            icon: const Icon(Icons.person_remove_outlined,
                                color: AppColors.negative, size: 20),
                            tooltip: AppLocalizations.of(context)!.removeGuest,
                            onPressed: () => _confirmRemoveGuest(context, ref, m),
                          ),
                        ],
                      )
                    // Remove button (admin only, not self, not guest)
                    else if (isAdmin && !isSelf && !m.isGuest)
                      IconButton(
                        icon: const Icon(Icons.person_remove_outlined,
                            color: AppColors.negative, size: 20),
                        tooltip: AppLocalizations.of(context)!.removeMember,
                        onPressed: () =>
                            _confirmRemove(context, ref, m, netSigned, currencyLabel),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showLinkGuestSheet(
    BuildContext context,
    WidgetRef ref,
    GroupMember guest,
    List<GroupMember> allMembers,
  ) async {
    final l = AppLocalizations.of(context)!;
    // Capture messenger before the sheet opens so it stays usable after close
    final messenger = ScaffoldMessenger.of(context);
    // Real (non-guest) members only
    final realMembers = allMembers.where((m) => !m.isGuest && m.userId != guest.userId).toList();
    if (realMembers.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('אין חברים רשומים לשיוך')),
      );
      return;
    }

    String? selectedUserId = realMembers.first.userId;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.link, color: Colors.purple, size: 20),
                  const SizedBox(width: 8),
                  Text(l.linkGuestTitle,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                Text(l.linkGuestSubtitle(guest.displayLabel),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.purple.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: Colors.purple),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.linkGuestExplain,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.purple,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: selectedUserId,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  items: realMembers
                      .map((m) => DropdownMenuItem(
                            value: m.userId,
                            child: Text(m.displayLabel),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => selectedUserId = v),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l.linkGuestBtn),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('או',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: Text(l.inviteFriends),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: const BorderSide(color: Colors.purple),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx, false);
                      try {
                        final api = ApiClient.instance;
                        final resp = await api.get(
                            '/groups/${group.id}/invite-link');
                        final data = resp.data['data'] as Map<String, dynamic>;
                        final code = data['invite_code'] as String;
                        final link = data['invite_link'] as String;
                        await ShareService.shareGroupInvite(
                          groupName: group.name,
                          inviteCode: code,
                          inviteUrl: link,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          String msg = 'שגיאה בקבלת קישור ההזמנה';
                          if (e is DioException) {
                            msg = (e.response?.data?['message'] as String?) ?? msg;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg)),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l.cancel,
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );

    if (confirmed != true || selectedUserId == null) return;

    try {
      final api = ApiClient.instance;
      await api.put(
        '/groups/${group.id}/guests/${guest.userId}/link',
        data: {'real_user_id': selectedUserId},
      );
      ref.invalidate(groupMembersProvider(group.id));
      ref.invalidate(balancesProvider(group.id));
      messenger.showSnackBar(
        SnackBar(content: Text(l.linkGuestSuccess)),
      );
    } catch (e) {
      String msg = 'שגיאה בשיוך האורח';
      if (e is DioException) {
        msg = (e.response?.data?['message'] as String?) ?? msg;
      }
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _confirmRemoveGuest(
    BuildContext context,
    WidgetRef ref,
    GroupMember guest,
  ) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dl = AppLocalizations.of(ctx)!;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.person_remove_outlined, color: AppColors.negative, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(dl.removeGuest,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${dl.removeMemberTitle(guest.displayLabel)}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  dl.removeGuestConfirm(guest.displayLabel),
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.5),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(dl.cancel)),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(dl.remove,
                  style: const TextStyle(
                      color: AppColors.negative, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      final api = ApiClient.instance;
      await api.delete('/groups/${group.id}/guests/${guest.userId}');
      ref.invalidate(groupMembersProvider(group.id));
      ref.invalidate(balancesProvider(group.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.guestRemovedSuccess(guest.displayLabel))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        String msg = 'שגיאה בהסרת האורח';
        if (e is DioException) {
          msg = (e.response?.data?['message'] as String?) ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
    double net,
    String currency,
  ) async {
    final l = AppLocalizations.of(context)!;
    final hasDebt = net.abs() > 0.001;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final dl = AppLocalizations.of(ctx)!;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.person_remove_outlined,
                color: AppColors.negative, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(dl.removeMemberTitle(member.displayLabel),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasDebt) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFD700)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: Color(0xFF856404)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          dl.memberHasBalance(member.displayLabel,
                              '${net.abs().round()} $currency'),
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF856404),
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  dl.removeMemberExplain,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.5),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(dl.cancel)),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(dl.remove,
                  style: const TextStyle(
                      color: AppColors.negative, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(groupRepositoryProvider)
          .removeMember(group.id, member.userId);
      ref.invalidate(groupMembersProvider(group.id));
      ref.invalidate(balancesProvider(group.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.memberRemovedSuccess(member.displayLabel))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        String msg = l.errorRemovingMember;
        if (e is DioException) {
          msg = (e.response?.data?['message'] as String?) ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 5),
            backgroundColor: AppColors.negative,
          ),
        );
      }
    }
  }
}

// ── Guest reminder banner ─────────────────────────────────────────────────────

class _GuestReminderCard extends StatelessWidget {
  final int count;
  const _GuestReminderCard({required this.count});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.person_outline, color: Colors.purple, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.guestReminderTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.guestReminderBody(count),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _OptionBtn(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                          fontSize: 13)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
