import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../models/lote.dart';

class LoteRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<int> insertar(Lote lote) async {
    final db = await _db;

    return db.insert(
      'lotes',
      lote.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Lote>> obtenerTodos() async {
    final db = await _db;

    final registros = await db.query(
      'lotes',
      orderBy: 'fecha_caducidad ASC, id ASC',
    );

    return registros.map(Lote.fromMap).toList();
  }

  Future<Lote?> obtenerPorId(int id) async {
    final db = await _db;

    final registros = await db.query(
      'lotes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (registros.isEmpty) return null;

    return Lote.fromMap(registros.first);
  }

  // Consultar lotes activos de un producto en orden FEFO.
  Future<List<Lote>> obtenerActivosPorProducto(int productoId) async {
    final db = await _db;

    final registros = await db.query(
      'lotes',
      where: 'producto_id = ? AND cantidad > 0',
      whereArgs: [productoId],
      orderBy: 'fecha_caducidad ASC, id ASC',
    );

    return registros.map(Lote.fromMap).toList();
  }

  Future<int> actualizar(Lote lote) async {
    if (lote.id == null) {
      throw ArgumentError('El lote necesita un ID para actualizarse.');
    }

    final db = await _db;

    return db.update(
      'lotes',
      lote.toMap(),
      where: 'id = ?',
      whereArgs: [lote.id],
    );
  }

  Future<int> eliminar(int id) async {
    final db = await _db;

    return db.delete('lotes', where: 'id = ?', whereArgs: [id]);
  }

  // Obtener lotes próximos a caducar.
  Future<List<Lote>> obtenerProximosACaducar({int diasAnticipacion = 3}) async {
    if (diasAnticipacion < 0) {
      throw ArgumentError('Los días de anticipación no pueden ser negativos.');
    }

    final db = await _db;
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final limite = inicio.add(Duration(days: diasAnticipacion));

    String fecha(DateTime valor) =>
        '${valor.year.toString().padLeft(4, '0')}-'
        '${valor.month.toString().padLeft(2, '0')}-'
        '${valor.day.toString().padLeft(2, '0')}';

    final registros = await db.query(
      'lotes',
      where: '''
        cantidad > 0
        AND fecha_caducidad >= ?
        AND fecha_caducidad <= ?
      ''',
      whereArgs: [fecha(inicio), fecha(limite)],
      orderBy: 'fecha_caducidad ASC, id ASC',
    );

    return registros.map(Lote.fromMap).toList();
  }

  // Obtener lotes caducados con existencias.
  Future<List<Lote>> obtenerCaducados() async {
    final db = await _db;

    final hoy = DateTime.now();
    final fechaHoy =
        '${hoy.year.toString().padLeft(4, '0')}-'
        '${hoy.month.toString().padLeft(2, '0')}-'
        '${hoy.day.toString().padLeft(2, '0')}';

    final registros = await db.query(
      'lotes',
      where: 'cantidad > 0 AND fecha_caducidad < ?',
      whereArgs: [fechaHoy],
      orderBy: 'fecha_caducidad ASC',
    );

    return registros.map(Lote.fromMap).toList();
  }

  // Descontar existencias utilizando FEFO.
  Future<void> consumirProducto(int productoId, int cantidad) async {
    if (cantidad <= 0) {
      throw ArgumentError('La cantidad a consumir debe ser mayor que cero.');
    }

    final db = await _db;

    await db.transaction((txn) async {
      final lotes = await txn.query(
        'lotes',
        where: '''
          producto_id = ?
          AND cantidad > 0
          AND fecha_caducidad >= ?
        ''',
        whereArgs: [productoId, _fechaHoy()],
        orderBy: 'fecha_caducidad ASC, id ASC',
      );

      final disponible = lotes.fold<int>(
        0,
        (total, lote) => total + (lote['cantidad'] as int),
      );

      if (disponible < cantidad) {
        throw StateError('Existencias insuficientes o productos caducados.');
      }

      var restante = cantidad;

      for (final lote in lotes) {
        if (restante == 0) break;

        final id = lote['id'] as int;
        final actual = lote['cantidad'] as int;
        final descontar = restante < actual ? restante : actual;

        await txn.update(
          'lotes',
          {'cantidad': actual - descontar},
          where: 'id = ?',
          whereArgs: [id],
        );

        restante -= descontar;
      }
    });
  }

  String _fechaHoy() {
    final hoy = DateTime.now();

    return '${hoy.year.toString().padLeft(4, '0')}-'
        '${hoy.month.toString().padLeft(2, '0')}-'
        '${hoy.day.toString().padLeft(2, '0')}';
  }
}
