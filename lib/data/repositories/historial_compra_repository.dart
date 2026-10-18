
import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../models/historial_compra.dart';
import '../models/tienda.dart';

class HistorialCompraRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  // Registrar una compra y crear su lote de inventario.
  Future<int> registrarCompra({
    required HistorialCompra compra,
    required DateTime fechaCaducidad,
    bool alertaActiva = true,
  }) async {
    if (compra.cantidad <= 0) {
      throw ArgumentError('La cantidad debe ser mayor que cero.');
    }

    if (compra.precioUnitario < 0 ||
        !compra.precioUnitario.isFinite) {
      throw ArgumentError('El precio unitario debe ser válido.');
    }

    if (compra.id != null || compra.loteId != null) {
      throw ArgumentError(
        'Una compra nueva no debe tener ID ni lote asignado.',
      );
    }

    final db = await _db;

    return db.transaction((txn) async {
      // Crear el lote asociado a la compra.
      final loteId = await txn.insert('lotes', {
        'producto_id': compra.productoId,
        'cantidad': compra.cantidad,
        'fecha_caducidad': _formatearFecha(fechaCaducidad),
        'alerta_activa': alertaActiva ? 1 : 0,
      });

      // Guardar el historial de la compra.
      final datosCompra = compra.toMap();
      datosCompra.remove('id');
      datosCompra['lote_id'] = loteId;

      final compraId = await txn.insert(
        'historial_compras',
        datosCompra,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      // El trigger SQLite actualiza automáticamente
      // productos.ultima_tienda_id.
      return compraId;
    });
  }

  // Consultar todo el historial de compras.
  Future<List<HistorialCompra>> obtenerTodas() async {
    final db = await _db;

    final registros = await db.query(
      'historial_compras',
      orderBy: 'fecha_compra DESC, id DESC',
    );

    return registros.map(HistorialCompra.fromMap).toList();
  }

  // Consultar una compra por ID.
  Future<HistorialCompra?> obtenerPorId(int id) async {
    final db = await _db;

    final registros = await db.query(
      'historial_compras',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (registros.isEmpty) return null;

    return HistorialCompra.fromMap(registros.first);
  }

  // Consultar el historial de un producto.
  Future<List<HistorialCompra>> obtenerPorProducto(
    int productoId,
  ) async {
    final db = await _db;

    final registros = await db.query(
      'historial_compras',
      where: 'producto_id = ?',
      whereArgs: [productoId],
      orderBy: 'fecha_compra DESC, id DESC',
    );

    return registros.map(HistorialCompra.fromMap).toList();
  }

  // Obtener las tiendas donde se ha comprado un producto.
  Future<List<Tienda>> obtenerTiendasPorProducto(
    int productoId,
  ) async {
    final db = await _db;

    final registros = await db.rawQuery(
      '''
      SELECT DISTINCT t.id, t.nombre, t.direccion
      FROM tiendas t
      INNER JOIN historial_compras h
        ON h.tienda_id = t.id
      WHERE h.producto_id = ?
      ORDER BY t.nombre COLLATE NOCASE ASC
      ''',
      [productoId],
    );

    return registros.map(Tienda.fromMap).toList();
  }

  // Consultar la última compra de un producto.
  Future<HistorialCompra?> obtenerUltimaCompra(
    int productoId,
  ) async {
    final db = await _db;

    final registros = await db.query(
      'historial_compras',
      where: 'producto_id = ?',
      whereArgs: [productoId],
      orderBy: 'fecha_compra DESC, id DESC',
      limit: 1,
    );

    if (registros.isEmpty) return null;

    return HistorialCompra.fromMap(registros.first);
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.year.toString().padLeft(4, '0')}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}';
  }
}
