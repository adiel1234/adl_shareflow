import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../providers/groups_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/balances_provider.dart';
import '../../../../providers/expenses_provider.dart';
import '../../../groups/domain/group_model.dart';
import '../../../balances/domain/balance_model.dart';
import '../../../../theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/invite_sheet.dart';

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
        var headerSlots = 0;
        if (isAdmin) headerSlots++;
        if (isAdmin && guestMembers.isNotEmpty) headerSlots++;

        final legendSlots = members.isNotEmpty ? 1 : 0;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(groupMembersProvider(group.id));
            ref.invalidate(balancesProvider(group.id));
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: members.length + headerSlots + legendSlots,
            itemBuilder: (context, i) {
              var slot = 0;
              if (isAdmin) {
                if (i == slot) {
                  return _MembersInviteActions(group: group);
                }
                slot++;
              }
              if (isAdmin && guestMembers.isNotEmpty) {
                if (i == slot) {
                  return _GuestReminderCard(
                    count: guestMembers.length,
                    onTap: () => _showAddGuestSheet(context, ref, group),
                  );
                }
                slot++;
              }
              if (legendSlots == 1) {
                if (i == slot) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      AppLocalizations.of(context)!.tipMemberBalanceLegend,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }
                slot++;
              }
              final m = members[i - slot];
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
                      if (context.mounted) {
                        await showInviteSheet(
                          context,
                          groupId: group.id,
                          groupName: group.name,
                          isAdmin: group.isAdmin,
                        );
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
    final amountLabel = '${net.abs().round()} $currency';

    // net > 0: others owe this member — blocked (section 13 mode B)
    if (net > 0.001) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.removeMemberTitle(member.displayLabel)),
          content: Text(l.removeMemberBlockedCreditor(member.displayLabel)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('סגור'),
            ),
          ],
        ),
      );
      return;
    }

    bool confirmed = false;

    if (net < -0.001) {
      // Member owes others — redistribute on removal (section 13 mode A)
      confirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) {
              final dl = AppLocalizations.of(ctx)!;
              return AlertDialog(
                title: Text(dl.removeMemberRedistributeTitle),
                content: Text(dl.removeMemberRedistributeBody(
                    member.displayLabel, amountLabel)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(dl.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(dl.remove,
                        style: const TextStyle(
                            color: AppColors.negative,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              );
            },
          ) ??
          false;
    } else {
      confirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) {
              final dl = AppLocalizations.of(ctx)!;
              return AlertDialog(
                title: Text(dl.removeMemberTitle(member.displayLabel)),
                content: Text(dl.removeMemberConfirm),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(dl.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(dl.remove,
                        style: const TextStyle(
                            color: AppColors.negative,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              );
            },
          ) ??
          false;
    }

    if (!confirmed) return;

    try {
      await ref.read(groupRepositoryProvider).removeMember(
            group.id,
            member.userId,
          );
      ref.invalidate(groupMembersProvider(group.id));
      ref.invalidate(balancesProvider(group.id));
      ref.invalidate(expensesProvider(group.id));
      if (context.mounted) {
        final msg = net < -0.001
            ? l.memberRemovedRedistributed(member.displayLabel)
            : l.memberRemovedSuccess(member.displayLabel);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
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

Future<String?> _showGuestSplitModeDialog(
  BuildContext context, {
  required String groupName,
  required int expenseCount,
}) {
  final l = AppLocalizations.of(context)!;
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
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
            l.howShouldNewMemberJoin,
            style: const TextStyle(fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        _GuestSplitOptionButton(
          icon: Icons.history,
          color: AppColors.primary,
          title: l.splitAll,
          subtitle: l.includePastExpenses,
          onTap: () => Navigator.pop(ctx, 'full'),
        ),
        const SizedBox(height: 8),
        _GuestSplitOptionButton(
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
}

Future<void> _showAddGuestSheet(
  BuildContext context,
  WidgetRef ref,
  Group group,
) async {
  final l = AppLocalizations.of(context)!;

  var splitMode = 'forward';
  int expenseCount = group.expenseCount;
  try {
    expenseCount = await ref
        .read(groupRepositoryProvider)
        .fetchExpenseCount(group.id);
  } catch (_) {}

  if (expenseCount > 0) {
    final chosen = await _showGuestSplitModeDialog(
      context,
      groupName: group.name,
      expenseCount: expenseCount,
    );
    if (chosen == null) return;
    splitMode = chosen;
  }

  final nameCtrl = TextEditingController();
  final nameFocus = FocusNode();
  final scrollCtrl = ScrollController();
  var loading = false;
  final addedGuests = <String>[];

  // Scroll to bottom when keyboard appears so the field stays visible
  nameFocus.addListener(() {
    if (nameFocus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (scrollCtrl.hasClients) {
          scrollCtrl.animateTo(
            scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  });

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.addGuestTitle,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(l.guestNoApp,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
            // Added guests list
            if (addedGuests.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...addedGuests.map((name) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(name,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              focusNode: nameFocus,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: l.addGuestHint,
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;

                      setSheetState(() => loading = true);
                      try {
                        await ref.read(groupRepositoryProvider).addGuest(
                          group.id,
                          name,
                          splitMode: splitMode,
                        );
                        ref.invalidate(groupMembersProvider(group.id));
                        ref.invalidate(balancesProvider(group.id));
                        ref.invalidate(expensesProvider(group.id));
                        ref.invalidate(groupDetailProvider(group.id));
                        ref.invalidate(groupsProvider);
                        if (ctx.mounted) {
                          setSheetState(() {
                            addedGuests.add(name);
                            nameCtrl.clear();
                          });
                          // Keep focus on the field for quick multi-add
                          nameFocus.requestFocus();
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          final msg = e is DioException
                              ? (e.response?.data?['message'] as String?) ??
                                  l.errorAddingGuest
                              : l.errorAddingGuest;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(msg)),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setSheetState(() => loading = false);
                      }
                    },
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.addGuestTitle),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.notifClose),
            ),
          ],
        ),
      ),
    ),
  );
  nameCtrl.dispose();
  nameFocus.dispose();
  scrollCtrl.dispose();
}

class _GuestSplitOptionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _GuestSplitOptionButton({
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
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
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
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Invite + guest actions (admin) ────────────────────────────────────────────

class _MembersInviteActions extends ConsumerWidget {
  final Group group;
  const _MembersInviteActions({required this.group});

  void _invalidate(WidgetRef ref) {
    ref.invalidate(groupMembersProvider(group.id));
    ref.invalidate(balancesProvider(group.id));
    ref.invalidate(expensesProvider(group.id));
    ref.invalidate(groupDetailProvider(group.id));
    ref.invalidate(groupsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () => openInviteFlow(
              context,
              groupId: group.id,
              groupName: group.name,
              isAdmin: group.isAdmin,
              expenseCountHint: group.expenseCount,
              onGuestAdded: () => _invalidate(ref),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
            label: Text(
              l.inviteViaApp,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showAddGuestSheet(context, ref, group),
            icon: const Icon(Icons.person_outline, size: 18),
            label: Text(l.addGuestOption),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.tipMembersActions,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Guest reminder banner ─────────────────────────────────────────────────────

class _GuestReminderCard extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;
  const _GuestReminderCard({required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
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
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Text(l.guestReminderAction,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple.shade700)),
            const Icon(Icons.chevron_left, size: 18, color: Colors.purple),
          ],
        ],
      ),
        ),
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
