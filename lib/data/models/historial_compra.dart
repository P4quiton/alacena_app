class HistorialCompra {
  final int? id;
  final int productoId;
  final int tiendaId;
  final int? loteId;
  final int cantidad;
  final double precioUnitario;
  final DateTime fechaCompra;

  const HistorialCompra({
    this.id,
    required this.productoId,
    required this.tiendaId,
    this.loteId,
    required this.cantidad,
    required this.precioUnitario,
    required this.fechaCompra,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'producto_id': productoId,
      'tienda_id': tiendaId,
      'lote_id': loteId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'fecha_compra': fechaCompra.toIso8601String(),
    };
  }

  factory HistorialCompra.fromMap(Map<String, dynamic> map) {
    return HistorialCompra(
      id: map['id'] as int?,
      productoId: map['producto_id'] as int,
      tiendaId: map['tienda_id'] as int,
      loteId: map['lote_id'] as int?,
      cantidad: map['cantidad'] as int,
      precioUnitario: (map['precio_unitario'] as num).toDouble(),
      fechaCompra: DateTime.parse(map['fecha_compra'] as String),
    );
  }

  HistorialCompra copyWith({
    int? id,
    int? productoId,
    int? tiendaId,
    int? loteId,
    int? cantidad,
    double? precioUnitario,
    DateTime? fechaCompra,
  }) {
    return HistorialCompra(
      id: id ?? this.id,
      productoId: productoId ?? this.productoId,
      tiendaId: tiendaId ?? this.tiendaId,
      loteId: loteId ?? this.loteId,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      fechaCompra: fechaCompra ?? this.fechaCompra,
    );
  }
}
