
import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../models/producto.dart';

class ProductoRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  // Registrar producto.
  Future<int> insertar(Producto producto) async {
    final db = await _db;

    return db.insert(
      'productos',
      producto.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  // Consultar todos los productos.
  Future<List<Producto>> obtenerTodos() async {
    final db = await _db;

    final registros = await db.query(
      'productos',
      orderBy: 'nombre COLLATE NOCASE ASC',
    );

    return registros.map(Producto.fromMap).toList();
  }

  // Obtener producto por ID.
  Future<Producto?> obtenerPorId(int id) async {
    final db = await _db;

    final registros = await db.query(
      'productos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (registros.isEmpty) return null;

    return Producto.fromMap(registros.first);
  }

  // Consultar productos de una categoría.
  Future<List<Producto>> obtenerPorCategoria(int categoriaId) async {
    final db = await _db;

    final registros = await db.query(
      'productos',
      where: 'categoria_id = ?',
      whereArgs: [categoriaId],
      orderBy: 'nombre COLLATE NOCASE ASC',
    );

    return registros.map(Producto.fromMap).toList();
  }

  // Actualizar producto.
  Future<int> actualizar(Producto producto) async {
    if (producto.id == null) {
      throw ArgumentError('El producto necesita un ID para actualizarse.');
    }

    final db = await _db;

    return db.update(
      'productos',
      producto.toMap(),
      where: 'id = ?',
      whereArgs: [producto.id],
    );
  }

  // Eliminar producto.
  // SQLite impide eliminarlo si tiene registros dependientes.
  Future<int> eliminar(int id) async {
    final db = await _db;

    return db.delete(
      'productos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Calcular las existencias totales del producto.
  Future<int> obtenerStockTotal(int productoId) async {
    final db = await _db;

    final resultado = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(cantidad), 0) AS stock_total
      FROM lotes
      WHERE producto_id = ? AND cantidad > 0
      ''',
      [productoId],
    );

    return (resultado.first['stock_total'] as num).toInt();
  }

  // Obtener los productos agotados.
  Future<List<Producto>> obtenerAgotados() async {
    final db = await _db;

    final registros = await db.rawQuery('''
      SELECT p.*
      FROM productos p
      LEFT JOIN lotes l ON l.producto_id = p.id
      GROUP BY p.id
      HAVING COALESCE(SUM(l.cantidad), 0) = 0
      ORDER BY p.nombre COLLATE NOCASE
    ''');

    return registros.map(Producto.fromMap).toList();
  }

  // Obtener productos por agotarse.
  Future<List<Producto>> obtenerPorAgotarse() async {
    final db = await _db;

    final registros = await db.rawQuery('''
      SELECT p.*
      FROM productos p
      LEFT JOIN lotes l ON l.producto_id = p.id
      GROUP BY p.id
      HAVING COALESCE(SUM(l.cantidad), 0) > 0
         AND COALESCE(SUM(l.cantidad), 0) <= p.stock_minimo
      ORDER BY p.nombre COLLATE NOCASE
    ''');

    return registros.map(Producto.fromMap).toList();
  }
}
