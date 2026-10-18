import 'package:flutter/material.dart';

import 'features/inventory/screens/inventory_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const verdePrincipal = Color(0xFF51865D);

    return MaterialApp(
      title: 'Alacena App',
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
