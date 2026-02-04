import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
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
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button
            _buildHeader(),

            // Main content
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Spacer(),

                        // Device info card
                        _buildDeviceCard(),
                        const SizedBox(height: 40),

                        // Instructions
                        const Text(
                          'Enter pairing code',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter the 6-digit code shown on your Android device',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // PIN input or loading
                        if (_isPairing)
                          _buildPairingState()
                        else
                          PinInput(
                            controller: _pinController,
                            focusNode: _focusNode,
                            onCompleted: _onPinComplete,
                          ),

                        // Error message
                        if (_error != null) ...[
                          const SizedBox(height: 20),
                          _buildErrorBanner(),
                        ],

                        const Spacer(flex: 2),

                        // Help text
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 18,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Make sure the PhoneSync server is running on your Android device',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Pair Device',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.phone_android,
              color: AppColors.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.device.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.device.host}:${widget.device.port}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPairingState() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Pairing...',
          style: TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
