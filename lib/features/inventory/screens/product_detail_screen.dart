import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/models/categoria.dart';
import '../../../data/models/lote.dart';
import '../../../data/models/producto.dart';
import '../../../data/repositories/categoria_repository.dart';
import '../../../data/repositories/lote_repository.dart';
import '../../../data/repositories/producto_repository.dart';

class _DetalleProducto {
  final Producto producto;
  final Categoria? categoria;
  final List<Lote> lotes;

  const _DetalleProducto({
    required this.producto,
    required this.categoria,
    required this.lotes,
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
    final lotes = await _loteRepository.obtenerActivosPorProducto(
      widget.productoId,
    );

    return _DetalleProducto(
      producto: producto,
      categoria: categoria,
      lotes: lotes,
    );
  }

  void _recargar() {
    setState(() {
      _futureDetalle = _cargar();
    });
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
      appBar: AppBar(title: const Text('Detalle del producto')),
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
        trailing: Container(
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
