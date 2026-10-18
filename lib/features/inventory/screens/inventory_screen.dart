
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/models/lote.dart';
import '../../../data/models/producto.dart';
import '../../../data/repositories/lote_repository.dart';
import '../../../data/repositories/producto_repository.dart';
import 'categories_screen.dart';
import 'product_form_screen.dart';

enum EstadoInventario {
  caducado,
  agotado,
  porCaducar,
  porAgotarse,
  disponible,
}

class ResumenProducto {
  final Producto producto;
  final int stock;
  final EstadoInventario estado;
  final DateTime? proximaCaducidad;

  const ResumenProducto({
    required this.producto,
    required this.stock,
    required this.estado,
    this.proximaCaducidad,
  });
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ProductoRepository _productoRepository = ProductoRepository();
  final LoteRepository _loteRepository = LoteRepository();

  late Future<List<ResumenProducto>> _futureProductos;

  @override
  void initState() {
    super.initState();
    _futureProductos = _cargarProductos();
  }

  Future<List<ResumenProducto>> _cargarProductos() async {
    final productos = await _productoRepository.obtenerTodos();
    final resultados = <ResumenProducto>[];

    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final limite = hoy.add(const Duration(days: 3));

    for (final producto in productos) {
      final lotes = await _loteRepository.obtenerActivosPorProducto(
        producto.id!,
      );

      final stock = lotes.fold<int>(
        0,
        (total, lote) => total + lote.cantidad,
      );

      final caducados = lotes.where(
        (lote) => lote.fechaCaducidad.isBefore(hoy),
      );

      final proximos = lotes.where((lote) {
        return !lote.fechaCaducidad.isBefore(hoy) &&
            !lote.fechaCaducidad.isAfter(limite);
      });

      EstadoInventario estado;

      if (stock == 0) {
        estado = EstadoInventario.agotado;
      } else if (caducados.isNotEmpty) {
        estado = EstadoInventario.caducado;
      } else if (proximos.isNotEmpty) {
        estado = EstadoInventario.porCaducar;
      } else if (stock <= producto.stockMinimo) {
        estado = EstadoInventario.porAgotarse;
      } else {
        estado = EstadoInventario.disponible;
      }

      resultados.add(
        ResumenProducto(
          producto: producto,
          stock: stock,
          estado: estado,
          proximaCaducidad: _primeraCaducidad(lotes),
        ),
      );
    }

    const prioridad = {
      EstadoInventario.caducado: 0,
      EstadoInventario.agotado: 1,
      EstadoInventario.porCaducar: 2,
      EstadoInventario.porAgotarse: 3,
      EstadoInventario.disponible: 4,
    };

    resultados.sort((a, b) {
      final diferencia =
          prioridad[a.estado]!.compareTo(prioridad[b.estado]!);

      if (diferencia != 0) return diferencia;

      return a.producto.nombre.toLowerCase().compareTo(
        b.producto.nombre.toLowerCase(),
      );
    });

    return resultados;
  }

  DateTime? _primeraCaducidad(List<Lote> lotes) {
    if (lotes.isEmpty) return null;

    final fechas = lotes.map((lote) => lote.fechaCaducidad).toList()
      ..sort();

    return fechas.first;
  }

  Future<void> _actualizar() async {
    final consulta = _cargarProductos();

    setState(() {
      _futureProductos = consulta;
    });

    await consulta;
  }

