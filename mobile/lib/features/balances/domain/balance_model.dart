class UserBalance {
  final String userId;
  final String displayName;
  final String netAmount;
  final String totalPaid;
  final String totalOwed;
  final String status; // creditor / debtor / settled

  const UserBalance({
    required this.userId,
    required this.displayName,
    required this.netAmount,
    required this.totalPaid,
    required this.totalOwed,
    required this.status,
  });

  factory UserBalance.fromJson(Map<String, dynamic> json) => UserBalance(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String,
        netAmount: json['net_amount'] as String,
        totalPaid: json['total_paid'] as String,
        totalOwed: json['total_owed'] as String,
        status: json['status'] as String,
      );

  double get netDouble => double.tryParse(netAmount) ?? 0;
  bool get isCreditor => status == 'creditor';
  bool get isDebtor => status == 'debtor';
  bool get isSettled => status == 'settled';
  bool get isPositive => netDouble > 0;
}

class SettlementSuggestion {
  final String fromUserId;
  final String fromDisplayName;
  final String toUserId;
  final String toDisplayName;
  final String amount;
  final String currency;
  // Recipient's payment details (for Bit / PayBox / bank transfer)
  final String? toPaymentPhone;
  final String? toBankName;
  final String? toBankBranch;
  final String? toBankAccountNumber;

  const SettlementSuggestion({
    required this.fromUserId,
    required this.fromDisplayName,
    required this.toUserId,
    required this.toDisplayName,
    required this.amount,
    required this.currency,
    this.toPaymentPhone,
    this.toBankName,
    this.toBankBranch,
    this.toBankAccountNumber,
  });

  factory SettlementSuggestion.fromJson(Map<String, dynamic> json) =>
      SettlementSuggestion(
        fromUserId: json['from_user_id'] as String,
        fromDisplayName: json['from_display_name'] as String,
        toUserId: json['to_user_id'] as String,
        toDisplayName: json['to_display_name'] as String,
        amount: json['amount'] as String,
        currency: json['currency'] as String,
        toPaymentPhone: json['to_payment_phone'] as String?,
        toBankName: json['to_bank_name'] as String?,
        toBankBranch: json['to_bank_branch'] as String?,
        toBankAccountNumber: json['to_bank_account_number'] as String?,
      );

  double get amountDouble => double.tryParse(amount) ?? 0;

  bool get hasPaymentDetails =>
      toPaymentPhone != null || toBankAccountNumber != null;
}
