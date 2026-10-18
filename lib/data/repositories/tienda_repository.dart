import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../models/tienda.dart';

class TiendaRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  // Registrar una tienda
  Future<int> insertar(Tienda tienda) async {
    final db = await _db;

    return db.insert(
      'tiendas',
      tienda.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  // Consultar todas las tiendas
  Future<List<Tienda>> obtenerTodas() async {
    final db = await _db;

    final registros = await db.query(
      'tiendas',
      orderBy: 'nombre COLLATE NOCASE ASC',
    );

    return registros.map(Tienda.fromMap).toList();
  }

  // Buscar tienda por ID
  Future<Tienda?> obtenerPorId(int id) async {
    final db = await _db;

    final registros = await db.query(
      'tiendas',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (registros.isEmpty) return null;

    return Tienda.fromMap(registros.first);
  }

  // Actualizar información de una tienda
  Future<int> actualizar(Tienda tienda) async {
    if (tienda.id == null) {
      throw ArgumentError('La tienda necesita un ID para actualizarse.');
    }

    final db = await _db;

    return db.update(
      'tiendas',
      tienda.toMap(),
      where: 'id = ?',
      whereArgs: [tienda.id],
    );
  }

  // Eliminar una tienda
  Future<int> eliminar(int id) async {
    final db = await _db;

    return db.delete('tiendas', where: 'id = ?', whereArgs: [id]);
  }
}
