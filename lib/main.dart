import 'package:flutter/material.dart';
import 'screens/products_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MarketMapperApp());
}

class MarketMapperApp extends StatelessWidget {
  const MarketMapperApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF18312B);
    return MaterialApp(
      title: 'Prateleira',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D7358),
          primary: const Color(0xFF1D7358),
          surface: const Color(0xFFF8F8F3),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F8F3),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8F8F3),
          foregroundColor: ink,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE3E8E2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE3E8E2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF1D7358), width: 1.5),
          ),
        ),
      ),
      home: const ProductsPage(),
    );
  }
}
