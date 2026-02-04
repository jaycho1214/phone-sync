import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../services/discovery_service.dart';

/// State for device discovery.
class DiscoveryState {
  final List<Device> devices;
  final bool isDiscovering;
  final String? error;

  const DiscoveryState({
    this.devices = const [],
    this.isDiscovering = false,
    this.error,
  });

  DiscoveryState copyWith({
    List<Device>? devices,
    bool? isDiscovering,
    String? error,
  }) {
    return DiscoveryState(
      devices: devices ?? this.devices,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      error: error,
    );
  }
}

/// Notifier for device discovery state.
class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  final DiscoveryService _service = DiscoveryService();

  DiscoveryNotifier() : super(const DiscoveryState());

  /// Start discovering devices on the local network.
  Future<void> startDiscovery() async {
    state = state.copyWith(isDiscovering: true, error: null);

    await _service.startDiscovery(
      onDevicesChanged: (devices) {
        state = state.copyWith(devices: List.from(devices));
      },
    );
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
      state = state.copyWith(
        devices: List.from(_service.devices),
        error: null,
      );
    } else {
      state = state.copyWith(error: 'Invalid format. Use IP:PORT (e.g., 192.168.1.100:8443)');
    }
  }

  /// Clear the error message.
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

/// Provider for device discovery.
final discoveryProvider = StateNotifierProvider<DiscoveryNotifier, DiscoveryState>((ref) {
  return DiscoveryNotifier();
});
