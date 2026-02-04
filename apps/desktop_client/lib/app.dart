import 'package:flutter/material.dart';

import 'screens/discovery_screen.dart';
import 'screens/pairing_screen.dart';
import 'screens/home_screen.dart';
import 'models/device.dart';

/// Main application widget with modern/minimal theme.
class PhoneSyncApp extends StatelessWidget {
  const PhoneSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhoneSync',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      initialRoute: '/discovery',
      onGenerateRoute: _generateRoute,
    );
  }

  /// Build modern/minimal theme with clean cards and subtle shadows.
  ThemeData _buildTheme() {
    const primaryColor = Color(0xFF2563EB); // Blue-600

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slate-50
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF1E293B), // Slate-800
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: Color(0xFF334155), // Slate-700
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFF475569), // Slate-600
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFF64748B), // Slate-500
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// Generate routes for the app.
  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/discovery':
        return MaterialPageRoute(
          builder: (_) => const DiscoveryScreen(),
          settings: settings,
        );
      case '/pairing':
        final device = settings.arguments as Device;
        return MaterialPageRoute(
          builder: (_) => PairingScreen(device: device),
          settings: settings,
        );
      case '/home':
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const DiscoveryScreen(),
          settings: settings,
        );
    }
  }
}
