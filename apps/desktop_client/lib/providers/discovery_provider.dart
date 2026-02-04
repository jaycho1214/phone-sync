import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../services/discovery_service.dart';

/// State for device discovery.
class DiscoveryState {
  final List<Device> devices;
  final bool isDiscovering;
  final String? error;

  const DiscoveryState({this.devices = const [], this.isDiscovering = false, this.error});

  DiscoveryState copyWith({List<Device>? devices, bool? isDiscovering, String? error}) {
    return DiscoveryState(
      devices: devices ?? this.devices,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      error: error,
    );
  }
}

/// Notifier for device discovery state.
class DiscoveryNotifier extends Notifier<DiscoveryState> {
  late final DiscoveryService _service;
  Device? _knownDevice; // Paired device to always show

  @override
  DiscoveryState build() {
    _service = DiscoveryService();
    ref.onDispose(() => _service.dispose());
    return const DiscoveryState();
  }

  /// Start discovering devices on the local network.
  Future<void> startDiscovery() async {
    state = state.copyWith(isDiscovering: true, error: null);

    await _service.startDiscovery(
      onDevicesChanged: (devices) {
        // Merge discovered devices with known device
        final merged = _mergeWithKnownDevice(devices);
        state = state.copyWith(devices: merged);
      },
    );

    // After discovery starts, add known device if we have one
    if (_knownDevice != null) {
      _service.addManualDevice(_knownDevice!);
    }
  }

  /// Merge discovered devices with known device, avoiding duplicates.
  List<Device> _mergeWithKnownDevice(List<Device> discovered) {
    if (_knownDevice == null) return List.from(discovered);

    // Check if known device is already in the list
    final hasKnown = discovered.any(
      (d) => d.host == _knownDevice!.host && d.port == _knownDevice!.port,
    );

    if (hasKnown) return List.from(discovered);

    // Add known device at the beginning
    return [_knownDevice!, ...discovered];
  }

  /// Stop discovering devices.
  Future<void> stopDiscovery() async {
    await _service.stopDiscovery();
    state = state.copyWith(isDiscovering: false);
  }

  /// Add a device manually (for IP:port fallback).
  void addManualDevice(String input) {
    final device = _service.parseManualEntry(input);
    if (device != null) {
      _service.addManualDevice(device);
      state = state.copyWith(devices: List.from(_service.devices), error: null);
    } else {
      state = state.copyWith(error: 'Invalid format. Use IP:PORT (e.g., 192.168.1.100:8443)');
    }
  }

  /// Add a known device directly (e.g., paired device from session).
  /// This device will be preserved even when discovery restarts.
  void addKnownDevice(Device device) {
    _knownDevice = device;
    _service.addManualDevice(device);
    state = state.copyWith(devices: _mergeWithKnownDevice(_service.devices));
  }
}

/// Provider for device discovery.
final discoveryProvider = NotifierProvider<DiscoveryNotifier, DiscoveryState>(
  DiscoveryNotifier.new,
);
