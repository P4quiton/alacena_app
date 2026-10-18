import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../../data/models/categoria.dart';
import '../../../data/repositories/categoria_repository.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final CategoriaRepository _repository = CategoriaRepository();

  late Future<List<Categoria>> _categorias;

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
  }

  void _cargarCategorias() {
    setState(() {
      _categorias = _repository.obtenerTodas();
    });
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _mostrarFormulario({Categoria? categoria}) async {
    final nombreController = TextEditingController(
      text: categoria?.nombre ?? '',
    );

    final descripcionController = TextEditingController(
      text: categoria?.descripcion ?? '',
    );

    final formKey = GlobalKey<FormState>();
    final esEdicion = categoria != null;

    try {
      final guardado = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (modalContext) {
          bool guardando = false;

          return StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          esEdicion ? 'Editar categoría' : 'Nueva categoría',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: nombreController,
                          maxLength: 60,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            hintText: 'Ej. Lácteos',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          validator: (valor) {
                            if (valor == null || valor.trim().isEmpty) {
                              return 'Ingresa el nombre';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descripcionController,
                          maxLines: 3,
                          maxLength: 200,
                          decoration: const InputDecoration(
                            labelText: 'Descripción (opcional)',
                            hintText: 'Ej. Leche, queso y yogur',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: guardando
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }

                                    setModalState(() {
                                      guardando = true;
                                    });

                                    final datos = Categoria(
                                      id: categoria?.id,
                                      nombre: nombreController.text.trim(),
                                      descripcion: descripcionController.text
                                          .trim(),
                                    );

                                    try {
                                      if (esEdicion) {
                                        await _repository.actualizar(datos);
                                      } else {
                                        await _repository.insertar(datos);
                                      }

                                      if (modalContext.mounted) {
                                        Navigator.of(modalContext).pop(true);
                                      }
                                    } on DatabaseException catch (e) {
                                      if (!modalContext.mounted) return;

                                      final mensaje =
                                          e.isUniqueConstraintError()
                                          ? 'Ya existe una categoría con ese nombre.'
                                          : 'No se pudo guardar la categoría.';

                                      ScaffoldMessenger.of(modalContext)
                                          .showSnackBar(
                                            SnackBar(content: Text(mensaje)),
                                          );
                                    } catch (_) {
                                      if (!modalContext.mounted) return;

                                      ScaffoldMessenger.of(modalContext)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Ocurrió un error al guardar.',
                                              ),
                                            ),
                                          );
                                    } finally {
                                      if (modalContext.mounted) {
                                        setModalState(() {
                                          guardando = false;
                                        });
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              guardando
                                  ? 'Guardando...'
                                  : esEdicion
                                  ? 'Guardar cambios'
                                  : 'Crear categoría',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      if (guardado == true && mounted) {
        _cargarCategorias();
        _mostrarMensaje(
          esEdicion
              ? 'Categoría actualizada correctamente'
              : 'Categoría creada correctamente',
        );
      }
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      nombreController.dispose();
      descripcionController.dispose();
    }
  }

  Future<void> _eliminarCategoria(Categoria categoria) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar categoría'),
          content: Text(
            '¿Deseas eliminar "${categoria.nombre}"? '
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

    if (confirmar != true) return;

    try {
      await _repository.eliminar(categoria.id!);
      if (!mounted) return;

      _cargarCategorias();
      _mostrarMensaje('Categoría eliminada');
    } on DatabaseException {
      _mostrarMensaje(
        'No se puede eliminar una categoría con productos asociados.',
      );
    } catch (_) {
      _mostrarMensaje('Ocurrió un error al eliminar la categoría.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva categoría'),
      ),
      body: FutureBuilder<List<Categoria>>(
        future: _categorias,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    const Text('No se pudieron cargar las categorías'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _cargarCategorias,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
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
                    const Icon(
                      Icons.category_outlined,
                      size: 64,
                      color: Color(0xFF51865D),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Todavía no hay categorías',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Agrega tu primera categoría para organizar '
                      'los productos de la alacena.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                sliver: SliverList.builder(
                  itemCount: categorias.length,
                  itemBuilder: (context, index) {
                    final categoria = categorias[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE7F1E5),
                          child: Icon(
                            Icons.category_outlined,
                            color: Color(0xFF51865D),
                          ),
                        ),
                        title: Text(
                          categoria.nombre,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: categoria.descripcion?.isNotEmpty == true
                            ? Text(categoria.descripcion!)
                            : null,
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Opciones',
                          onSelected: (opcion) {
                            if (opcion == 'editar') {
                              _mostrarFormulario(categoria: categoria);
                            } else if (opcion == 'eliminar') {
                              _eliminarCategoria(categoria);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'editar',
                              child: Text('Editar'),
                            ),
                            PopupMenuItem(
                              value: 'eliminar',
                              child: Text('Eliminar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
