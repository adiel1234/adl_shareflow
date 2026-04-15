import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/groups_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/balances_provider.dart';
import '../../../groups/domain/group_model.dart';
import '../../../balances/domain/balance_model.dart';
import '../../../../theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

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

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(groupMembersProvider(group.id));
            ref.invalidate(balancesProvider(group.id));
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: members.length,
            itemBuilder: (context, i) {
              final m = members[i];
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
                      backgroundColor: isSelf
                          ? AppColors.primary.withOpacity(0.12)
                          : AppColors.surfaceVariant,
                      child: Text(
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

                    // Remove button (admin only, not self)
                    if (isAdmin && !isSelf)
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

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
    double net,
    String currency,
  ) async {
    final l = AppLocalizations.of(context)!;
    final hasDebt = net.abs() > 0.001;
    String? mode;

    if (hasDebt) {
      mode = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final dl = AppLocalizations.of(ctx)!;
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(dl.removeMemberTitle(member.displayLabel),
                style: const TextStyle(fontWeight: FontWeight.w700),
                textAlign: TextAlign.right),
            content: Text(
              dl.memberHasBalance(
                  member.displayLabel, '${net.abs().round()} $currency'),
              style: const TextStyle(
                  color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.right,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              _OptionBtn(
                icon: Icons.handshake_outlined,
                color: AppColors.positive,
                title: dl.settleDebt,
                subtitle: dl.settleDebtDesc,
                onTap: () => Navigator.pop(ctx, 'settle'),
              ),
              const SizedBox(height: 8),
              _OptionBtn(
                icon: Icons.people_outline,
                color: AppColors.primary,
                title: dl.redistributeDebt,
                subtitle: dl.redistributeDebtDesc,
                onTap: () => Navigator.pop(ctx, 'redistribute'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(dl.cancel,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          );
        },
      );
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final dl = AppLocalizations.of(ctx)!;
          return AlertDialog(
            title: Text(dl.removeMemberTitle(member.displayLabel)),
            content: Text(dl.removeMemberConfirm),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(dl.cancel)),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(dl.remove,
                    style: const TextStyle(color: AppColors.negative)),
              ),
            ],
          );
        },
      );
      if (ok == true) mode = 'settle';
    }

    if (mode == null) return;

    try {
      await ref
          .read(groupRepositoryProvider)
          .removeMember(group.id, member.userId, mode: mode);
      ref.invalidate(groupMembersProvider(group.id));
      ref.invalidate(balancesProvider(group.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.memberRemovedSuccess(member.displayLabel))),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.errorRemovingMember)),
        );
      }
    }
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
