
import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../models/carrito.dart';
import '../models/carrito_detalle.dart';

class CarritoRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  // Buscar el carrito activo o crear uno nuevo.
  Future<int> _obtenerOCrearActivo(
    Transaction txn,
  ) async {
    final registros = await txn.query(
      'carrito',
      where: 'estado = ?',
      whereArgs: ['activo'],
      orderBy: 'id ASC',
      limit: 1,
    );

    if (registros.isNotEmpty) {
      return registros.first['id'] as int;
    }

    return txn.insert('carrito', {
      'fecha_creacion': DateTime.now().toIso8601String(),
      'estado': 'activo',
    });
  }

  // Agregar un producto al carrito.
  // Si ya existe, incrementar su cantidad.
  Future<void> agregarProducto(
    int productoId, {
    int cantidad = 1,
  }) async {
    if (cantidad <= 0) {
      throw ArgumentError('La cantidad debe ser mayor que cero.');
    }

    final db = await _db;

    await db.transaction((txn) async {
      final carritoId = await _obtenerOCrearActivo(txn);

      final existentes = await txn.query(
        'carrito_detalles',
        where: 'carrito_id = ? AND producto_id = ?',
        whereArgs: [carritoId, productoId],
        limit: 1,
      );

      if (existentes.isEmpty) {
        await txn.insert('carrito_detalles', {
          'carrito_id': carritoId,
          'producto_id': productoId,
          'cantidad': cantidad,
        });
      } else {
        final actual = existentes.first['cantidad'] as int;

        await txn.update(
          'carrito_detalles',
          {'cantidad': actual + cantidad},
          where: 'carrito_id = ? AND producto_id = ?',
          whereArgs: [carritoId, productoId],
        );
      }
    });
  }

  // Consultar el carrito activo.
  Future<Carrito?> obtenerCarritoActivo() async {
    final db = await _db;

    final registros = await db.query(
      'carrito',
      where: 'estado = ?',
      whereArgs: ['activo'],
      orderBy: 'id ASC',
      limit: 1,
    );

    if (registros.isEmpty) return null;

    return Carrito.fromMap(registros.first);
  }

  // Consultar los artículos agregados al carrito.
  Future<List<CarritoDetalle>> obtenerDetalles() async {
    final db = await _db;
    final carrito = await obtenerCarritoActivo();

    if (carrito?.id == null) return [];

    final registros = await db.query(
      'carrito_detalles',
      where: 'carrito_id = ?',
      whereArgs: [carrito!.id],
      orderBy: 'id ASC',
    );

    return registros.map(CarritoDetalle.fromMap).toList();
  }

  // Cambiar la cantidad deseada de un producto.
  Future<int> actualizarCantidad(
    int productoId,
    int cantidad,
  ) async {
    if (cantidad <= 0) {
      throw ArgumentError('La cantidad debe ser mayor que cero.');
    }

    final db = await _db;
    final carrito = await obtenerCarritoActivo();

    if (carrito?.id == null) return 0;

    return db.update(
      'carrito_detalles',
      {'cantidad': cantidad},
      where: 'carrito_id = ? AND producto_id = ?',
      whereArgs: [carrito!.id, productoId],
    );
  }

  // Eliminar un artículo del carrito activo.
  Future<int> eliminarProducto(int productoId) async {
    final db = await _db;
    final carrito = await obtenerCarritoActivo();

    if (carrito?.id == null) return 0;

    return db.delete(
      'carrito_detalles',
      where: 'carrito_id = ? AND producto_id = ?',
      whereArgs: [carrito!.id, productoId],
    );
  }

  // Vaciar la lista de compras.
  Future<int> vaciarCarrito() async {
    final db = await _db;
    final carrito = await obtenerCarritoActivo();

    if (carrito?.id == null) return 0;

    return db.delete(
      'carrito_detalles',
      where: 'carrito_id = ?',
      whereArgs: [carrito!.id],
    );
  }

  // Cantidad de productos diferentes en el carrito.
  // Se utilizará para el badge del icono.
  Future<int> contarProductos() async {
    final detalles = await obtenerDetalles();
    return detalles.length;
  }

  // Suma de todas las unidades solicitadas.
  Future<int> contarUnidades() async {
    final detalles = await obtenerDetalles();

    return detalles.fold<int>(
      0,
      (total, detalle) => total + detalle.cantidad,
    );
  }

  // Marcar la lista de compras como completada.
  Future<void> completarCarrito() async {
    final db = await _db;

    await db.transaction((txn) async {
      final registros = await txn.query(
        'carrito',
        where: 'estado = ?',
        whereArgs: ['activo'],
        orderBy: 'id ASC',
        limit: 1,
      );

      if (registros.isEmpty) {
        throw StateError('No existe un carrito activo.');
      }

      final carritoId = registros.first['id'] as int;

      final detalles = await txn.query(
        'carrito_detalles',
        where: 'carrito_id = ?',
        whereArgs: [carritoId],
        limit: 1,
      );

      if (detalles.isEmpty) {
        throw StateError('No se puede completar un carrito vacío.');
      }

      await txn.update(
        'carrito',
        {'estado': 'completado'},
        where: 'id = ?',
        whereArgs: [carritoId],
      );
    });
  }
}
