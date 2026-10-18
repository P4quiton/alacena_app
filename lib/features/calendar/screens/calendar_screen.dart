import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../data/models/lote.dart';
import '../../../data/models/producto.dart';
import '../../../data/repositories/lote_repository.dart';
import '../../../data/repositories/producto_repository.dart';
import 'dart:io';

class _EventoCaducidad {
  final Producto producto;
  final Lote lote;

  const _EventoCaducidad({required this.producto, required this.lote});
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final ProductoRepository _productoRepository = ProductoRepository();
  final LoteRepository _loteRepository = LoteRepository();

  Map<DateTime, List<_EventoCaducidad>> _eventos = {};
  bool _cargando = true;
  String? _error;

  DateTime _diaEnfocado = DateTime.now();
  DateTime? _diaSeleccionado;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // Deja solo año, mes y día, para poder usar la fecha como llave.
  DateTime _soloFecha(DateTime fecha) {
    return DateTime(fecha.year, fecha.month, fecha.day);
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final productos = await _productoRepository.obtenerTodos();
      final eventos = <DateTime, List<_EventoCaducidad>>{};

      for (final producto in productos) {
        final lotes = await _loteRepository.obtenerActivosPorProducto(
          producto.id!,
        );

        for (final lote in lotes) {
          final dia = _soloFecha(lote.fechaCaducidad);

          eventos
              .putIfAbsent(dia, () => [])
              .add(_EventoCaducidad(producto: producto, lote: lote));
        }
      }

      if (!mounted) return;

      setState(() {
        _eventos = eventos;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _cargando = false;
        _error = 'No se pudo cargar el calendario.';
      });
    }
  }

  List<_EventoCaducidad> _eventosDelDia(DateTime dia) {
    return _eventos[_soloFecha(dia)] ?? const [];
  }

  void _abrirListadoDelDia(DateTime dia, List<_EventoCaducidad> eventos) {
    showDialog<void>(
      context: context,
      builder: (_) => _ListadoDelDia(dia: dia, eventos: eventos),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario de caducidades')),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(_error!),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final seleccionado = _diaSeleccionado;
    final cantidadSeleccionado = seleccionado == null
        ? 0
        : _eventosDelDia(seleccionado).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TableCalendar<_EventoCaducidad>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2100, 12, 31),
              focusedDay: _diaEnfocado,
              startingDayOfWeek: StartingDayOfWeek.monday,
              selectedDayPredicate: (dia) {
                return _diaSeleccionado != null &&
                    isSameDay(_diaSeleccionado, dia);
              },
              eventLoader: _eventosDelDia,
              onDaySelected: (seleccionado, enfocado) {
                setState(() {
                  _diaSeleccionado = seleccionado;
                  _diaEnfocado = enfocado;
                });
                final eventos = _eventosDelDia(seleccionado);
                if (eventos.isNotEmpty) {
                  _abrirListadoDelDia(seleccionado, eventos);
                }
              },
              onPageChanged: (enfocado) {
                _diaEnfocado = enfocado;
              },
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              calendarStyle: const CalendarStyle(
                markersMaxCount: 6,
                markerSize: 6,
                markerDecoration: BoxDecoration(
                  color: Color(0xFFC0392B),
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Color(0xFF80A58A),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Color(0xFF51865D),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Cada punto es un producto que caduca ese día.',
          textAlign: TextAlign.center,
        ),
        if (seleccionado != null) ...[
          const SizedBox(height: 8),
          Text(
            cantidadSeleccionado == 0
                ? 'No hay productos que caduquen ese día.'
                : '$cantidadSeleccionado producto(s) caducan ese día.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }
}

class _ListadoDelDia extends StatelessWidget {
  final DateTime dia;
  final List<_EventoCaducidad> eventos;

  const _ListadoDelDia({required this.dia, required this.eventos});

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
          title: Text('Caducan el ${_fechaVisible(dia)}'),
        ),
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList.builder(
                itemCount: eventos.length,
                itemBuilder: (context, index) => _tarjeta(eventos[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta(_EventoCaducidad evento) {
    final (texto, color) = _estadoDelLote(evento.lote.fechaCaducidad);

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
                child: _imagen(evento.producto.imagenPath),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    evento.producto.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Cantidad en el lote: ${evento.lote.cantidad}'),
                  Text('Caduca: ${_fechaVisible(evento.lote.fechaCaducidad)}'),
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
                    child: Text(
                      texto,
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

// Estado del lote según su fecha de caducidad.
(String, Color) _estadoDelLote(DateTime caducidad) {
  final ahora = DateTime.now();
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final dia = DateTime(caducidad.year, caducidad.month, caducidad.day);

  if (dia.isBefore(hoy)) {
    return ('Caducado', const Color(0xFFC0392B));
  }

  if (!dia.isAfter(hoy.add(const Duration(days: 3)))) {
    return ('Por caducar', const Color(0xFFCA7C16));
  }

  return ('Vigente', const Color(0xFF438454));
}

String _fechaVisible(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');

  return '$dia/$mes/${fecha.year}';
}