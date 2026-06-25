class ScheduledTransaction {
  final int? id;
  final int accountId;
  final int categoryId;
  final int? subcategoryId;
  final String type; // 'income' o 'expense'
  final double amount;
  final String description;
  final String frequency; // 'once', 'daily', 'weekly', 'monthly', 'yearly'
  final DateTime nextDate;
  final int currentInstallment;
  final int? totalInstallments;
  final bool autoApply;
  final bool isActive;

  ScheduledTransaction({
    this.id,
    required this.accountId,
    required this.categoryId,
    this.subcategoryId,
    required this.type,
    required this.amount,
    required this.description,
    required this.frequency,
    required this.nextDate,
    this.currentInstallment = 1,
    this.totalInstallments,
    required this.autoApply,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'type': type,
      'amount': amount,
      'description': description,
      'frequency': frequency,
      'next_date': nextDate.toIso8601String().substring(0, 10),
      'current_installment': currentInstallment,
      'total_installments': totalInstallments,
      'auto_apply': autoApply ? 1 : 0,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory ScheduledTransaction.fromMap(Map<String, dynamic> map) {
    return ScheduledTransaction(
      id: map['id'] as int,
      accountId: map['account_id'] as int,
      categoryId: map['category_id'] as int,
      subcategoryId: map['subcategory_id'] as int?,
      type: map['type'] as String,
      amount: map['amount'] as double,
      description: map['description'] as String,
      frequency: map['frequency'] as String,
      nextDate: DateTime.parse(map['next_date'] as String),
      currentInstallment: map['current_installment'] as int,
      totalInstallments: map['total_installments'] as int?,
      autoApply: (map['auto_apply'] as int) == 1,
      isActive: (map['is_active'] as int) == 1,
    );
  }
}
