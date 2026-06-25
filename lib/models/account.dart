/// Modelo que representa una cuenta de dinero (ej. Billetera, Banco) en la base de datos.
class Account {
  final int? id;
  final String name;
  final String currency; // Símbolo o código de moneda (ej. "USD", "PYG")
  final String color;    // Código hexadecimal de color para la tarjeta visual
  final bool isActive;   // Si la cuenta está activa para transacciones
  final bool isDefault;  // Si es la cuenta principal por defecto

  Account({
    this.id,
    required this.name,
    required this.currency,
    required this.color,
    this.isActive = true,
    this.isDefault = false,
  });

  /// Crea un objeto [Account] a partir de un mapa de SQLite.
  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as int?,
      name: map['name'] as String,
      currency: map['currency'] as String,
      color: map['color'] as String,
      isActive: (map['is_active'] as int) == 1,
      isDefault: (map['is_default'] as int?) == 1,
    );
  }

  /// Convierte el objeto [Account] en un mapa para insertar en SQLite.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'currency': currency,
      'color': color,
      'is_active': isActive ? 1 : 0,
      'is_default': isDefault ? 1 : 0,
    };
  }

  /// Retorna una copia de la cuenta con algunos atributos modificados.
  Account copyWith({
    int? id,
    String? name,
    String? currency,
    String? color,
    bool? isActive,
    bool? isDefault,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
