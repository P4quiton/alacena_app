
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../data/models/historial_compra.dart';
import '../../../data/models/producto.dart';
import '../../../data/models/tienda.dart';
import '../../../data/repositories/historial_compra_repository.dart';
import '../../../data/repositories/producto_repository.dart';
import '../../../data/repositories/tienda_repository.dart';
import 'stores_screen.dart';

class PurchaseFormScreen extends StatefulWidget {
  final int? productoId;

  const PurchaseFormScreen({super.key, this.productoId});

  @override
  State<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends State<PurchaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cantidadController = TextEditingController(text: '1');
  final _precioController = TextEditingController();

  final _productoRepository = ProductoRepository();
  final _tiendaRepository = TiendaRepository();
  final _compraRepository = HistorialCompraRepository();

  List<Producto> _productos = [];
  List<Tienda> _tiendas = [];

  int? _productoSeleccionado;
  int? _tiendaSeleccionada;

  late DateTime _fechaCompra;
  DateTime? _fechaCaducidad;

  bool _alertaActiva = true;
  bool _cargando = true;
  bool _guardando = false;
  String? _errorCarga;

  final _formatoFecha = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _fechaCompra = DateTime.now();
    _productoSeleccionado = widget.productoId;
    _cargarDatos();
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    try {
      final productos = await _productoRepository.obtenerTodos();
      final tiendas = await _tiendaRepository.obtenerTodas();

      if (!mounted) return;

      setState(() {
        _productos = productos;
        _tiendas = tiendas;

        if (!_productos.any((p) => p.id == _productoSeleccionado)) {
          _productoSeleccionado = null;
        }

        if (!_tiendas.any((t) => t.id == _tiendaSeleccionada)) {
          _tiendaSeleccionada = null;
        }

        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = 'No se pudieron cargar los datos.';
      });
    }
  }

  Future<void> _abrirTiendas() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const StoresScreen(),
      ),
    );

    if (!mounted) return;
    await _cargarDatos();
  }

  Future<void> _seleccionarFechaCompra() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaCompra,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Seleccionar fecha de compra',
    );

    if (fecha == null || !mounted) return;

    setState(() {
      _fechaCompra = fecha;
    });
  }

  Future<void> _seleccionarCaducidad() async {
    final hoy = DateTime.now();

    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaCaducidad ?? hoy,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Seleccionar fecha de caducidad',
    );

    if (fecha == null || !mounted) return;

    setState(() {
      _fechaCaducidad = fecha;
    });
  }

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto)),
    );
  }

  Future<void> _guardar() async {
    if (_guardando || !_formKey.currentState!.validate()) return;

    if (_fechaCaducidad == null) {
      _mensaje('Selecciona la fecha de caducidad.');
      return;
    }

    final cantidad = int.tryParse(_cantidadController.text.trim());
    final precio = double.tryParse(
      _precioController.text.trim().replaceAll(',', '.'),
    );

    if (cantidad == null ||
        cantidad <= 0 ||
        precio == null ||
        precio < 0 ||
        !precio.isFinite) {
      _mensaje('Verifica la cantidad y el precio.');
      return;
    }

    setState(() => _guardando = true);

    try {
      final compra = HistorialCompra(
        productoId: _productoSeleccionado!,
        tiendaId: _tiendaSeleccionada!,
        cantidad: cantidad,
        precioUnitario: precio,
        fechaCompra: _fechaCompra,
      );

      await _compraRepository.registrarCompra(
        compra: compra,
        fechaCaducidad: _fechaCaducidad!,
        alertaActiva: _alertaActiva,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      _mensaje('No se pudo registrar la compra.');
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  Widget _campoFecha({
    required String titulo,
    required DateTime? fecha,
    required VoidCallback onTap,
    required IconData icono,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icono, color: const Color(0xFF51865D)),
        title: Text(titulo),
        subtitle: Text(
          fecha == null ? 'Seleccionar fecha' : _formatoFecha.format(fecha),
        ),
        trailing: const Icon(Icons.calendar_month_outlined),
        onTap: _guardando ? null : onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar compra')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _errorCarga != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_errorCarga!),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _cargarDatos,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const Text(
                          'Información de la compra',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          initialValue: _productoSeleccionado,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Producto',
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                          ),
                          items: _productos.map((producto) {
                            return DropdownMenuItem(
                              value: producto.id,
                              child: Text(
                                producto.nombre,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: _guardando
                              ? null
                              : (valor) {
                                  setState(() {
                                    _productoSeleccionado = valor;
                                  });
                                },
                          validator: (valor) => valor == null
                              ? 'Selecciona un producto'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          initialValue: _tiendaSeleccionada,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Tienda',
                            prefixIcon: Icon(Icons.store_outlined),
                          ),
                          items: _tiendas.map((tienda) {
                            return DropdownMenuItem(
                              value: tienda.id,
                              child: Text(
                                tienda.nombre,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: _guardando
                              ? null
                              : (valor) {
                                  setState(() {
                                    _tiendaSeleccionada = valor;
                                  });
                                },
                          validator: (valor) =>
                              valor == null ? 'Selecciona una tienda' : null,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _guardando ? null : _abrirTiendas,
                            icon: const Icon(Icons.add_business_outlined),
                            label: const Text('Administrar tiendas'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _cantidadController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Cantidad comprada',
                            prefixIcon: Icon(
                              Icons.production_quantity_limits,
                            ),
                          ),
                          validator: (valor) {
                            final cantidad = int.tryParse(valor ?? '');
                            if (cantidad == null || cantidad <= 0) {
                              return 'Ingresa una cantidad mayor que cero';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _precioController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Precio unitario',
                            prefixText: '\$ ',
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          validator: (valor) {
                            final precio = double.tryParse(
                              (valor ?? '').trim().replaceAll(',', '.'),
                            );

                            if (precio == null ||
                                precio < 0 ||
                                !precio.isFinite) {
                              return 'Ingresa un precio válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        _campoFecha(
                          titulo: 'Fecha de compra',
                          fecha: _fechaCompra,
                          onTap: _seleccionarFechaCompra,
                          icono: Icons.shopping_bag_outlined,
                        ),
                        _campoFecha(
                          titulo: 'Fecha de caducidad',
                          fecha: _fechaCaducidad,
                          onTap: _seleccionarCaducidad,
                          icono: Icons.event_outlined,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Alertas de caducidad'),
                          subtitle: const Text(
                            'Activar avisos locales para este lote',
                          ),
                          value: _alertaActiva,
                          onChanged: _guardando
                              ? null
                              : (valor) {
                                  setState(() {
                                    _alertaActiva = valor;
                                  });
                                },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _guardando ? null : _guardar,
                            icon: const Icon(Icons.save_outlined),
                            label: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              child: Text(
                                _guardando
                                    ? 'Registrando...'
                                    : 'Registrar compra',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
