
class Categoria {
  final int? id;
  final String nombre;
  final String? descripcion;

  const Categoria({
    this.id,
    required this.nombre,
    this.descripcion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
    };
  }

  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      descripcion: map['descripcion'] as String?,
    );
  }

  Categoria copyWith({
    int? id,
    String? nombre,
    String? descripcion,
  }) {
    return Categoria(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
    );
  }
}