  // Abrir pantalla para registrar un nuevo producto.
  Future<void> _abrirNuevoProducto() async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const ProductFormScreen(),
      ),
    );

    if (!mounted) return;

    if (guardado == true) {
      await _actualizar();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto registrado correctamente'),
        ),
      );
    }
  }

  // Abrir administración de categorías.
  Future<void> _abrirCategorias() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => const CategoriesScreen(),
      ),
    );

    if (!mounted) return;

    // Recargamos porque los nombres o relaciones
    // de categorías pudieron modificarse.
    await _actualizar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirNuevoProducto,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo producto'),
      ),
      body: RefreshIndicator(
        onRefresh: _actualizar,
        child: FutureBuilder<List<ResumenProducto>>(
          future: _futureProductos,
          builder: (context, snapshot) {
            final productos = snapshot.data ?? [];
            final cargando =
                snapshot.connectionState == ConnectionState.waiting;

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  floating: true,
                  expandedHeight: 115,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.category_outlined),
                      tooltip: 'Administrar categorías',
                      onPressed: _abrirCategorias,
                    ),
                    const SizedBox(width: 8),
                  ],
                  flexibleSpace: const FlexibleSpaceBar(
                    titlePadding: EdgeInsets.only(
                      left: 20,
                      bottom: 16,
                    ),
                    title: Text(
                      'Mi alacena',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: _resumenGeneral(productos),
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Mis productos',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (cargando)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    child: _mensaje(
                      Icons.error_outline,
                      'No se pudo cargar el inventario',
                      'Comprueba que la base de datos esté disponible.',
                      error: snapshot.error.toString(),
                      permitirReintentar: true,
                    ),
                  )
                else if (productos.isEmpty)
                  SliverFillRemaining(
                    child: _mensaje(
                      Icons.inventory_2_outlined,
                      'Tu alacena está vacía',
                      'Presiona "Nuevo producto" para comenzar '
                          'a organizar tu alacena.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      110,
                    ),
                    sliver: SliverList.builder(
                      itemCount: productos.length,
                      itemBuilder: (context, index) {
                        return _tarjetaProducto(productos[index]);
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _resumenGeneral(List<ResumenProducto> productos) {
    final alertas = productos.where(
      (producto) => producto.estado != EstadoInventario.disponible,
    ).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F1E5),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.kitchen_outlined,
              color: Color(0xFF51865D),
              size: 29,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumen de tu alacena',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${productos.length} productos registrados',
                ),
                Text(
                  '$alertas productos con alertas',
                  style: const TextStyle(
                    color: Color(0xFF9A5B1C),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaProducto(ResumenProducto resumen) {
    final producto = resumen.producto;
    final color = _colorEstado(resumen.estado);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                width: 76,
                height: 76,
                child: _imagenProducto(producto.imagenPath),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text('Existencias: ${resumen.stock}'),
                  if (resumen.proximaCaducidad != null)
                    Text(
                      'Caducidad: '
                      '${_fechaVisible(resumen.proximaCaducidad!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _nombreEstado(resumen.estado),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagenProducto(String? ruta) {
    if (ruta == null || ruta.isEmpty) {
      return _imagenPredeterminada();
    }

    return Image.file(
      File(ruta),
      fit: BoxFit.cover,
      errorBuilder: (_, error, stackTrace) {
        return _imagenPredeterminada();
      },
    );
  }

  Widget _imagenPredeterminada() {
    return Container(
      color: const Color(0xFFF0F3EA),
      child: const Icon(
        Icons.inventory_2_outlined,
        color: Color(0xFF51865D),
        size: 31,
      ),
    );
  }

  Widget _mensaje(
    IconData icono,
    String titulo,
    String descripcion, {
    String? error,
    bool permitirReintentar = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 65,
              color: const Color(0xFF80A58A),
            ),
            const SizedBox(height: 15),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              descripcion,
              textAlign: TextAlign.center,
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
            if (permitirReintentar) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _actualizar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _colorEstado(EstadoInventario estado) {
    return switch (estado) {
      EstadoInventario.caducado => const Color(0xFFC0392B),
      EstadoInventario.agotado => const Color(0xFF8E4444),
      EstadoInventario.porCaducar => const Color(0xFFCA7C16),
      EstadoInventario.porAgotarse => const Color(0xFFB08A26),
      EstadoInventario.disponible => const Color(0xFF438454),
    };
  }

  String _nombreEstado(EstadoInventario estado) {
    return switch (estado) {
      EstadoInventario.caducado => 'Caducado',
      EstadoInventario.agotado => 'Agotado',
      EstadoInventario.porCaducar => 'Por caducar',
      EstadoInventario.porAgotarse => 'Por agotarse',
      EstadoInventario.disponible => 'Disponible',
    };
  }

  String _fechaVisible(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');

    return '$dia/$mes/${fecha.year}';
  }
}
