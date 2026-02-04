import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../providers/session_provider.dart';
import '../widgets/pin_input.dart';

/// Screen for entering PIN to pair with a device.
class PairingScreen extends ConsumerStatefulWidget {
  final Device device;

  const PairingScreen({super.key, required this.device});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isPairing = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onPinComplete(String pin) async {
    if (_isPairing) return;

    setState(() {
      _isPairing = true;
      _error = null;
    });

    final sessionNotifier = ref.read(sessionProvider.notifier);
    final success = await sessionNotifier.pair(widget.device, pin);

    if (!mounted) return;

    if (success) {
      // Navigate to home screen
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
      );
    } else {
      // Show error and clear input
      final sessionState = ref.read(sessionProvider);
      setState(() {
        _isPairing = false;
        _error = sessionState.error ?? 'Pairing failed';
      });
      _pinController.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              const SizedBox(height: 48),
              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Back to device list',
                ),
              ),
              const Spacer(),
              // Device info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.phone_android,
                      color: Color(0xFF2563EB),
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.device.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          '${widget.device.host}:${widget.device.port}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              // Instructions
              Text(
                'Enter the PIN shown on your phone',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'The PIN is displayed on your Android device',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // PIN input
              if (_isPairing)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Pairing...',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                )
              else
                PinInput(
                  controller: _pinController,
                  focusNode: _focusNode,
                  onCompleted: _onPinComplete,
                ),
              const SizedBox(height: 24),
              // Error message
              if (_error != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(flex: 2),
              // Help text
              Text(
                "Make sure the PhoneSync server is running on your Android device",
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
