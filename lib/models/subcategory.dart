/// Modelo que representa una subcategoría asociada a una categoría principal.
/// Ejemplo: Categoría "Hogar" -> Subcategoría "Energía Eléctrica".
class Subcategory {
  final int? id;
  final int categoryId; // Clave foránea que apunta a la categoría padre
  final String name;     // Nombre de la subcategoría

  Subcategory({
    this.id,
    required this.categoryId,
    required this.name,
  });

  /// Crea un objeto [Subcategory] a partir de un mapa de SQLite.
  factory Subcategory.fromMap(Map<String, dynamic> map) {
    return Subcategory(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int,
      name: map['name'] as String,
    );
  }

  /// Convierte el objeto [Subcategory] en un mapa para insertar en SQLite.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category_id': categoryId,
      'name': name,
    };
  }

  /// Retorna una copia de la subcategoría con algunos atributos modificados.
  Subcategory copyWith({
    int? id,
    int? categoryId,
    String? name,
  }) {
    return Subcategory(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
    );
  }
}
