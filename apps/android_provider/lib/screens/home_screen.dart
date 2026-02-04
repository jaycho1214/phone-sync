import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/extraction_provider.dart';
import '../providers/pairing_provider.dart';
import '../providers/permission_provider.dart';
import '../providers/server_provider.dart';
import '../providers/sync_state_provider.dart';

// Industrial color palette
class _Colors {
  static const background = Color(0xFF0A0A0A);
  static const surface = Color(0xFF111111);
  static const border = Color(0xFF222222);
  static const borderLight = Color(0xFF333333);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF888888);
  static const textMuted = Color(0xFF555555);
  static const accent = Color(0xFF00FF88);
  static const accentDim = Color(0xFF00AA5C);
  static const error = Color(0xFFFF3B3B);
  static const warning = Color(0xFFFFAA00);
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _hasAutoStarted = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(permissionProvider.notifier).checkPermissions();
      ref.read(syncStateProvider.notifier).loadSyncState();
      _autoStartServerIfReady();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final server = ref.read(serverProvider);
    if (state == AppLifecycleState.resumed && !server.isRunning) {
      _autoStartServerIfReady();
    } else if (state == AppLifecycleState.paused) {
      ref.read(serverProvider.notifier).stopServer();
      ref.read(pairingProvider.notifier).reset();
    }
  }

  void _autoStartServerIfReady() {
    final permissions = ref.read(permissionProvider);
    final server = ref.read(serverProvider);

    if (permissions.hasAnyGranted && !server.isRunning && !_hasAutoStarted) {
      _hasAutoStarted = true;
      ref.read(serverProvider.notifier).startServer();
      ref.read(pairingProvider.notifier).generateNewPin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionProvider);
    final extraction = ref.watch(extractionProvider);
    final server = ref.watch(serverProvider);
    final pairing = ref.watch(pairingProvider);

    return Scaffold(
      backgroundColor: _Colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(server),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // PIN Section (hero element)
                    if (server.isRunning) _buildPinSection(pairing),

                    // Status Grid
                    _buildStatusGrid(permissions, extraction, server),

                    // Error display
                    if (server.error != null ||
                        extraction.error != null ||
                        permissions.error != null)
                      _buildErrorSection(
                        server.error ??
                            extraction.error ??
                            permissions.error ??
                            '',
                      ),

                    // Permissions request
                    if (!permissions.hasAnyGranted && !permissions.isLoading)
                      _buildPermissionsRequest(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Bottom action bar
            _buildBottomBar(server, permissions, extraction),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ServerState server) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _Colors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Status indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: server.isRunning
                      ? Color.lerp(
                          _Colors.accent,
                          _Colors.accentDim,
                          _pulseController.value,
                        )
                      : _Colors.textMuted,
                  boxShadow: server.isRunning
                      ? [
                          BoxShadow(
                            color: _Colors.accent
                                .withValues(alpha: 0.5 - _pulseController.value * 0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          // Title
          const Text(
            'PHONESYNC',
            style: TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 4,
              color: _Colors.textPrimary,
            ),
          ),
          const Spacer(),
          // Port badge
          if (server.isRunning)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: _Colors.borderLight),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                ':${server.port}',
                style: const TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 11,
                  color: _Colors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPinSection(PairingUIState pairing) {
    if (pairing.isPaired) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: _Colors.border, width: 1),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.link,
              size: 32,
              color: _Colors.accent,
            ),
            const SizedBox(height: 16),
            const Text(
              'PAIRED',
              style: TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 24,
                fontWeight: FontWeight.w300,
                letterSpacing: 8,
                color: _Colors.accent,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Device connected',
              style: TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 11,
                color: _Colors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _Colors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Label
          const Text(
            'PAIRING CODE',
            style: TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 3,
              color: _Colors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          // Large PIN display - terminal style
          Text(
            _formatPin(pairing.pin ?? '------'),
            style: const TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 48,
              fontWeight: FontWeight.w300,
              letterSpacing: 16,
              color: _Colors.accent,
              height: 1,
            ),
          ),
          const SizedBox(height: 20),
          // Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      pairing.isPinExpired ? _Colors.error : _Colors.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                pairing.isPinExpired
                    ? 'EXPIRED'
                    : pairing.formattedTimeRemaining,
                style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 11,
                  letterSpacing: 2,
                  color:
                      pairing.isPinExpired ? _Colors.error : _Colors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Refresh button
          GestureDetector(
            onTap: () => ref.read(pairingProvider.notifier).generateNewPin(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: _Colors.borderLight),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 14, color: _Colors.textSecondary),
                  SizedBox(width: 8),
                  Text(
                    'NEW CODE',
                    style: TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 10,
                      letterSpacing: 2,
                      color: _Colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPin(String pin) {
    if (pin.length != 6) return pin;
    return '${pin.substring(0, 3)} ${pin.substring(3)}';
  }

  Widget _buildStatusGrid(
    PermissionState permissions,
    ExtractionState extraction,
    ServerState server,
  ) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          const Text(
            'DATA SOURCES',
            style: TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
              color: _Colors.textMuted,
            ),
          ),
          const SizedBox(height: 16),

          // Data rows
          _buildDataRow(
            'Contacts',
            permissions.contacts.isGranted ? extraction.contactCount : null,
            permissions.contacts,
          ),
          _buildDivider(),
          _buildDataRow(
            'SMS',
            permissions.sms.isGranted ? extraction.smsCount : null,
            permissions.sms,
          ),
          _buildDivider(),
          _buildDataRow(
            'Call Log',
            permissions.callLog.isGranted ? extraction.callLogCount : null,
            permissions.callLog,
          ),
          _buildDivider(),

          // Total row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 11,
                    letterSpacing: 2,
                    color: _Colors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatNumber(extraction.totalCount),
                  style: const TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _Colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, int? count, PermissionStatus status) {
    final isGranted = status.isGranted;
    final isDenied = status.isPermanentlyDenied;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isGranted
                  ? _Colors.accent
                  : isDenied
                      ? _Colors.error
                      : _Colors.warning,
            ),
          ),
          const SizedBox(width: 12),
          // Label
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 11,
              letterSpacing: 1,
              color: _Colors.textSecondary,
            ),
          ),
          const Spacer(),
          // Count or status
          Text(
            isGranted
                ? _formatNumber(count)
                : isDenied
                    ? 'DENIED'
                    : 'PENDING',
            style: TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 13,
              fontWeight: isGranted ? FontWeight.w500 : FontWeight.w400,
              color: isGranted
                  ? _Colors.textPrimary
                  : isDenied
                      ? _Colors.error
                      : _Colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: _Colors.border,
    );
  }

  String _formatNumber(int? number) {
    if (number == null) return '---';
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildErrorSection(String error) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: _Colors.error.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            color: _Colors.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 11,
                color: _Colors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsRequest() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _Colors.borderLight),
            ),
            child: const Icon(
              Icons.lock_outline,
              color: _Colors.textMuted,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'PERMISSIONS REQUIRED',
            style: TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 11,
              letterSpacing: 2,
              color: _Colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Grant access to sync your data',
            style: TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 12,
              color: _Colors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () async {
              await ref
                  .read(permissionProvider.notifier)
                  .requestAllPermissions();
              final newPerms = ref.read(permissionProvider);
              await ref.read(extractionProvider.notifier).refreshCounts(
                    hasContacts: newPerms.contacts.isGranted,
                    hasSms: newPerms.sms.isGranted,
                    hasCallLog: newPerms.callLog.isGranted,
                  );
              _hasAutoStarted = false;
              _autoStartServerIfReady();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _Colors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Text(
                'GRANT ACCESS',
                style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: _Colors.background,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    ServerState server,
    PermissionState permissions,
    ExtractionState extraction,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: _Colors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Server toggle
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (server.isRunning) {
                  ref.read(serverProvider.notifier).stopServer();
                  ref.read(pairingProvider.notifier).reset();
                } else {
                  ref.read(serverProvider.notifier).startServer();
                  ref.read(pairingProvider.notifier).generateNewPin();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color:
                      server.isRunning ? _Colors.surface : _Colors.accent,
                  border: Border.all(
                    color: server.isRunning ? _Colors.borderLight : _Colors.accent,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      server.isRunning ? Icons.stop : Icons.play_arrow,
                      size: 16,
                      color: server.isRunning
                          ? _Colors.textSecondary
                          : _Colors.background,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      server.isRunning ? 'STOP' : 'START',
                      style: TextStyle(
                        fontFamily: 'RobotoMono',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: server.isRunning
                            ? _Colors.textSecondary
                            : _Colors.background,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Refresh button
          GestureDetector(
            onTap: permissions.hasAnyGranted && !extraction.isLoading
                ? () => ref.read(extractionProvider.notifier).refreshCounts(
                      hasContacts: permissions.contacts.isGranted,
                      hasSms: permissions.sms.isGranted,
                      hasCallLog: permissions.callLog.isGranted,
                    )
                : null,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: _Colors.borderLight),
                borderRadius: BorderRadius.circular(2),
              ),
              child: extraction.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: _Colors.textMuted,
                      ),
                    )
                  : Icon(
                      Icons.refresh,
                      size: 16,
                      color: permissions.hasAnyGranted
                          ? _Colors.textSecondary
                          : _Colors.textMuted,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Settings button
          GestureDetector(
            onTap: () => ref.read(permissionProvider.notifier).openSettings(),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: _Colors.borderLight),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Icon(
                Icons.settings_outlined,
                size: 16,
                color: _Colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
