import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/balances_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/groups_provider.dart';
import '../../../groups/domain/group_model.dart';
import '../../../groups/data/group_repository.dart';
import '../../domain/balance_model.dart';
import '../../data/balance_repository.dart';
import '../../../../theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

class EventSummaryScreen extends ConsumerStatefulWidget {
  final Group group;
  const EventSummaryScreen({super.key, required this.group});

  @override
  ConsumerState<EventSummaryScreen> createState() => _EventSummaryScreenState();
}

class _EventSummaryScreenState extends ConsumerState<EventSummaryScreen> {
  bool _loading = true;
  bool _sending = false;
  bool _closing = false;
  int _wizardStep = 0;
  Map<String, dynamic>? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static const _summaryTimeout = Duration(seconds: 20);

  String _formatLoadError(DioException e) {
    final l = AppLocalizations.of(context)!;
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final serverMsg = data is Map ? data['message'] as String? : null;
    final parts = <String>[l.errorLoadingSummary];
    if (status != null) parts.add('($status)');
    if (serverMsg != null && serverMsg.isNotEmpty) parts.add(serverMsg);
    return parts.join(' ');
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await BalanceRepository()
          .fetchEventSummaryPreview(widget.group.id)
          .timeout(_summaryTimeout);
      if (!mounted) return;
      setState(() {
        _summary = (data['summary'] as Map<String, dynamic>?) ?? data;
      });
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = _formatLoadError(e);
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _error = '${AppLocalizations.of(context)!.errorLoadingSummary} (timeout)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '${AppLocalizations.of(context)!.errorLoadingSummary} ($e)';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendAppNotifications() async {
    setState(() => _sending = true);
    try {
      await BalanceRepository()
          .sendEventSummaryNotifications(widget.group.id)
          .timeout(_summaryTimeout);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.notificationSentToAll)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorSendingNotification)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatAmount(dynamic val) {
    final d = double.tryParse(val?.toString() ?? '0') ?? 0;
    return d.round().toString();
  }

