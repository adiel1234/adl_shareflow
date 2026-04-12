class Expense {
  final String id;
  final String groupId;
  final String paidById;
  final String? paidByName;
  final String? createdById;
  final String title;
  final String originalAmount;
  final String originalCurrency;
  final String exchangeRate;
  final String convertedAmount;
  final String? category;
  final String splitType;
  final String? expenseDate;
  final String? notes;
  final List<ExpenseParticipant> participants;
  final DateTime? createdAt;
  final String myShare;
  final bool isPayer;
  final bool isCreator;
  final bool isSystemExpense;

  const Expense({
    required this.id,
    required this.groupId,
    required this.paidById,
    this.paidByName,
    this.createdById,
    required this.title,
    required this.originalAmount,
    required this.originalCurrency,
    this.exchangeRate = '1.000000',
    required this.convertedAmount,
    this.category,
    required this.splitType,
    this.expenseDate,
    this.notes,
    this.participants = const [],
    this.createdAt,
    this.myShare = '0.00',
    this.isPayer = false,
    this.isCreator = false,
    this.isSystemExpense = false,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    final payer = json['payer'] as Map<String, dynamic>?;
    final parts = (json['participants'] as List<dynamic>? ?? [])
        .map((p) => ExpenseParticipant.fromJson(p as Map<String, dynamic>))
        .toList();
    return Expense(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      paidById: json['paid_by'] as String,
      paidByName: payer?['display_name'] as String?,
      createdById: json['created_by'] as String?,
      title: json['title'] as String,
      originalAmount: json['original_amount'] as String,
      originalCurrency: json['original_currency'] as String,
      exchangeRate: json['exchange_rate'] as String? ?? '1.000000',
      convertedAmount: json['converted_amount'] as String,
      category: json['category'] as String?,
      splitType: json['split_type'] as String? ?? 'equal',
      expenseDate: json['expense_date'] as String?,
      notes: json['notes'] as String?,
      participants: parts,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      myShare: json['my_share'] as String? ?? '0.00',
      isPayer: json['is_payer'] as bool? ?? false,
      isCreator: json['is_creator'] as bool? ?? false,
      isSystemExpense: json['is_system_expense'] as bool? ?? false,
    );
  }

  String get categoryEmoji {
    switch (category) {
      case 'food': return '🍔';
      case 'travel': return '✈️';
      case 'housing': return '🏠';
      case 'transport': return '🚌';
      case 'entertainment': return '🎬';
      case 'shopping': return '🛍️';
      case 'health': return '💊';
      case 'utilities': return '💡';
      default: return '💳';
    }
  }

  double get amountDouble => double.tryParse(originalAmount) ?? 0;
}

class ExpenseParticipant {
  final String id;
  final String userId;
  final String? displayName;
  final String shareAmount;
  final bool isSettled;

  const ExpenseParticipant({
    required this.id,
    required this.userId,
    this.displayName,
    required this.shareAmount,
    this.isSettled = false,
  });

  factory ExpenseParticipant.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return ExpenseParticipant(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      displayName: user?['display_name'] as String?,
      shareAmount: json['share_amount'] as String,
      isSettled: json['is_settled'] as bool? ?? false,
    );
  }
}
