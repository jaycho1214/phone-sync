import 'package:flutter/material.dart';

import '../models/device.dart';

/// Placeholder pairing screen - full implementation in Task 3.
class PairingScreen extends StatelessWidget {
  final Device device;

  const PairingScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Pairing Screen for ${device.name} - Coming in Task 3'),
      ),
    );
  }
}
