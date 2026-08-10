import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../groups/domain/group_model.dart';

class ParticipantsSelector extends StatelessWidget {
  final List<GroupMember> members;
  final Set<String> selectedIds;
  final double totalAmount;
  final String currency;
  final void Function(Set<String>) onChanged;

  const ParticipantsSelector({
    super.key,
    required this.members,
    required this.selectedIds,
    required this.totalAmount,
    required this.currency,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final count = selectedIds.length;
    final perPerson = count > 0 && totalAmount > 0
        ? (totalAmount / count).toStringAsFixed(2)
        : '0.00';
    final subtitle = l.perParticipant('$perPerson $currency');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l.participants,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l.tipParticipantsEqualSplit,
          style: const TextStyle(
            fontSize: 12,
            height: 1.35,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: members.asMap().entries.map((entry) {
              final idx = entry.key;
              final member = entry.value;
              final isSelected = selectedIds.contains(member.userId);
              final isLast = idx == members.length - 1;
              return Column(
                children: [
                  CheckboxListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    title: Text(
                      member.displayLabel,
                      style: const TextStyle(fontSize: 14),
                    ),
                    value: isSelected,
                    activeColor: AppColors.primary,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (checked) {
                      final next = Set<String>.from(selectedIds);
                      if (checked == true) {
                        next.add(member.userId);
                      } else {
                        if (next.length > 1) next.remove(member.userId);
                      }
                      onChanged(next);
                    },
                  ),
                  if (!isLast)
                    const Divider(height: 1, indent: 12, endIndent: 12),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
