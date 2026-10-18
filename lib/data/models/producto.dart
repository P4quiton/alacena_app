class Producto {
  final int? id;
  final int categoriaId;
  final String nombre;
  final String? descripcion;
  final String? imagenPath;
  final int stockMinimo;
  final int? ultimaTiendaId;

  const Producto({
    this.id,
    required this.categoriaId,
    required this.nombre,
    this.descripcion,
    this.imagenPath,
    this.stockMinimo = 1,
    this.ultimaTiendaId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoria_id': categoriaId,
      'nombre': nombre,
      'descripcion': descripcion,
      'imagen_path': imagenPath,
      'stock_minimo': stockMinimo,
      'ultima_tienda_id': ultimaTiendaId,
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'] as int?,
      categoriaId: map['categoria_id'] as int,
      nombre: map['nombre'] as String,
      descripcion: map['descripcion'] as String?,
      imagenPath: map['imagen_path'] as String?,
      stockMinimo: map['stock_minimo'] as int,
      ultimaTiendaId: map['ultima_tienda_id'] as int?,
    );
  }

  Producto copyWith({
    int? id,
    int? categoriaId,
    String? nombre,
    String? descripcion,
    String? imagenPath,
    int? stockMinimo,
    int? ultimaTiendaId,
  }) {
    return Producto(
      id: id ?? this.id,
      categoriaId: categoriaId ?? this.categoriaId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      imagenPath: imagenPath ?? this.imagenPath,
      stockMinimo: stockMinimo ?? this.stockMinimo,
      ultimaTiendaId: ultimaTiendaId ?? this.ultimaTiendaId,
    );
  }
}
