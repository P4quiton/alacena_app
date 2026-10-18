
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String databaseName = 'alacena.db';
  static const int databaseVersion = 1;

  Database? _database;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, databaseName);

    return openDatabase(
      path,
      version: databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Categorías de productos
    await db.execute('''
      CREATE TABLE categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE,
        descripcion TEXT
      )
    ''');

    // Establecimientos donde se realizan las compras
    await db.execute('''
      CREATE TABLE tiendas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        direccion TEXT
      )
    ''');

    // Información general de los productos
    await db.execute('''
      CREATE TABLE productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoria_id INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        imagen_path TEXT,
        stock_minimo INTEGER NOT NULL DEFAULT 1
          CHECK(stock_minimo >= 0),
        ultima_tienda_id INTEGER,

        FOREIGN KEY(categoria_id)
          REFERENCES categorias(id)
          ON DELETE RESTRICT,

        FOREIGN KEY(ultima_tienda_id)
          REFERENCES tiendas(id)
          ON DELETE RESTRICT
      )
    ''');

    // Lotes con cantidades y fechas de caducidad
    await db.execute('''
      CREATE TABLE lotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER NOT NULL,
        cantidad INTEGER NOT NULL DEFAULT 0
          CHECK(cantidad >= 0),
        fecha_caducidad TEXT NOT NULL,
        alerta_activa INTEGER NOT NULL DEFAULT 1
          CHECK(alerta_activa IN (0, 1)),

        FOREIGN KEY(producto_id)
          REFERENCES productos(id)
          ON DELETE RESTRICT,

        UNIQUE(id, producto_id)
      )
    ''');

    // Registro histórico de compras
    await db.execute('''
      CREATE TABLE historial_compras (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER NOT NULL,
        tienda_id INTEGER NOT NULL,
        lote_id INTEGER,
        cantidad INTEGER NOT NULL
          CHECK(cantidad > 0),
        precio_unitario REAL NOT NULL DEFAULT 0
          CHECK(precio_unitario >= 0),
        fecha_compra TEXT NOT NULL,

        FOREIGN KEY(producto_id)
          REFERENCES productos(id)
          ON DELETE RESTRICT,

        FOREIGN KEY(tienda_id)
          REFERENCES tiendas(id)
          ON DELETE RESTRICT,

        FOREIGN KEY(lote_id, producto_id)
          REFERENCES lotes(id, producto_id)
          ON DELETE RESTRICT
      )
    ''');

    // Carritos de compras
    await db.execute('''
      CREATE TABLE carrito (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha_creacion TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'activo'
          CHECK(estado IN ('activo', 'completado'))
      )
    ''');

    // Productos agregados a cada carrito
    await db.execute('''
      CREATE TABLE carrito_detalles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        carrito_id INTEGER NOT NULL,
        producto_id INTEGER NOT NULL,
        cantidad INTEGER NOT NULL DEFAULT 1
          CHECK(cantidad > 0),

        UNIQUE(carrito_id, producto_id),

        FOREIGN KEY(carrito_id)
          REFERENCES carrito(id)
          ON DELETE CASCADE,

        FOREIGN KEY(producto_id)
          REFERENCES productos(id)
          ON DELETE RESTRICT
      )
    ''');

    // Índice para facilitar las consultas FEFO
    await db.execute('''
      CREATE INDEX idx_lotes_producto_caducidad
      ON lotes(producto_id, fecha_caducidad)
    ''');

    // Índice para consultar el historial por producto
    await db.execute('''
      CREATE INDEX idx_compras_producto
      ON historial_compras(producto_id)
    ''');

    // Actualiza automáticamente la última tienda
    // cuando se registra una compra.
    await db.execute('''
      CREATE TRIGGER actualizar_ultima_tienda
      AFTER INSERT ON historial_compras
      BEGIN
        UPDATE productos
        SET ultima_tienda_id = NEW.tienda_id
        WHERE id = NEW.producto_id;
      END
    ''');
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
