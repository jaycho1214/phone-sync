import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../models/device.dart';
import '../providers/discovery_provider.dart';
import '../providers/session_provider.dart';
import '../widgets/device_card.dart';

/// Screen for discovering and selecting Android devices.
class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _manualEntryController = TextEditingController();
  bool _showManualEntry = false;
  Timer? _manualEntryTimer;
  bool _checkedSession = false;
  DiscoveryNotifier? _discoveryNotifier;

  @override
  void initState() {
    super.initState();
    // Delay to avoid modifying providers during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Save notifier reference for use in dispose
      _discoveryNotifier = ref.read(discoveryProvider.notifier);
      _checkExistingSession();
    });
  }

  Future<void> _checkExistingSession() async {
    final sessionState = ref.read(sessionProvider);

    // Wait for session to load
    if (sessionState.isLoading) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
    }

    final session = ref.read(sessionProvider);

    // If there's a paired device, verify the session is still valid
    if (session.isPaired && session.device != null) {
      final syncService = session.syncService;
      bool isValid = false;

      if (syncService != null) {
        try {
          isValid = await syncService.validateSession();
        } catch (_) {
          isValid = false;
        }
      }

      if (!mounted) return;

      if (isValid) {
        // Session is valid, add device to discovery list with Paired badge
        ref.read(discoveryProvider.notifier).addKnownDevice(session.device!);
      } else {
        // Session expired, clear it so badge won't show
        await ref.read(sessionProvider.notifier).unpair();
      }
    }

    _checkedSession = true;

    // Always start discovery and show device list
    // User must explicitly tap a device to go to home screen
    _startDiscovery();
  }

  void _startDiscovery() {
    ref.read(discoveryProvider.notifier).startDiscovery();

    // Show manual entry option after 5 seconds if no devices found
    _manualEntryTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        final devices = ref.read(discoveryProvider).devices;
        if (devices.isEmpty) {
          setState(() => _showManualEntry = true);
        }
      }
    });
  }

  @override
  void dispose() {
    _manualEntryController.dispose();
    _manualEntryTimer?.cancel();
    _discoveryNotifier?.stopDiscovery();
    super.dispose();
  }

  Future<void> _selectDevice(Device device) async {
    final session = ref.read(sessionProvider);

    // If this device is already paired, verify connection first
    if (session.isPaired && session.device != null) {
      final pairedDevice = session.device!;
      if (pairedDevice.host == device.host && pairedDevice.port == device.port) {
        // Check if session is still valid
        final syncService = session.syncService;
        if (syncService != null) {
          try {
            final isValid = await syncService.validateSession();
            if (!mounted) return;

            if (isValid) {
              Navigator.of(context).pushReplacementNamed('/home');
              return;
            }
          } catch (_) {
            // Session is invalid, fall through to pairing
          }
        }

        // Session expired - clear it and go to pairing
        if (!mounted) return;
        await ref.read(sessionProvider.notifier).unpair();
      }
    }

    // Go to pairing screen
    if (!mounted) return;
    Navigator.of(context).pushNamed('/pairing', arguments: device);
  }

  void _addManualDevice() {
    final input = _manualEntryController.text.trim();
    if (input.isEmpty) return;

    ref.read(discoveryProvider.notifier).addManualDevice(input);

    // Check if device was added successfully
    final state = ref.read(discoveryProvider);
    if (state.error == null) {
      _manualEntryController.clear();

      // Auto-select if it's the only device
      if (state.devices.length == 1) {
        _selectDevice(state.devices.first);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final discoveryState = ref.watch(discoveryProvider);
    final sessionState = ref.watch(sessionProvider);

    // Show loading while checking session
    if (!_checkedSession || sessionState.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              const Text(
                'Checking for paired device...',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                        const SizedBox(height: 24),

                        // Device list or searching indicator
                        Expanded(child: _buildContent(discoveryState, sessionState)),

                        // Manual entry section
                        if (_showManualEntry || discoveryState.devices.isEmpty)
                          _buildManualEntry(discoveryState),

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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // Logo
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset('assets/logo.png', width: 40, height: 40),
          ),
          const SizedBox(width: 12),
          // Title
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PhoneSync',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Connect to your Android device',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(DiscoveryState state, SessionState sessionState) {
    if (state.devices.isEmpty && state.isDiscovering) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.textMuted),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Searching for devices...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Make sure your Android device is on the same network',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (state.devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(Icons.devices_other, size: 28, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            const Text(
              'No devices found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the IP address manually below',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        const Text(
          'AVAILABLE DEVICES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        // Device list
        Expanded(
          child: ListView.separated(
            itemCount: state.devices.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final device = state.devices[index];
              final isPaired =
                  sessionState.isPaired &&
                  sessionState.device != null &&
                  sessionState.device!.host == device.host &&
                  sessionState.device!.port == device.port;

              return DeviceCard(
                device: device,
                onTap: () => _selectDevice(device),
                isPaired: isPaired,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildManualEntry(DiscoveryState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.devices.isNotEmpty) ...[
          const SizedBox(height: 16),
          Center(
            child: Text(
              "Can't find your device?",
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MANUAL ENTRY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualEntryController,
                      decoration: InputDecoration(
                        hintText: '192.168.1.100:42829',
                        errorText: state.error,
                        filled: true,
                        fillColor: AppColors.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.textPrimary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        color: AppColors.textPrimary,
                      ),
                      keyboardType: TextInputType.text,
                      onSubmitted: (_) => _addManualDevice(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _addManualDevice,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Connect',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
