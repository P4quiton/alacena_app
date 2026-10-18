import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/repositories/lote_repository.dart';
import '../../data/repositories/producto_repository.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String payloadCaducanHoy = 'caducan_hoy';

  // Hora a la que suena la alarma el día que caduca el producto.
  static const int _hora = 8;
  static const int _minuto = 0;

  // Solo se programan las alarmas de los próximos días.
  static const int _diasAProgramar = 60;

  static const NotificationDetails _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'caducidades',
      'Caducidades',
      channelDescription: 'Avisos de productos que caducan hoy',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final ProductoRepository _productoRepository = ProductoRepository();
  final LoteRepository _loteRepository = LoteRepository();

  /// Devuelve true si la app se abrió tocando una notificación.
  Future<bool> inicializar({
    required void Function() alTocarNotificacion,
  }) async {
    try {
      tzdata.initializeTimeZones();

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (respuesta) {
          if (respuesta.payload == payloadCaducanHoy) {
            alTocarNotificacion();
          }
        },
      );

      final detalles = await _plugin.getNotificationAppLaunchDetails();

      return detalles?.didNotificationLaunchApp == true &&
          detalles?.notificationResponse?.payload == payloadCaducanHoy;
    } catch (e) {
      debugPrint('Notificaciones: no se pudo inicializar ($e)');
      return false;
    }
  }

  Future<void> pedirPermisos() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Notificaciones: no se pudo pedir permiso ($e)');
    }
  }

  /// Borra las alarmas anteriores y programa una por cada día en que
  /// caduca algún lote activo con alerta encendida.
  Future<void> reprogramar() async {
    try {
      debugPrint('Notificaciones: reprogramando...');
      await _plugin.cancelAll();

      final ahora = DateTime.now();
      final hoy = DateTime(ahora.year, ahora.month, ahora.day);
      final limite = hoy.add(const Duration(days: _diasAProgramar));

      final productos = await _productoRepository.obtenerTodos();
      final nombresPorDia = <DateTime, List<String>>{};

      for (final producto in productos) {
        final lotes = await _loteRepository.obtenerActivosPorProducto(
          producto.id!,
        );

        for (final lote in lotes) {
          if (!lote.alertaActiva) continue;

          final dia = DateTime(
            lote.fechaCaducidad.year,
            lote.fechaCaducidad.month,
            lote.fechaCaducidad.day,
          );

          if (dia.isBefore(hoy) || dia.isAfter(limite)) continue;

          nombresPorDia.putIfAbsent(dia, () => []).add(producto.nombre);
        }
      }

      for (final entrada in nombresPorDia.entries) {
        final dia = entrada.key;
        final momento = DateTime(dia.year, dia.month, dia.day, _hora, _minuto);

        // Si la hora de ese día ya pasó, no se programa.
        if (!momento.isAfter(DateTime.now())) {
          debugPrint('Notificaciones: se omite $dia, la hora $momento ya pasó');
          continue;
        }

        await _plugin.zonedSchedule(
          id: dia.year * 10000 + dia.month * 100 + dia.day,
          title: '${entrada.value.length} producto(s) caducan hoy',
          body: entrada.value.join(', '),
          scheduledDate: tz.TZDateTime.from(momento, tz.UTC),
          notificationDetails: _detalles,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payloadCaducanHoy,
        );
      }

      final pendientes = await _plugin.pendingNotificationRequests();
      debugPrint(
        'Notificaciones: ${nombresPorDia.length} día(s) con lotes, '
        '${pendientes.length} alarma(s) pendiente(s)',
      );
    } catch (e) {
      debugPrint('Notificaciones: no se pudieron programar ($e)');
    }
  }
}