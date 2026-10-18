import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../../data/models/tienda.dart';
import '../../../data/repositories/tienda_repository.dart';

class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  final TiendaRepository _repository = TiendaRepository();

  late Future<List<Tienda>> _tiendas;

  @override
  void initState() {
    super.initState();
    _cargarTiendas();
  }

  void _cargarTiendas() {
    setState(() {
      _tiendas = _repository.obtenerTodas();
    });
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _mostrarFormulario({Tienda? tienda}) async {
    final nombreController = TextEditingController(text: tienda?.nombre ?? '');

    final direccionController = TextEditingController(
      text: tienda?.direccion ?? '',
    );

    final formKey = GlobalKey<FormState>();
    final esEdicion = tienda != null;

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
                          esEdicion ? 'Editar tienda' : 'Nueva tienda',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: nombreController,
                          maxLength: 80,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la tienda',
                            hintText: 'Ej. Soriana',
                            prefixIcon: Icon(Icons.store_outlined),
                          ),
                          validator: (valor) {
                            if (valor == null || valor.trim().isEmpty) {
                              return 'Ingresa el nombre de la tienda';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: direccionController,
                          maxLength: 200,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Dirección (opcional)',
                            hintText: 'Ej. Av. Principal 100',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                        ),
                        const SizedBox(height: 20),
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

                                    final datos = Tienda(
                                      id: tienda?.id,
                                      nombre: nombreController.text.trim(),
                                      direccion: direccionController.text
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
                                    } catch (_) {
                                      if (modalContext.mounted) {
                                        ScaffoldMessenger.of(modalContext)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'No se pudo guardar '
                                                  'la tienda.',
                                                ),
                                              ),
                                            );
                                      }
                                    } finally {
                                      if (modalContext.mounted && guardando) {
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
                                  : 'Crear tienda',
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
        _cargarTiendas();
        _mostrarMensaje(
          esEdicion
              ? 'Tienda actualizada correctamente'
              : 'Tienda registrada correctamente',
        );
      }
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      nombreController.dispose();
      direccionController.dispose();
    }
  }

  Future<void> _eliminarTienda(Tienda tienda) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar tienda'),
          content: Text(
            '¿Deseas eliminar "${tienda.nombre}"? '
            'No podrás eliminarla si tiene compras '
            'o productos asociados.',
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
      await _repository.eliminar(tienda.id!);

      if (!mounted) return;
      _cargarTiendas();
      _mostrarMensaje('Tienda eliminada correctamente');
    } on DatabaseException {
      _mostrarMensaje(
        'No se puede eliminar esta tienda porque '
        'tiene registros asociados.',
      );
    } catch (_) {
      _mostrarMensaje('Ocurrió un error al eliminar la tienda.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis tiendas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva tienda'),
      ),
      body: FutureBuilder<List<Tienda>>(
        future: _tiendas,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No se pudieron cargar las tiendas'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _cargarTiendas,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final tiendas = snapshot.data ?? [];

          if (tiendas.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 64,
                      color: Color(0xFF51865D),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Todavía no hay tiendas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Registra los establecimientos '
                      'donde compras tus productos.',
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
                  itemCount: tiendas.length,
                  itemBuilder: (context, index) {
                    final tienda = tiendas[index];

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
                            Icons.store_outlined,
                            color: Color(0xFF51865D),
                          ),
                        ),
                        title: Text(
                          tienda.nombre,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: tienda.direccion?.isNotEmpty == true
                            ? Text(tienda.direccion!)
                            : const Text('Sin dirección registrada'),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Opciones de tienda',
                          onSelected: (opcion) {
                            if (opcion == 'editar') {
                              _mostrarFormulario(tienda: tienda);
                            } else if (opcion == 'eliminar') {
                              _eliminarTienda(tienda);
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
