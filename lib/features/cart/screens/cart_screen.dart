import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/models/producto.dart';
import '../../../data/repositories/carrito_repository.dart';
import '../../../data/repositories/producto_repository.dart';
import '../../purchases/screens/purchase_form_screen.dart';

class _ItemCarrito {
  final Producto producto;
  int cantidad;

  _ItemCarrito({required this.producto, required this.cantidad});
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CarritoRepository _carritoRepository = CarritoRepository();
  final ProductoRepository _productoRepository = ProductoRepository();

  List<_ItemCarrito> _items = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final detalles = await _carritoRepository.obtenerDetalles();
      final items = <_ItemCarrito>[];

      for (final detalle in detalles) {
        final producto = await _productoRepository.obtenerPorId(
          detalle.productoId,
        );

        if (producto != null) {
          items.add(
            _ItemCarrito(producto: producto, cantidad: detalle.cantidad),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _items = items;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _cargando = false;
        _error = 'No se pudo cargar el carrito.';
      });
    }
  }

  void _mensaje(String texto) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto)),
    );
  }

  Future<void> _cambiarCantidad(_ItemCarrito item, int nueva) async {
    if (nueva < 1) return;

    final anterior = item.cantidad;
    setState(() => item.cantidad = nueva);

    try {
      await _carritoRepository.actualizarCantidad(item.producto.id!, nueva);
    } catch (_) {
      if (!mounted) return;

      setState(() => item.cantidad = anterior);
      _mensaje('No se pudo actualizar la cantidad.');
    }
  }

  // Se llama cuando el usuario desliza un producto para quitarlo.
  Future<void> _quitar(_ItemCarrito item) async {
    setState(() => _items.remove(item));

    try {
      await _carritoRepository.eliminarProducto(item.producto.id!);
      _mensaje('${item.producto.nombre} quitado del carrito');
    } catch (_) {
      _mensaje('No se pudo quitar el producto.');
      await _cargar();
    }
  }

  Future<void> _registrarCompra(_ItemCarrito item) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PurchaseFormScreen(productoId: item.producto.id),
      ),
    );
    if (guardado != true || !mounted) return;
    try {
      await _carritoRepository.eliminarProducto(item.producto.id!);
      if (!mounted) return;
      setState(() => _items.remove(item));
      _mensaje('Compra registrada: ${item.producto.nombre} salió de tu lista');
    } catch (_) {
      _mensaje('La compra se registró, pero no se pudo quitar del carrito.');
      await _cargar();
    }
  }

  Future<void> _vaciar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Vaciar carrito'),
          content: const Text(
            '¿Quitar todos los productos de tu lista de compras?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Vaciar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    try {
      await _carritoRepository.vaciarCarrito();
      if (!mounted) return;

      setState(() => _items = []);
    } catch (_) {
      _mensaje('No se pudo vaciar el carrito.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de compras'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              tooltip: 'Vaciar carrito',
              onPressed: _vaciar,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _mensajeCentral(
        Icons.error_outline,
        _error!,
        reintentar: true,
      );
    }

    if (_items.isEmpty) {
      return _mensajeCentral(
        Icons.shopping_cart_outlined,
        'Tu carrito está vacío.\n'
        'Agrega productos desde el inventario.',
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          sliver: SliverList.builder(
            itemCount: _items.length,
            itemBuilder: (context, index) => _tarjeta(_items[index]),
          ),
        ),
      ],
    );
  }

  Widget _tarjeta(_ItemCarrito item) {
    return Dismissible(
      key: ValueKey(item.producto.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _quitar(item),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: const Color(0xFFC0392B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: _imagen(item.producto.imagenPath),
                ),
              ),
              const SizedBox(width: 12),
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
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Quitar una unidad',
                          onPressed: item.cantidad > 1
                              ? () => _cambiarCantidad(item, item.cantidad - 1)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '${item.cantidad}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Agregar una unidad',
                          onPressed: () =>
                              _cambiarCantidad(item, item.cantidad + 1),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _registrarCompra(item),
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text('Ya lo compré'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
        size: 28,
      ),
    );
  }

  Widget _mensajeCentral(
    IconData icono,
    String texto, {
    bool reintentar = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 64, color: const Color(0xFF80A58A)),
            const SizedBox(height: 14),
            Text(texto, textAlign: TextAlign.center),
            if (reintentar) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}