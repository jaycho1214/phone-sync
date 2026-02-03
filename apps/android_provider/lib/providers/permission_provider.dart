import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Permission status for all three data sources
class PermissionState {
  final PermissionStatus contacts;
  final PermissionStatus sms;
  final PermissionStatus callLog;
  final bool isLoading;
  final String? error;

  const PermissionState({
    this.contacts = PermissionStatus.denied,
    this.sms = PermissionStatus.denied,
    this.callLog = PermissionStatus.denied,
    this.isLoading = false,
    this.error,
  });

  bool get hasAnyGranted =>
      contacts.isGranted || sms.isGranted || callLog.isGranted;

  bool get allPermanentlyDenied =>
      contacts.isPermanentlyDenied &&
      sms.isPermanentlyDenied &&
      callLog.isPermanentlyDenied;

  List<String> get permanentlyDeniedNames => [
        if (contacts.isPermanentlyDenied) 'Contacts',
        if (sms.isPermanentlyDenied) 'SMS',
        if (callLog.isPermanentlyDenied) 'Call Log',
      ];

  PermissionState copyWith({
    PermissionStatus? contacts,
    PermissionStatus? sms,
    PermissionStatus? callLog,
    bool? isLoading,
    String? error,
  }) {
    return PermissionState(
      contacts: contacts ?? this.contacts,
      sms: sms ?? this.sms,
      callLog: callLog ?? this.callLog,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PermissionNotifier extends StateNotifier<PermissionState> {
  PermissionNotifier() : super(const PermissionState());

  /// Check current permission status without requesting
  Future<void> checkPermissions() async {
    state = state.copyWith(isLoading: true);
    try {
      final contacts = await Permission.contacts.status;
      final sms = await Permission.sms.status;
      // Permission.phone covers call log on Android 9+
      final callLog = await Permission.phone.status;

      state = PermissionState(
        contacts: contacts,
        sms: sms,
        callLog: callLog,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Request all permissions at once (per CONTEXT.md decision)
  Future<void> requestAllPermissions() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final statuses = await [
        Permission.contacts,
        Permission.sms,
        Permission.phone, // Includes call log
      ].request();

      state = PermissionState(
        contacts: statuses[Permission.contacts] ?? PermissionStatus.denied,
        sms: statuses[Permission.sms] ?? PermissionStatus.denied,
        callLog: statuses[Permission.phone] ?? PermissionStatus.denied,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Open app settings for manually enabling permissions
  Future<bool> openSettings() async {
    return await openAppSettings();
  }
}

final permissionProvider =
    StateNotifierProvider<PermissionNotifier, PermissionState>(
  (ref) => PermissionNotifier(),
);
