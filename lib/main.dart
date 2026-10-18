import 'package:flutter/material.dart';

import 'core/notifications/notification_service.dart';
import 'features/alarms/screens/caducan_hoy_screen.dart';
import 'features/inventory/screens/inventory_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void _abrirCaducanHoy() {
  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (_) => const CaducanHoyScreen()),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final abrirHoy = await NotificationService.instance.inicializar(
    alTocarNotificacion: _abrirCaducanHoy,
  );

  runApp(const MyApp());

  // Si la app se abrió desde la notificación, mostrar la pantalla.
  if (abrirHoy) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _abrirCaducanHoy());
  }

  NotificationService.instance.pedirPermisos();

}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const verdePrincipal = Color(0xFF51865D);

    return MaterialApp(
      title: 'Alacena App',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: verdePrincipal,
          brightness: Brightness.light,
          surface: const Color(0xFFF9F8F3),
        ),
        scaffoldBackgroundColor: const Color(0xFFF9F8F3),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF9F8F3),
          foregroundColor: Color(0xFF26392B),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const InventoryScreen(),
    );
  }
}