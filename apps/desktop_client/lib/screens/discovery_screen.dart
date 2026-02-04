import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final sessionState = ref.read(sessionProvider);

    // Wait for session to load
    if (sessionState.isLoading) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
    }

    final session = ref.read(sessionProvider);
    _checkedSession = true;

    if (session.isPaired && session.device != null) {
      // Check if device is online
      final sessionNotifier = ref.read(sessionProvider.notifier);
      final isOnline = await sessionNotifier.checkDeviceOnline();

      if (!mounted) return;

      if (isOnline) {
        // Auto-navigate to home
        Navigator.of(context).pushReplacementNamed('/home');
        return;
      }
    }

    // Start discovery
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
    ref.read(discoveryProvider.notifier).stopDiscovery();
    super.dispose();
  }

  void _selectDevice(Device device) {
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
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Checking for paired device...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 48),
            // Header
            Text(
              'PhoneSync',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to your Android device',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),

            // Device list or searching indicator
            Expanded(
              child: _buildContent(discoveryState),
            ),

            // Manual entry section
            if (_showManualEntry || discoveryState.devices.isEmpty)
              _buildManualEntry(discoveryState),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(DiscoveryState state) {
    if (state.devices.isEmpty && state.isDiscovering) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Searching for devices...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Make sure your Android device is on the same network',
              style: Theme.of(context).textTheme.bodyMedium,
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
            Icon(
              Icons.devices_other,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No devices found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the IP address manually below',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: state.devices.length,
      itemBuilder: (context, index) {
        final device = state.devices[index];
        return DeviceCard(
          device: device,
          onTap: () => _selectDevice(device),
        );
      },
    );
  }

  Widget _buildManualEntry(DiscoveryState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.devices.isNotEmpty) ...[
            const Divider(height: 32),
            Text(
              "Can't find your device?",
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualEntryController,
                  decoration: InputDecoration(
                    hintText: '192.168.1.100:8443',
                    labelText: 'IP:Port',
                    errorText: state.error,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _manualEntryController.clear();
                        ref.read(discoveryProvider.notifier).clearError();
                      },
                    ),
                  ),
                  keyboardType: TextInputType.text,
                  onSubmitted: (_) => _addManualDevice(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _addManualDevice,
                child: const Text('Connect'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
