
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/models/categoria.dart';
import '../../../data/models/producto.dart';
import '../../../data/repositories/categoria_repository.dart';
import '../../../data/repositories/producto_repository.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _stockMinimoController = TextEditingController(text: '1');

  final _categoriaRepository = CategoriaRepository();
  final _productoRepository = ProductoRepository();
  final _imagePicker = ImagePicker();

  late Future<List<Categoria>> _categoriasFuture;

  int? _categoriaSeleccionada;
  XFile? _imagenSeleccionada;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _categoriasFuture = _categoriaRepository.obtenerTodas();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _stockMinimoController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    try {
      final imagen = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (imagen != null && mounted) {
        setState(() => _imagenSeleccionada = imagen);
      }
    } catch (_) {
      if (!mounted) return;
      _mostrarMensaje('No se pudo seleccionar la imagen.');
    }
  }

  Future<String?> _guardarImagenLocal() async {
    if (_imagenSeleccionada == null) return null;

    final directorio = await getApplicationDocumentsDirectory();
    final carpeta = Directory(p.join(directorio.path, 'productos'));

    if (!await carpeta.exists()) {
      await carpeta.create(recursive: true);
    }

    final extension = p.extension(_imagenSeleccionada!.path);
    final nombre = 'producto_${DateTime.now().microsecondsSinceEpoch}'
        '$extension';

    final destino = p.join(carpeta.path, nombre);

    await File(_imagenSeleccionada!.path).copy(destino);

    return destino;
  }

  Future<void> _guardarProducto() async {
    if (_guardando || !_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    String? imagenGuardada;

    try {
      imagenGuardada = await _guardarImagenLocal();

      final producto = Producto(
        categoriaId: _categoriaSeleccionada!,
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        imagenPath: imagenGuardada,
        stockMinimo: int.parse(_stockMinimoController.text.trim()),
      );

      await _productoRepository.insertar(producto);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      // Si SQLite falla, no dejamos una imagen huérfana.
      if (imagenGuardada != null) {
        try {
          final archivo = File(imagenGuardada);
          if (await archivo.exists()) {
            await archivo.delete();
          }
        } catch (_) {
          // La limpieza no debe ocultar el error original.
        }
      }

      if (!mounted) return;
      _mostrarMensaje('No se pudo guardar el producto.');
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo producto')),
      body: FutureBuilder<List<Categoria>>(
        future: _categoriasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No se pudieron cargar las categorías.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _categoriasFuture =
                            _categoriaRepository.obtenerTodas();
                      });
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final categorias = snapshot.data ?? [];

          if (categorias.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.category_outlined, size: 60),
                    const SizedBox(height: 16),
                    const Text(
                      'Primero registra una categoría.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Regresar'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Form(
            key: _formKey,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      GestureDetector(
                        onTap: _guardando ? null : _seleccionarImagen,
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F1E5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _imagenSeleccionada == null
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_outlined,
                                      size: 42,
                                      color: Color(0xFF51865D),
                                    ),
                                    SizedBox(height: 8),
                                    Text('Seleccionar imagen'),
                                  ],
                                )
                              : Image.file(
                                  File(_imagenSeleccionada!.path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error, stack) =>
                                      const Center(
                                    child: Text(
                                      'No se pudo mostrar la imagen',
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nombreController,
                        maxLength: 80,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del producto',
                          hintText: 'Ej. Leche entera',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                        validator: (valor) {
                          if (valor == null || valor.trim().isEmpty) {
                            return 'Ingresa el nombre del producto';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _categoriaSeleccionada,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: categorias.map((categoria) {
                          return DropdownMenuItem<int>(
                            value: categoria.id,
                            child: Text(categoria.nombre),
                          );
                        }).toList(),
                        onChanged: _guardando
                            ? null
                            : (valor) {
                                setState(() {
                                  _categoriaSeleccionada = valor;
                                });
                              },
                        validator: (valor) {
                          if (valor == null) {
                            return 'Selecciona una categoría';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _descripcionController,
                        maxLength: 250,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descripción (opcional)',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _stockMinimoController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock mínimo',
                          helperText:
                              'Cantidad a partir de la cual se mostrará '
                              'una alerta de agotamiento.',
                          prefixIcon: Icon(Icons.production_quantity_limits),
                        ),
                        validator: (valor) {
                          final numero = int.tryParse(valor?.trim() ?? '');
                          if (numero == null || numero < 0) {
                            return 'Ingresa un número entero mayor o igual a 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _guardando ? null : _guardarProducto,
                          icon: const Icon(Icons.save_outlined),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              _guardando
                                  ? 'Guardando...'
                                  : 'Guardar producto',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
