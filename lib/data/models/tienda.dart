
class Tienda {
  final int? id;
  final String nombre;
  final String? direccion;

  const Tienda({
    this.id,
    required this.nombre,
    this.direccion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'direccion': direccion,
    };
  }

  factory Tienda.fromMap(Map<String, dynamic> map) {
    return Tienda(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      direccion: map['direccion'] as String?,
    );
  }

  Tienda copyWith({
    int? id,
    String? nombre,
    String? direccion,
  }) {
    return Tienda(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      direccion: direccion ?? this.direccion,
    );
  }
}
