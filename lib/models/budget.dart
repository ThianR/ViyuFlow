class Budget {
  final int? id;
  final double amount;
  final String currency;
  final int? accountId; // null = all accounts of this currency
  final int? categoryId; // null = global budget
  final int? subcategoryId; // optional
  final String period; // 'monthly' by default
  final bool isActive;

  Budget({
    this.id,
    required this.amount,
    required this.currency,
    this.accountId,
    this.categoryId,
    this.subcategoryId,
    this.period = 'monthly',
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'currency': currency,
      'account_id': accountId,
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'period': period,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as int,
      amount: map['amount'] as double,
      currency: map['currency'] as String,
      accountId: map['account_id'] as int?,
      categoryId: map['category_id'] as int?,
      subcategoryId: map['subcategory_id'] as int?,
      period: map['period'] as String,
      isActive: (map['is_active'] as int) == 1,
    );
  }
}
