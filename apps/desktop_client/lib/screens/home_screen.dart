import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../providers/export_provider.dart';
import '../providers/session_provider.dart';

/// Home screen - shown when paired with a device.
/// Compact layout with data counts, export selection, and settings.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(sessionProvider);
      ref.read(exportProvider.notifier).setSyncService(session.syncService);
    });
  }

  Future<void> _unpair(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Unpair Device',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Are you sure? You will need to enter the PIN again to reconnect.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unpair', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(sessionProvider.notifier).unpair();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/discovery', (route) => false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final exportState = ref.read(exportProvider);
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: exportState.sinceDate ?? now.subtract(const Duration(days: 30)),
      firstDate: DateTime(2000),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.textPrimary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(exportProvider.notifier).setSinceDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final device = session.device;

    if (device == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/discovery');
      });
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted)),
      );
    }

    ref.listen(sessionProvider, (prev, next) {
      if (prev?.syncService != next.syncService) {
        ref.read(exportProvider.notifier).setSyncService(next.syncService);
      }
    });

    final exportState = ref.watch(exportProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, session, device.name),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Connection warning
                        if (session.connectionStatus == ConnectionStatus.disconnected)
                          _buildDisconnectedBanner(),

                        // Data counts - compact 2x2 grid
                        _buildDataCounts(exportState),
                        const SizedBox(height: 12),

                        // Export section - 3 selectors + button
                        _buildExportSection(context, device.name, exportState),

                        // Messages
                        if (exportState.lastExportPath != null || exportState.error != null)
                          const SizedBox(height: 12),
                        if (exportState.lastExportPath != null)
                          _buildSuccessMessage(exportState.lastExportPath!),
                        if (exportState.error != null) _buildErrorMessage(exportState.error!),
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

  Widget _buildHeader(BuildContext context, SessionState session, String deviceName) {
    final isConnected = session.connectionStatus == ConnectionStatus.connected;
    final statusColor = isConnected ? AppColors.accent : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/logo.png', width: 32, height: 32),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PhoneSync',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        deviceName,
                        style: TextStyle(fontSize: 11, color: statusColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _unpair(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Unpair',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Device disconnected',
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
          GestureDetector(
            onTap: () => ref.read(sessionProvider.notifier).retryConnection(),
            child: const Text(
              'Retry',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCounts(ExportState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCountItem(
              'Contacts',
              state.contactsCount ?? 0,
              Icons.contacts_outlined,
              state.contactsCount == null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCountItem(
              'SMS',
              state.smsCount ?? 0,
              Icons.message_outlined,
              state.smsCount == null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCountItem(
              'Calls',
              state.callsCount ?? 0,
              Icons.phone_outlined,
              state.callsCount == null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCountItem(
              'Numbers',
              state.phoneNumbersCount ?? 0,
              Icons.dialpad,
              state.phoneNumbersCount == null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountItem(String label, int count, IconData icon, bool isLoading) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textMuted),
                  )
                else
                  Text(
                    _formatNumber(count),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  Widget _buildExportSection(BuildContext context, String deviceName, ExportState state) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Export status
          if (state.isExporting) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    state.statusMessage,
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ],

          // Data type selectors - 3 columns
          Row(
            children: [
              Expanded(
                child: _buildDataTypeSelector(
                  'Contacts',
                  Icons.contacts_outlined,
                  DataType.contacts,
                  state,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDataTypeSelector('SMS', Icons.message_outlined, DataType.sms, state),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDataTypeSelector('Calls', Icons.phone_outlined, DataType.calls, state),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Settings row - compact
          Row(
            children: [
              // Date filter
              Expanded(
                child: GestureDetector(
                  onTap: state.isExporting ? null : () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            state.sinceDate != null
                                ? 'Since ${dateFormat.format(state.sinceDate!)}'
                                : 'All dates',
                            style: TextStyle(
                              fontSize: 11,
                              color: state.sinceDate != null
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (state.sinceDate != null)
                          GestureDetector(
                            onTap: () => ref.read(exportProvider.notifier).setSinceDate(null),
                            child: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Korean mobile toggle
              GestureDetector(
                onTap: state.isExporting
                    ? null
                    : () => ref
                          .read(exportProvider.notifier)
                          .setKoreanMobileFilter(!state.koreanMobileOnly),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: state.koreanMobileOnly ? AppColors.accentLight : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: state.koreanMobileOnly
                          ? AppColors.accent.withValues(alpha: 0.3)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state.koreanMobileOnly ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 14,
                        color: state.koreanMobileOnly ? AppColors.accent : AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '010 only',
                        style: TextStyle(
                          fontSize: 11,
                          color: state.koreanMobileOnly ? AppColors.accent : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Export button
          GestureDetector(
            onTap: state.isExporting || !state.hasAnySelected
                ? null
                : () => ref.read(exportProvider.notifier).exportSelected(deviceName),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: state.isExporting || !state.hasAnySelected
                    ? AppColors.surfaceAlt
                    : AppColors.accent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.file_download_outlined,
                    size: 18,
                    color: state.isExporting || !state.hasAnySelected
                        ? AppColors.textMuted
                        : Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Export to Excel',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: state.isExporting || !state.hasAnySelected
                          ? AppColors.textMuted
                          : Colors.white,
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

  Widget _buildDataTypeSelector(String label, IconData icon, DataType type, ExportState state) {
    final isSelected = state.selectedTypes.contains(type);

    return GestureDetector(
      onTap: state.isExporting
          ? null
          : () => ref.read(exportProvider.notifier).toggleDataType(type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.textPrimary : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? AppColors.textPrimary : AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: isSelected ? Colors.white : AppColors.textMuted),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessMessage(String path) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _openExportedFile(path),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  'Exported: $path',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.accent,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.accent,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _openExportedFile(path),
            child: const MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Icon(Icons.open_in_new, size: 14, color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openExportedFile(String path) async {
    final uri = Uri.file(path);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback: try to open the containing folder
      final file = File(path);
      final dir = file.parent;
      final dirUri = Uri.file(dir.path);
      if (await canLaunchUrl(dirUri)) {
        await launchUrl(dirUri);
      }
    }
  }

  Widget _buildErrorMessage(String error) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(error, style: const TextStyle(fontSize: 11, color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
