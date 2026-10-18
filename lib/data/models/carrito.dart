class Carrito {
  final int? id;
  final DateTime fechaCreacion;
  final String estado;

  const Carrito({this.id, required this.fechaCreacion, this.estado = 'activo'});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'estado': estado,
    };
  }

  factory Carrito.fromMap(Map<String, dynamic> map) {
    return Carrito(
      id: map['id'] as int?,
      fechaCreacion: DateTime.parse(map['fecha_creacion'] as String),
      estado: map['estado'] as String,
    );
  }

  Carrito copyWith({int? id, DateTime? fechaCreacion, String? estado}) {
    return Carrito(
      id: id ?? this.id,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      estado: estado ?? this.estado,
    );
  }
}