  Future<void> _closeGroup() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.closeGroupAfterSummary),
        content: Text(l.closeGroupConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.closeGroupAfterSummary)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _closing = true);
    final repo = ref.read(groupRepositoryProvider);
    try {
      await repo.closeGroup(widget.group.id);
      if (mounted) {
        ref.invalidate(groupsProvider);
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.groupClosedSuccess)),
        );
      }
    } on DioException catch (e) {
      final body = e.response?.data as Map<String, dynamic>?;
      final unsettled = (body?['errors']?['unsettled'] as List?)?.isNotEmpty == true;
      if (unsettled && mounted) {
        final force = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.unsettledDebts),
            content: Text(l.unsettledDebtsWarning),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l.cancel)),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l.closeGroupAfterSummary)),
            ],
          ),
        );
        if (force == true && mounted) {
          await repo.closeGroup(widget.group.id, force: true);
          if (mounted) {
            ref.invalidate(groupsProvider);
            Navigator.pop(context);
            Navigator.pop(context);
          }
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.errorClosingGroup)),
        );
      }
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Widget _wizardBar(AppLocalizations l) {
    final steps = [l.wizardStepSummary, l.wizardStepSend, l.wizardStepClose];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: List.generate(steps.length, (i) {
          final active = i == _wizardStep;
          final done = i < _wizardStep;
          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: done || active
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                Column(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: active || done
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active || done
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w400,
                        color: active
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomBar(AppLocalizations l) {
    const totalSteps = 3;
    final displayStep = _loading ? 0 : _wizardStep;

    return SafeArea(
      top: false,
      child: Material(
        color: AppColors.surface,
        elevation: 4,
        shadowColor: Colors.black26,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.wizardStepOf(displayStep + 1, totalSteps),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    onPressed: () => setState(() {
                      _error = null;
                      _loading = true;
                      _load();
                    }),
                    child: Text(l.tryAgain),
                  ),
                )
              else
                Row(
                  children: [
                    if (displayStep > 0) ...[
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                          ),
                          onPressed: _loading
                              ? null
                              : () => setState(() => _wizardStep--),
                          child: Text(l.wizardBack),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: displayStep < 2
                          ? ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                              ),
                              onPressed: _loading
                                  ? null
                                  : () => setState(() => _wizardStep++),
                              child: Text(l.wizardNext),
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                              ),
                              onPressed:
                                  _closing || _loading ? null : _closeGroup,
                              child: _closing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(l.closeGroupAfterSummary),
                            ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(l.finishEventWizard,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    _wizardBar(l),
                    Expanded(child: _buildContent()),
                  ],
                ),
      bottomNavigationBar: _buildBottomBar(l),
    );
  }

  Widget _buildContent() {
    final l = AppLocalizations.of(context)!;
    final s = _summary!;
    final transfers = (s['transfers'] as List? ?? []);
    final booksBalanced = s['books_balanced'] as bool? ?? true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_wizardStep >= 0) ...[
          // Header stats card
          if (_wizardStep == 0)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text('💳', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 8),
                Text(
                  widget.group.name,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                _TotalAmountsDisplay(summary: s),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatChip(
                      icon: '👥',
                      label: l.participants,
                      value: '${s['member_count']}',
                    ),
                    _StatChip(
                      icon: '📊',
                      label: l.costPerParticipant,
                      value: s['avg_per_member'] as String? ?? '0',
                    ),
                    if (s['top_payer'] != null)
                      _StatChip(
                        icon: '🏆',
                        label: 'שילם הכי הרבה',
                        value: (s['top_payer'] as Map)['display_name'] as String? ?? '',
                      ),
                  ],
                ),
                if (s['top_payer'] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '🏆 ${(s['top_payer'] as Map)['display_name']} שילם/ה '
                      '${(s['top_payer'] as Map)['total_paid']}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),
          ],

          if (_wizardStep == 0) ...[
          // Transfers section
          Text(
            l.requiredTransfers,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),

          if (transfers.isEmpty && booksBalanced)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.positive.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.positive.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('✅', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Text(l.allSettled,
                      style: TextStyle(
                          color: AppColors.positive,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            )
          else if (transfers.isEmpty && !booksBalanced)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.negative.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.negative.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.booksImbalancedWarning,
                      style: const TextStyle(
                        color: AppColors.negative,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...transfers.map((t) => _TransferCard(
                  fromName: t['from_name'] as String,
                  toName: t['to_name'] as String,
                  amount: _formatAmount(t['amount']),
                  currency: t['currency'] as String,
                  onRemind: () => _sendReminder(t),
                )),

          const SizedBox(height: 32),
          ],

          if (_wizardStep == 1) ...[
          Text(
            l.sendSummary,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.notifications_outlined,
            label: l.sendPushToAll,
            subtitle: l.sendPushSubtitle,
            color: AppColors.primary,
            loading: _sending,
            onTap: _sendAppNotifications,
          ),
          ],

          if (_wizardStep == 2) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.lock_outline,
                      size: 40, color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text(
                    l.closeGroupAfterSummary,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.closeGroupConfirm,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textSecondary, height: 1.5),
                  ),
                  if (transfers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      l.unsettledDebtsTitle,
                      style: const TextStyle(
                          color: AppColors.negative,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _sendReminder(Map t) async {
    try {
      await BalanceRepository().sendPaymentReminder(
        groupId: widget.group.id,
        toUserId: t['from_user_id'] as String,
        amount: _formatAmount(t['amount']),
        currency: t['currency'] as String,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.reminderSent(t['from_name'] as String)),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorSendingReminder)),
        );
      }
    }
  }
}

class _StatChip extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  const _StatChip(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class _TransferCard extends StatelessWidget {
  final String fromName;
  final String toName;
  final String amount;
  final String currency;
  final VoidCallback onRemind;

  const _TransferCard({
    required this.fromName,
    required this.toName,
    required this.amount,
    required this.currency,
    required this.onRemind,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Visual row: avatar → arrow → avatar
          Row(
            children: [
              _Avatar(name: fromName, color: AppColors.negative),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$amount $currency',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 30,
                          height: 2,
                          color: AppColors.primary.withOpacity(0.4),
                        ),
                        const Icon(Icons.arrow_forward,
                            size: 16, color: AppColors.primary),
                        Container(
                          width: 30,
                          height: 2,
                          color: AppColors.primary.withOpacity(0.4),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _Avatar(name: toName, color: AppColors.positive),
            ],
          ),
          const SizedBox(height: 10),
          // Text description
          Text(
            AppLocalizations.of(context)!.debtOwesAmount(
              fromName,
              toName,
              amount,
              currency,
            ),
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Remind button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRemind,
              icon: const Icon(Icons.notifications_outlined, size: 16),
              label: Text(AppLocalizations.of(context)!.sendReminderTo(fromName)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                    color: AppColors.primary.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final Color color;
  const _Avatar({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withOpacity(0.12),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 18),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 70,
          child: Text(
            name,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool loading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color),
                    )
                  : Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: color,
                            fontSize: 14)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Displays total amounts per currency — each on its own line, LTR aligned
// ---------------------------------------------------------------------------
class _TotalAmountsDisplay extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _TotalAmountsDisplay({required this.summary});

  @override
  Widget build(BuildContext context) {
    final totals = summary['totals_by_currency'] as Map<String, dynamic>?;

    // Fallback: parse total_summary string if new field not yet available
    final List<MapEntry<String, int>> entries;
    if (totals != null && totals.isNotEmpty) {
      entries = totals.entries
          .map((e) => MapEntry(e.key as String,
              (e.value as num?)?.toInt() ?? 0))
          .toList();
    } else {
      final raw = summary['total_summary'] as String? ?? '';
      entries = raw
          .split('|')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((s) {
            final parts = s.split(' ');
            final amt = int.tryParse(parts.firstWhere(
                  (p) => int.tryParse(p) != null,
                  orElse: () => '0')) ?? 0;
            final cur = parts.firstWhere(
                (p) => int.tryParse(p) == null && p.isNotEmpty,
                orElse: () => '');
            return MapEntry(cur, amt);
          })
          .where((e) => e.key.isNotEmpty)
          .toList();
    }

    if (entries.isEmpty) {
      return const Text('0',
          style: TextStyle(color: Colors.white, fontSize: 28,
              fontWeight: FontWeight.w900));
    }

    return Column(
      children: entries.map((e) {
        final symbol = _currencySymbol(e.key);
        final formatted = _formatNumber(e.value);
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '$symbol $formatted',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _currencySymbol(String code) {
    const symbols = {
      'ILS': '₪', 'USD': '\$', 'EUR': '€',
      'GBP': '£', 'JPY': '¥', 'CHF': 'Fr',
    };
    return symbols[code.toUpperCase()] ?? code;
  }

  String _formatNumber(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
