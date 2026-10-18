
class Lote {
  final int? id;
  final int productoId;
  final int cantidad;
  final DateTime fechaCaducidad;
  final bool alertaActiva;

  const Lote({
    this.id,
    required this.productoId,
    required this.cantidad,
    required this.fechaCaducidad,
    this.alertaActiva = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'producto_id': productoId,
      'cantidad': cantidad,
      'fecha_caducidad':
          '${fechaCaducidad.year.toString().padLeft(4, '0')}-'
          '${fechaCaducidad.month.toString().padLeft(2, '0')}-'
          '${fechaCaducidad.day.toString().padLeft(2, '0')}',
      'alerta_activa': alertaActiva ? 1 : 0,
    };
  }

  factory Lote.fromMap(Map<String, dynamic> map) {
    return Lote(
      id: map['id'] as int?,
      productoId: map['producto_id'] as int,
      cantidad: map['cantidad'] as int,
      fechaCaducidad: DateTime.parse(map['fecha_caducidad'] as String),
      alertaActiva: (map['alerta_activa'] as int) == 1,
    );
  }

  Lote copyWith({
    int? id,
    int? productoId,
    int? cantidad,
    DateTime? fechaCaducidad,
    bool? alertaActiva,
  }) {
    return Lote(
      id: id ?? this.id,
      productoId: productoId ?? this.productoId,
      cantidad: cantidad ?? this.cantidad,
      fechaCaducidad: fechaCaducidad ?? this.fechaCaducidad,
      alertaActiva: alertaActiva ?? this.alertaActiva,
    );
  }
}
