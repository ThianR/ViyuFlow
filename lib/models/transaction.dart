/// Modelo que representa una transacción de ingreso o egreso en ViyuFlow.
class TransactionModel {
  final int? id;
  final int accountId;
  final int categoryId;
  final int? subcategoryId; // Nullable si no se especifica subcategoría
  final double amount;
  final String description;
  final DateTime date;
  final String type; // 'income' o 'expense'
  final bool syncStatus; // false = pendiente de subir, true = sincronizado
  final DateTime? syncDate; // Fecha de sincronización con Google Drive

  // Campos cargados mediante Joins de base de datos para la UI (no se guardan directamente)
  final String? accountName;
  final String? accountCurrency;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final String? subcategoryName;

  TransactionModel({
    this.id,
    required this.accountId,
    required this.categoryId,
    this.subcategoryId,
    required this.amount,
    required this.description,
    required this.date,
    required this.type,
    this.syncStatus = false,
    this.syncDate,
    this.accountName,
    this.accountCurrency,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.subcategoryName,
  });

  /// Crea un objeto [TransactionModel] a partir de un mapa de SQLite.
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      accountId: map['account_id'] as int,
      categoryId: map['category_id'] as int,
      subcategoryId: map['subcategory_id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String? ?? '',
      date: DateTime.parse(map['date'] as String),
      type: map['type'] as String,
      syncStatus: (map['sync_status'] as int? ?? 0) == 1,
      syncDate: map['sync_date'] != null ? DateTime.parse(map['sync_date'] as String) : null,
      
      // Mapeo opcional de Joins
      accountName: map['account_name'] as String?,
      accountCurrency: map['account_currency'] as String?,
      categoryName: map['category_name'] as String?,
      categoryIcon: map['category_icon'] as String?,
      categoryColor: map['category_color'] as String?,
      subcategoryName: map['subcategory_name'] as String?,
    );
  }

  /// Convierte el objeto [TransactionModel] en un mapa para insertar en SQLite.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'account_id': accountId,
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'type': type,
      'sync_status': syncStatus ? 1 : 0,
      'sync_date': syncDate?.toIso8601String(),
    };
  }

  /// Retorna una copia de la transacción con algunos atributos modificados.
  TransactionModel copyWith({
    int? id,
    int? accountId,
    int? categoryId,
    int? subcategoryId,
    double? amount,
    String? description,
    DateTime? date,
    String? type,
    bool? syncStatus,
    DateTime? syncDate,
    String? accountName,
    String? accountCurrency,
    String? categoryName,
    String? categoryIcon,
    String? categoryColor,
    String? subcategoryName,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      type: type ?? this.type,
      syncStatus: syncStatus ?? this.syncStatus,
      syncDate: syncDate ?? this.syncDate,
      accountName: accountName ?? this.accountName,
      accountCurrency: accountCurrency ?? this.accountCurrency,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
      subcategoryName: subcategoryName ?? this.subcategoryName,
    );
  }
}
