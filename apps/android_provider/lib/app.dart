import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';

class PhoneSyncApp extends StatelessWidget {
  const PhoneSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Industrial dark theme
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0A0A0A),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return MaterialApp(
      title: 'PhoneSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF0A0A0A),
          primary: Color(0xFF00FF88),
          secondary: Color(0xFF00FF88),
          error: Color(0xFFFF3B3B),
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          // Large terminal readout
          displayLarge: TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 56,
            fontWeight: FontWeight.w300,
            letterSpacing: 12,
            color: Color(0xFF00FF88),
          ),
          // Section labels
          labelLarge: TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
            color: Color(0xFF666666),
          ),
          // Data values
          bodyLarge: TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFFCCCCCC),
          ),
          bodyMedium: TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 12,
            color: Color(0xFF888888),
          ),
        ),
        dividerColor: const Color(0xFF222222),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
