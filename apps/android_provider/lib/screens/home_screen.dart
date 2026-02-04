import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/extraction_provider.dart';
import '../providers/pairing_provider.dart';
import '../providers/permission_provider.dart';
import '../providers/server_provider.dart';
import '../providers/sync_state_provider.dart';

// Professional light color palette
class _Colors {
  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF1F3F4);
  static const border = Color(0xFFE5E7EB);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const accent = Color(0xFF10B981);
  static const accentLight = Color(0xFFD1FAE5);
  static const error = Color(0xFFEF4444);
  static const errorLight = Color(0xFFFEE2E2);
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFEF3C7);
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(permissionProvider.notifier).checkPermissions();
      ref.read(syncStateProvider.notifier).loadSyncState();
      // Auto-start server by default (safe to call if already running)
      _autoStartServerIfReady();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

    // Start server (safe to call multiple times - server provider handles idempotency)
    if (!server.isRunning) {
      ref.read(serverProvider.notifier).startServer();
      ref.read(pairingProvider.notifier).generateNewPin();
    }

    // Refresh counts if permissions granted
    if (permissions.hasAnyGranted) {
      ref.read(extractionProvider.notifier).refreshCounts(
            hasContacts: permissions.contacts.isGranted,
            hasSms: permissions.sms.isGranted,
            hasCallLog: permissions.callLog.isGranted,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionProvider);
    final extraction = ref.watch(extractionProvider);
    final syncState = ref.watch(syncStateProvider);
    final server = ref.watch(serverProvider);
    final pairing = ref.watch(pairingProvider);

    return Scaffold(
      backgroundColor: _Colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Professional Header
            _buildHeader(server),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PIN Section
                    if (server.isRunning) ...[
                      _buildPinSection(pairing),
                      const SizedBox(height: 20),
                    ],

                    // Permissions 1x3 card
                    _buildSectionLabel('PERMISSIONS'),
                    const SizedBox(height: 8),
                    _buildPermissionsCard(permissions),

                    const SizedBox(height: 20),

                    // Available Data 1xn cards
                    _buildSectionLabel('AVAILABLE DATA'),
                    const SizedBox(height: 8),
                    _buildDataCards(permissions, extraction),

                    const SizedBox(height: 20),

                    // Sync Status 1xn cards
                    _buildSectionLabel('LAST SYNCED'),
                    const SizedBox(height: 8),
                    _buildSyncCards(syncState),

                    // Error display
                    if (server.error != null ||
                        extraction.error != null ||
                        permissions.error != null) ...[
                      const SizedBox(height: 20),
                      _buildErrorBanner(
                        server.error ??
                            extraction.error ??
                            permissions.error ??
                            '',
                      ),
                    ],

                    // Permissions request
                    if (!permissions.hasAnyGranted && !permissions.isLoading) ...[
                      const SizedBox(height: 20),
                      _buildPermissionsRequest(),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ServerState server) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: _Colors.surface,
        border: Border(
          bottom: BorderSide(color: _Colors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Logo/Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _Colors.textPrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.sync_alt,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // Title and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PhoneSync',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _Colors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: server.isRunning ? _Colors.accent : _Colors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      server.isRunning ? 'Active on port ${server.port}' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: server.isRunning ? _Colors.accent : _Colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Server toggle
          GestureDetector(
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: server.isRunning ? _Colors.surfaceAlt : _Colors.textPrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                server.isRunning ? 'Stop' : 'Start',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: server.isRunning ? _Colors.textSecondary : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _Colors.textMuted,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildPinSection(PairingUIState pairing) {
    if (pairing.isPaired) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _Colors.accentLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _Colors.accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _Colors.accent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Connected',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _Colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Desktop client is paired',
              style: TextStyle(
                fontSize: 13,
                color: _Colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _Colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Colors.border),
      ),
      child: Column(
        children: [
          const Text(
            'Pairing Code',
            style: TextStyle(
              fontSize: 13,
              color: _Colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          // Large PIN display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _buildPinDigits(pairing.pin ?? '------'),
          ),
          const SizedBox(height: 16),
          // Timer and refresh
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: pairing.isPinExpired ? _Colors.error : _Colors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                pairing.isPinExpired ? 'Expired' : pairing.formattedTimeRemaining,
                style: TextStyle(
                  fontSize: 12,
                  color: pairing.isPinExpired ? _Colors.error : _Colors.textMuted,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => ref.read(pairingProvider.notifier).generateNewPin(),
                child: Row(
                  children: [
                    Icon(
                      Icons.refresh,
                      size: 14,
                      color: _Colors.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'New code',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _Colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPinDigits(String pin) {
    return pin.split('').map((digit) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 44,
        height: 56,
        decoration: BoxDecoration(
          color: _Colors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _Colors.border),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: _Colors.textPrimary,
              fontFamily: 'RobotoMono',
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildPermissionsCard(PermissionState permissions) {
    return Container(
      decoration: BoxDecoration(
        color: _Colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Colors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _buildPermissionItem('Contacts', permissions.contacts)),
          Container(width: 1, height: 60, color: _Colors.border),
          Expanded(child: _buildPermissionItem('SMS', permissions.sms)),
          Container(width: 1, height: 60, color: _Colors.border),
          Expanded(child: _buildPermissionItem('Calls', permissions.callLog)),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(String label, PermissionStatus status) {
    final isGranted = status.isGranted;
    final isDenied = status.isPermanentlyDenied;

    Color iconColor;
    Color bgColor;
    IconData icon;

    if (isGranted) {
      iconColor = _Colors.accent;
      bgColor = _Colors.accentLight;
      icon = Icons.check_circle;
    } else if (isDenied) {
      iconColor = _Colors.error;
      bgColor = _Colors.errorLight;
      icon = Icons.cancel;
    } else {
      iconColor = _Colors.warning;
      bgColor = _Colors.warningLight;
      icon = Icons.warning_rounded;
    }

    return GestureDetector(
      onTap: !isGranted
          ? () => ref.read(permissionProvider.notifier).openSettings()
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: _Colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCards(PermissionState permissions, ExtractionState extraction) {
    return Row(
      children: [
        Expanded(
          child: _buildDataCard(
            'Contacts',
            Icons.person_outline,
            permissions.contacts.isGranted ? extraction.contactCount : null,
            !permissions.contacts.isGranted,
            extraction.isLoading,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildDataCard(
            'SMS',
            Icons.message_outlined,
            permissions.sms.isGranted ? extraction.smsCount : null,
            !permissions.sms.isGranted,
            extraction.isLoading,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildDataCard(
            'Calls',
            Icons.phone_outlined,
            permissions.callLog.isGranted ? extraction.callLogCount : null,
            !permissions.callLog.isGranted,
            extraction.isLoading,
          ),
        ),
      ],
    );
  }

  Widget _buildDataCard(
    String label,
    IconData icon,
    int? count,
    bool noPermission,
    bool isLoading,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: _Colors.textMuted),
          const SizedBox(height: 12),
          if (isLoading && !noPermission)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _Colors.textMuted,
              ),
            )
          else
            Text(
              noPermission ? '—' : _formatNumber(count),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: _Colors.textPrimary,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _Colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncCards(SyncState syncState) {
    return Row(
      children: [
        Expanded(
          child: _buildSyncCard(
            'Contacts',
            syncState.formatLastSync(syncState.contactsLastSync),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSyncCard(
            'SMS',
            syncState.formatLastSync(syncState.smsLastSync),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSyncCard(
            'Calls',
            syncState.formatLastSync(syncState.callLogLastSync),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncCard(String label, String time) {
    final isNever = time == 'Never';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: _Colors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isNever ? _Colors.textMuted : _Colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int? number) {
    if (number == null) return '—';
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Colors.errorLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _Colors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: _Colors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 13,
                color: _Colors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsRequest() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _Colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Colors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _Colors.surfaceAlt,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.lock_outline,
              color: _Colors.textMuted,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Permissions Required',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _Colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Grant access to sync your phone data',
            style: TextStyle(
              fontSize: 13,
              color: _Colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
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
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _Colors.textPrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Grant Permissions',
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
    );
  }
}
