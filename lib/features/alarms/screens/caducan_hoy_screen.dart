import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/models/lote.dart';
import '../../../data/models/producto.dart';
import '../../../data/repositories/lote_repository.dart';
import '../../../data/repositories/producto_repository.dart';

class _ItemHoy {
  final Producto producto;
  final Lote lote;

  const _ItemHoy({required this.producto, required this.lote});
}

class CaducanHoyScreen extends StatefulWidget {
  const CaducanHoyScreen({super.key});

  @override
  State<CaducanHoyScreen> createState() => _CaducanHoyScreenState();
}

class _CaducanHoyScreenState extends State<CaducanHoyScreen> {
  final ProductoRepository _productoRepository = ProductoRepository();
  final LoteRepository _loteRepository = LoteRepository();

  late Future<List<_ItemHoy>> _futureItems;

  @override
  void initState() {
    super.initState();
    _futureItems = _cargar();
  }

  Future<List<_ItemHoy>> _cargar() async {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    final productos = await _productoRepository.obtenerTodos();
    final items = <_ItemHoy>[];

    for (final producto in productos) {
      final lotes = await _loteRepository.obtenerActivosPorProducto(
        producto.id!,
      );

      for (final lote in lotes) {
        final f = lote.fechaCaducidad;

        if (DateTime(f.year, f.month, f.day) == hoy) {
          items.add(_ItemHoy(producto: producto, lote: lote));
        }
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caducan hoy')),
      body: FutureBuilder<List<_ItemHoy>>(
        future: _futureItems,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('No se pudieron cargar los productos.'),
            );
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Hoy no caduca ningún producto.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) => _tarjeta(items[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tarjeta(_ItemHoy item) {
    const color = Color(0xFFCA7C16);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: _imagen(item.producto.imagenPath),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.producto.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Cantidad en el lote: ${item.lote.cantidad}'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Caduca hoy',
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
        size: 28,
      ),
    );
  }
}