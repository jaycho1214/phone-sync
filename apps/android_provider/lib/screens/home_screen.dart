import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/extraction_provider.dart';
import '../providers/pairing_provider.dart';
import '../providers/permission_provider.dart';
import '../providers/server_provider.dart';
import '../providers/sync_status_provider.dart';
import '../theme/app_colors.dart';

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
      final permissions = ref.read(permissionProvider);

      // Auto-request permissions on first load if none are granted
      if (!permissions.hasAnyGranted) {
        await ref.read(permissionProvider.notifier).requestAllPermissions();
      }

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
      ref
          .read(extractionProvider.notifier)
          .refreshCounts(
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
    final server = ref.watch(serverProvider);
    final pairing = ref.watch(pairingProvider);
    final desktopActivity = ref.watch(desktopActivityProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
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
                    // PIN / Connection Section
                    if (server.isRunning) ...[
                      _buildConnectionSection(pairing, desktopActivity),
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
                    color: AppColors.textPrimary,
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
                        color: server.isRunning
                            ? AppColors.accent
                            : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        server.isRunning
                            ? 'Active${server.localIp != null ? ' • ${server.localIp}:${server.port}' : ' on port ${server.port}'}'
                            : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: server.isRunning
                              ? AppColors.accent
                              : AppColors.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
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
                color: server.isRunning
                    ? AppColors.surfaceAlt
                    : AppColors.textPrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                server.isRunning ? 'Stop' : 'Start',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: server.isRunning
                      ? AppColors.textSecondary
                      : Colors.white,
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
        color: AppColors.textMuted,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildConnectionSection(
    PairingUIState pairing,
    DesktopActivityState activity,
  ) {
    if (pairing.isPaired) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: activity.isExporting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              activity.isExporting ? 'Exporting' : 'Connected',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            if (activity.isExporting)
              Text(
                activity.exportStatusMessage,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.computer,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    pairing.clientName ?? 'Desktop',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Text(
            'Pairing Code',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                color: pairing.isPinExpired
                    ? AppColors.error
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                pairing.isPinExpired
                    ? 'Expired'
                    : pairing.formattedTimeRemaining,
                style: TextStyle(
                  fontSize: 12,
                  color: pairing.isPinExpired
                      ? AppColors.error
                      : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () =>
                    ref.read(pairingProvider.notifier).generateNewPin(),
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 14, color: AppColors.accent),
                    const SizedBox(width: 4),
                    Text(
                      'New code',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.accent,
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
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFamily: 'RobotoMono',
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildPermissionsCard(PermissionState permissions) {
    final needsPermissions = !permissions.hasAllGranted;
    final hasSomeDenied =
        permissions.contacts.isPermanentlyDenied ||
        permissions.sms.isPermanentlyDenied ||
        permissions.callLog.isPermanentlyDenied;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: needsPermissions
              ? AppColors.warning.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          // Permission items row
          Row(
            children: [
              Expanded(
                child: _buildPermissionItem('Contacts', permissions.contacts),
              ),
              Container(width: 1, height: 60, color: AppColors.border),
              Expanded(child: _buildPermissionItem('SMS', permissions.sms)),
              Container(width: 1, height: 60, color: AppColors.border),
              Expanded(
                child: _buildPermissionItem('Calls', permissions.callLog),
              ),
            ],
          ),
          // Action row when permissions needed
          if (needsPermissions && !permissions.isLoading) ...[
            Container(height: 1, color: AppColors.border),
            GestureDetector(
              onTap: () async {
                if (hasSomeDenied) {
                  ref.read(permissionProvider.notifier).openSettings();
                } else {
                  await ref
                      .read(permissionProvider.notifier)
                      .requestAllPermissions();
                  final newPerms = ref.read(permissionProvider);
                  await ref
                      .read(extractionProvider.notifier)
                      .refreshCounts(
                        hasContacts: newPerms.contacts.isGranted,
                        hasSms: newPerms.sms.isGranted,
                        hasCallLog: newPerms.callLog.isGranted,
                      );
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(11),
                    bottomRight: Radius.circular(11),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      hasSomeDenied ? Icons.settings : Icons.touch_app,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasSomeDenied
                          ? 'Open Settings to Grant'
                          : 'Tap to Grant Permissions',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
      iconColor = AppColors.accent;
      bgColor = AppColors.accentLight;
      icon = Icons.check_circle;
    } else if (isDenied) {
      iconColor = AppColors.error;
      bgColor = AppColors.errorLight;
      icon = Icons.cancel;
    } else {
      iconColor = AppColors.warning;
      bgColor = AppColors.warningLight;
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
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCards(
    PermissionState permissions,
    ExtractionState extraction,
  ) {
    final hasAnyPermission =
        permissions.contacts.isGranted ||
        permissions.sms.isGranted ||
        permissions.callLog.isGranted;

    return Column(
      children: [
        // First row: Contacts and SMS
        Row(
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
          ],
        ),
        const SizedBox(height: 8),
        // Second row: Calls and Phone Numbers
        Row(
          children: [
            Expanded(
              child: _buildDataCard(
                'Calls',
                Icons.phone_outlined,
                permissions.callLog.isGranted ? extraction.callLogCount : null,
                !permissions.callLog.isGranted,
                extraction.isLoading,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDataCard(
                'Phone Numbers',
                Icons.dialpad,
                hasAnyPermission ? extraction.phoneNumberCount : null,
                !hasAnyPermission,
                extraction.isLoading,
              ),
            ),
          ],
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(height: 12),
          if (isLoading && !noPermission)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textMuted,
              ),
            )
          else
            Text(
              noPermission ? '—' : _formatNumber(count),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
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
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(fontSize: 13, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
