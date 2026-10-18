class CarritoDetalle {
  final int? id;
  final int carritoId;
  final int productoId;
  final int cantidad;

  const CarritoDetalle({
    this.id,
    required this.carritoId,
    required this.productoId,
    this.cantidad = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'carrito_id': carritoId,
      'producto_id': productoId,
      'cantidad': cantidad,
    };
  }

  factory CarritoDetalle.fromMap(Map<String, dynamic> map) {
    return CarritoDetalle(
      id: map['id'] as int?,
      carritoId: map['carrito_id'] as int,
      productoId: map['producto_id'] as int,
      cantidad: map['cantidad'] as int,
    );
  }

  CarritoDetalle copyWith({
    int? id,
    int? carritoId,
    int? productoId,
    int? cantidad,
  }) {
    return CarritoDetalle(
      id: id ?? this.id,
      carritoId: carritoId ?? this.carritoId,
      productoId: productoId ?? this.productoId,
      cantidad: cantidad ?? this.cantidad,
    );
  }
}
