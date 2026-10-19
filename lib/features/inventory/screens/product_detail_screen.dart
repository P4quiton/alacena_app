import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/models/categoria.dart';
import '../../../data/models/lote.dart';
import '../../../data/models/producto.dart';
import '../../../data/repositories/categoria_repository.dart';
import '../../../data/repositories/lote_repository.dart';
import '../../../data/repositories/producto_repository.dart';
import '../../../data/repositories/carrito_repository.dart';
import '../../../data/models/historial_compra.dart';
import '../../../data/models/tienda.dart';
import '../../../data/repositories/historial_compra_repository.dart';
import 'product_form_screen.dart';
import 'package:sqflite/sqflite.dart';

class _DetalleProducto {
  final Producto producto;
  final Categoria? categoria;
  final List<Lote> lotes;
  final List<Tienda> tiendas;
  final List<HistorialCompra> compras;

  const _DetalleProducto({
    required this.producto,
    required this.categoria,
    required this.lotes,
    required this.tiendas,
    required this.compras,
  });
}

class ProductDetailScreen extends StatefulWidget {
  final int productoId;

  const ProductDetailScreen({super.key, required this.productoId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ProductoRepository _productoRepository = ProductoRepository();
  final CategoriaRepository _categoriaRepository = CategoriaRepository();
  final LoteRepository _loteRepository = LoteRepository();
  final HistorialCompraRepository _historialRepository = HistorialCompraRepository();
  final CarritoRepository _carritoRepository = CarritoRepository();

  late Future<_DetalleProducto> _futureDetalle;

  @override
  void initState() {
    super.initState();
    _futureDetalle = _cargar();
  }

  Future<_DetalleProducto> _cargar() async {
    final producto = await _productoRepository.obtenerPorId(widget.productoId);

    if (producto == null) {
      throw StateError('El producto ya no existe.');
    }

    final categoria = await _categoriaRepository.obtenerPorId(
      producto.categoriaId,
    );
        final lotes =
        await _loteRepository.obtenerActivosPorProducto(widget.productoId);
    final tiendas = await _historialRepository.obtenerTiendasPorProducto(
      widget.productoId,
    );
    final compras = await _historialRepository.obtenerPorProducto(
      widget.productoId,
    );

    return _DetalleProducto(
      producto: producto,
      categoria: categoria,
      lotes: lotes,
      tiendas: tiendas,
      compras: compras,
    );
  }

  void _recargar() {
    setState(() {
      _futureDetalle = _cargar();
    });
  }

  Future<void> _editar() async {
    try {
      final detalle = await _futureDetalle;
      if (!mounted) return;

      final guardado = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ProductFormScreen(producto: detalle.producto),
        ),
      );

      if (guardado == true && mounted) {
        _recargar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto actualizado')),
        );
      }
    } catch (_) {
      // Si el producto no se pudo cargar, no hay nada que editar.
    }
  }

    Future<void> _eliminar() async {
    try {
      final detalle = await _futureDetalle;
      if (!mounted) return;

      final producto = detalle.producto;

      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Eliminar producto'),
            content: Text(
              '¿Deseas eliminar "${producto.nombre}"? '
              'Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          );
        },
      );

      if (confirmar != true || !mounted) return;

      // Integridad referencial: con lotes hay compras en el historial.
      final lotes = await _loteRepository.obtenerTodos();
      final tieneLotes = lotes.any((lote) => lote.productoId == producto.id);

      if (tieneLotes) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se puede eliminar: el producto ya tiene compras '
              'registradas y se conserva su historial.',
            ),
          ),
        );
        return;
      }

      // Si estaba en el carrito, se quita antes de eliminarlo.
      await _carritoRepository.eliminarProducto(producto.id!);
      await _productoRepository.eliminar(producto.id!);

      // Borrar la foto para no dejar archivos huérfanos.
      final ruta = producto.imagenPath;
      if (ruta != null && ruta.isNotEmpty) {
        try {
          final archivo = File(ruta);
          if (await archivo.exists()) await archivo.delete();
        } catch (_) {
          // El producto ya se eliminó; la foto sobrante no es grave.
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${producto.nombre} eliminado')),
      );
      Navigator.of(context).pop();
    } on DatabaseException {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se puede eliminar: el producto tiene registros asociados.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocurrió un error al eliminar.')),
      );
    }
  }

  // Consumir unidades usando FEFO (primero el lote que caduca antes).
  Future<void> _consumir(int disponible) async {
    final cantidad = await showDialog<int>(
      context: context,
      builder: (_) => _ConsumirDialog(maximo: disponible),
    );

    if (cantidad == null || !mounted) return;

    try {
      await _loteRepository.consumirProducto(widget.productoId, cantidad);
      if (!mounted) return;

      _recargar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se consumieron $cantidad unidad(es)')),
      );
    } on StateError catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocurrió un error al consumir.')),
      );
    }
  }


  Future<void> _descartarLote(Lote lote) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Descartar lote'),
          content: Text(
            'Se descartarán ${lote.cantidad} unidad(es) de este lote. '
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    try {
      await _loteRepository.actualizar(lote.copyWith(cantidad: 0));
      if (!mounted) return;

      _recargar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lote descartado')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo descartar el lote.')),
      );
    }
  }

  DateTime get _hoy {
    final ahora = DateTime.now();
    return DateTime(ahora.year, ahora.month, ahora.day);
  }

  bool _estaCaducado(Lote lote) => lote.fechaCaducidad.isBefore(_hoy);

  bool _porCaducar(Lote lote) {
    final limite = _hoy.add(const Duration(days: 3));
    return !_estaCaducado(lote) && !lote.fechaCaducidad.isAfter(limite);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del producto'),
        actions: [
          IconButton(
            tooltip: 'Editar producto',
            onPressed: _editar,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Eliminar producto',
            onPressed: _eliminar,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: FutureBuilder<_DetalleProducto>(
        future: _futureDetalle,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar el producto.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return _contenido(snapshot.data!);
        },
      ),
    );
  }

  Widget _contenido(_DetalleProducto detalle) {
    final producto = detalle.producto;
    final lotes = detalle.lotes;

    final stockTotal = lotes.fold<int>(0, (t, l) => t + l.cantidad);
    final stockDisponible = lotes
        .where((l) => !_estaCaducado(l))
        .fold<int>(0, (t, l) => t + l.cantidad);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: _imagen(producto.imagenPath),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  producto.nombre,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detalle.categoria?.nombre ?? 'Sin categoría',
                  style: const TextStyle(color: Color(0xFF51865D)),
                ),
                if (producto.descripcion != null &&
                    producto.descripcion!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(producto.descripcion!),
                ],
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stock total: $stockTotal'),
                        Text('Disponible (sin caducados): $stockDisponible'),
                        Text('Stock mínimo: ${producto.stockMinimo}'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: stockDisponible > 0
                              ? () => _consumir(stockDisponible)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                          label: const Text('Consumir'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Lotes (el primero se consume primero)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        if (lotes.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Este producto no tiene lotes.')),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList.builder(
              itemCount: lotes.length,
              itemBuilder: (context, index) => _tarjetaLote(lotes[index]),
            ),
          ),
                SliverToBoxAdapter(child: _encabezadoHistorial(detalle)),
        if (detalle.compras.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Text('Todavía no hay compras registradas.'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList.builder(
              itemCount: detalle.compras.length,
              itemBuilder: (context, index) {
                return _tarjetaCompra(
                  detalle.compras[index],
                  detalle.tiendas,
                );
              },
            ),
          ),
      ],
    );
  }

    Widget _tarjetaLote(Lote lote) {
    final (texto, color) = _estaCaducado(lote)
        ? ('Caducado', const Color(0xFFC0392B))
        : _porCaducar(lote)
        ? ('Por caducar', const Color(0xFFCA7C16))
        : ('Vigente', const Color(0xFF438454));

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(Icons.inventory_outlined, color: color),
        title: Text('Cantidad: ${lote.cantidad}'),
        subtitle: Text('Caduca: ${_fecha(lote.fechaCaducidad)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                texto,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Descartar lote',
              onPressed: () => _descartarLote(lote),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

    Widget _encabezadoHistorial(_DetalleProducto detalle) {
    final ultimaId = detalle.producto.ultimaTiendaId;
    final ultima = detalle.tiendas.where((t) => t.id == ultimaId).firstOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Historial de compras',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Última tienda: ${ultima?.nombre ?? 'Sin compras registradas'}'),
          if (detalle.tiendas.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Tiendas donde se ha comprado:'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: detalle.tiendas.map((tienda) {
                return Chip(
                  avatar: const Icon(Icons.store_outlined, size: 18),
                  label: Text(tienda.nombre),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _tarjetaCompra(HistorialCompra compra, List<Tienda> tiendas) {
    final tienda = tiendas.where((t) => t.id == compra.tiendaId).firstOrNull;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(
          Icons.receipt_long_outlined,
          color: Color(0xFF51865D),
        ),
        title: Text(
          '${compra.cantidad} unidad(es) en ${tienda?.nombre ?? 'tienda'}',
        ),
        subtitle: Text(
          '${_fecha(compra.fechaCompra)} · '
          '\$${compra.precioUnitario.toStringAsFixed(2)} c/u',
        ),
      ),
    );
  }

  Widget _imagen(String? ruta) {
    if (ruta == null || ruta.isEmpty) return _imagenPredeterminada();

    return Image.file(
      File(ruta),
      fit: BoxFit.cover,
      errorBuilder: (_, error, stackTrace) => _imagenPredeterminada(),
    );
  }

  Widget _imagenPredeterminada() {
    return Container(
      color: const Color(0xFFF0F3EA),
      child: const Icon(
        Icons.inventory_2_outlined,
        color: Color(0xFF51865D),
        size: 48,
      ),
    );
  }

  String _fecha(DateTime f) {
    final d = f.day.toString().padLeft(2, '0');
    final m = f.month.toString().padLeft(2, '0');
    return '$d/$m/${f.year}';
  }
}

class _ConsumirDialog extends StatefulWidget {
  final int maximo;

  const _ConsumirDialog({required this.maximo});

  @override
  State<_ConsumirDialog> createState() => _ConsumirDialogState();
}

class _ConsumirDialogState extends State<_ConsumirDialog> {
  int _cantidad = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Consumir unidades'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Disponibles: ${widget.maximo}'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _cantidad > 1
                    ? () => setState(() => _cantidad--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$_cantidad',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: _cantidad < widget.maximo
                    ? () => setState(() => _cantidad++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _cantidad),
          child: const Text('Consumir'),
        ),
      ],
    );
  }
}
