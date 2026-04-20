import 'group_model.dart';

class PeriodDebt {
  final String id;
  final String reportId;
  final String fromUserId;
  final GroupMember? fromUser;
  final String toUserId;
  final GroupMember? toUser;
  final double amount;
  final String currency;
  final bool isPaid;
  final DateTime? paidAt;

  const PeriodDebt({
    required this.id,
    required this.reportId,
    required this.fromUserId,
    this.fromUser,
    required this.toUserId,
    this.toUser,
    required this.amount,
    required this.currency,
    this.isPaid = false,
    this.paidAt,
  });

  factory PeriodDebt.fromJson(Map<String, dynamic> json) {
    final fromUserJson = json['from_user'] as Map<String, dynamic>?;
    final toUserJson   = json['to_user']   as Map<String, dynamic>?;
    return PeriodDebt(
      id:         json['id'] as String,
      reportId:   json['report_id'] as String,
      fromUserId: json['from_user_id'] as String,
      fromUser: fromUserJson != null
          ? GroupMember.fromJson({
              'id': '', 'group_id': '', 'user_id': json['from_user_id'],
              'role': 'member', 'user': fromUserJson,
            })
          : null,
      toUserId: json['to_user_id'] as String,
      toUser: toUserJson != null
          ? GroupMember.fromJson({
              'id': '', 'group_id': '', 'user_id': json['to_user_id'],
              'role': 'member', 'user': toUserJson,
            })
          : null,
      amount:   double.tryParse(json['amount'] as String? ?? '0') ?? 0,
      currency: json['currency'] as String? ?? 'ILS',
      isPaid:   json['is_paid'] as bool? ?? false,
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'] as String)
          : null,
    );
  }

  String get fromName => fromUser?.displayLabel ?? fromUserId;
  String get toName   => toUser?.displayLabel   ?? toUserId;
}


class PeriodReport {
  final String id;
  final String groupId;
  final int periodNumber;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double totalExpenses;
  final String currency;
  final String triggeredBy;
  final DateTime createdAt;
  final List<PeriodDebt> debts;

  const PeriodReport({
    required this.id,
    required this.groupId,
    required this.periodNumber,
    required this.periodStart,
    required this.periodEnd,
    required this.totalExpenses,
    required this.currency,
    required this.triggeredBy,
    required this.createdAt,
    required this.debts,
  });

  factory PeriodReport.fromJson(Map<String, dynamic> json) => PeriodReport(
        id:           json['id'] as String,
        groupId:      json['group_id'] as String,
        periodNumber: json['period_number'] as int? ?? 1,
        periodStart:  DateTime.parse(json['period_start'] as String),
        periodEnd:    DateTime.parse(json['period_end'] as String),
        totalExpenses: double.tryParse(json['total_expenses'] as String? ?? '0') ?? 0,
        currency:     json['currency'] as String? ?? 'ILS',
        triggeredBy:  json['triggered_by'] as String? ?? 'auto',
        createdAt:    DateTime.parse(json['created_at'] as String),
        debts: (json['debts'] as List<dynamic>? ?? [])
            .map((d) => PeriodDebt.fromJson(d as Map<String, dynamic>))
            .toList(),
      );

  bool get hasUnpaidDebts => debts.any((d) => !d.isPaid);
  int get unpaidCount => debts.where((d) => !d.isPaid).length;
}
