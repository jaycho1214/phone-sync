import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class PhoneSyncApp extends StatelessWidget {
  const PhoneSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhoneSync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
