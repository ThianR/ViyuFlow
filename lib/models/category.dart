/// Modelo que representa una categoría financiera (ej. "Hogar", "Salario")
/// que clasifica si la transacción es de ingresos ('income') o egresos ('expense').
class Category {
  final int? id;
  final String name;
  final String icon;  // Identificador de icono (ej. nombre del icono Material o emoji)
  final String color; // Código hexadecimal para el fondo visual del icono
  final String type;  // 'income' o 'expense'

  Category({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
  });

  /// Crea un objeto [Category] a partir de un mapa de SQLite.
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: map['color'] as String,
      type: map['type'] as String,
    );
  }

  /// Convierte el objeto [Category] en un mapa para insertar en SQLite.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'type': type,
    };
  }

  /// Retorna una copia de la categoría con algunos atributos modificados.
  Category copyWith({
    int? id,
    String? name,
    String? icon,
    String? color,
    String? type,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      type: type ?? this.type,
    );
  }
}
