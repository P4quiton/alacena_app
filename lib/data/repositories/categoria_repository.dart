
import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../models/categoria.dart';

class CategoriaRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  // Registrar una categoría
  Future<int> insertar(Categoria categoria) async {
    final db = await _db;

    return db.insert(
      'categorias',
      categoria.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  // Consultar todas las categorías
  Future<List<Categoria>> obtenerTodas() async {
    final db = await _db;

    final registros = await db.query(
      'categorias',
      orderBy: 'nombre COLLATE NOCASE ASC',
    );

    return registros.map(Categoria.fromMap).toList();
  }

  // Buscar una categoría por ID
  Future<Categoria?> obtenerPorId(int id) async {
    final db = await _db;

    final registros = await db.query(
      'categorias',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (registros.isEmpty) return null;

    return Categoria.fromMap(registros.first);
  }

  // Actualizar una categoría existente
  Future<int> actualizar(Categoria categoria) async {
    if (categoria.id == null) {
      throw ArgumentError('La categoría necesita un ID para actualizarse.');
    }

    final db = await _db;

    return db.update(
      'categorias',
      categoria.toMap(),
      where: 'id = ?',
      whereArgs: [categoria.id],
    );
  }

  // Eliminar una categoría
  Future<int> eliminar(int id) async {
    final db = await _db;

    return db.delete(
      'categorias',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
