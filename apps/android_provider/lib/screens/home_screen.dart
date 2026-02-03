import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/permission_provider.dart';
import '../providers/extraction_provider.dart';
import '../providers/sync_state_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Check permissions and load sync state on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(permissionProvider.notifier).checkPermissions();
      ref.read(syncStateProvider.notifier).loadSyncState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionProvider);
    final extraction = ref.watch(extractionProvider);
    final syncState = ref.watch(syncStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PhoneSync'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Permission Status Section
            _buildSectionHeader('Permission Status'),
            _buildPermissionRow('Contacts', permissions.contacts),
            _buildPermissionRow('SMS', permissions.sms),
            _buildPermissionRow('Call Log', permissions.callLog),

            if (permissions.permanentlyDeniedNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () =>
                    ref.read(permissionProvider.notifier).openSettings(),
                icon: const Icon(Icons.settings),
                label: Text(
                  'Open Settings to enable: ${permissions.permanentlyDeniedNames.join(", ")}',
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Request Permissions Button
            if (!permissions.hasAnyGranted && !permissions.isLoading)
              ElevatedButton.icon(
                onPressed: () async {
                  await ref
                      .read(permissionProvider.notifier)
                      .requestAllPermissions();
                  // Refresh counts after permissions granted
                  final newPerms = ref.read(permissionProvider);
                  await ref.read(extractionProvider.notifier).refreshCounts(
                        hasContacts: newPerms.contacts.isGranted,
                        hasSms: newPerms.sms.isGranted,
                        hasCallLog: newPerms.callLog.isGranted,
                      );
                },
                icon: const Icon(Icons.security),
                label: const Text('Request Permissions'),
              ),

            const SizedBox(height: 24),

            // Data Counts Section
            _buildSectionHeader('Available Data'),
            if (extraction.isLoading)
              const LinearProgressIndicator()
            else ...[
              _buildCountRow(
                'Contacts',
                permissions.contacts.isGranted ? extraction.contactCount : null,
                !permissions.contacts.isGranted,
              ),
              _buildCountRow(
                'SMS',
                permissions.sms.isGranted ? extraction.smsCount : null,
                !permissions.sms.isGranted,
              ),
              _buildCountRow(
                'Call Log',
                permissions.callLog.isGranted ? extraction.callLogCount : null,
                !permissions.callLog.isGranted,
              ),
              const Divider(),
              _buildCountRow('Total', extraction.totalCount, false),
            ],

            const SizedBox(height: 24),

            // Last Sync Section
            _buildSectionHeader('Sync Status'),
            Text('Contacts: ${syncState.formatLastSync(syncState.contactsLastSync)}'),
            Text('SMS: ${syncState.formatLastSync(syncState.smsLastSync)}'),
            Text('Call Log: ${syncState.formatLastSync(syncState.callLogLastSync)}'),

            const Spacer(),

            // Refresh Button
            if (permissions.hasAnyGranted)
              Center(
                child: ElevatedButton.icon(
                  onPressed: extraction.isLoading
                      ? null
                      : () => ref.read(extractionProvider.notifier).refreshCounts(
                            hasContacts: permissions.contacts.isGranted,
                            hasSms: permissions.sms.isGranted,
                            hasCallLog: permissions.callLog.isGranted,
                          ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Counts'),
                ),
              ),

            // Error display
            if (extraction.error != null || permissions.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  extraction.error ?? permissions.error ?? '',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),

            // Sync progress (shown when desktop is pulling)
            if (extraction.currentOperation != null) ...[
              const SizedBox(height: 16),
              Text('${extraction.currentOperation}: ${(extraction.progress * 100).toInt()}%'),
              LinearProgressIndicator(value: extraction.progress),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildPermissionRow(String name, PermissionStatus status) {
    final color = status.isGranted
        ? Colors.green
        : status.isPermanentlyDenied
            ? Colors.red
            : Colors.orange;
    final icon = status.isGranted
        ? Icons.check_circle
        : status.isPermanentlyDenied
            ? Icons.block
            : Icons.warning;
    final label = status.isGranted
        ? 'Granted'
        : status.isPermanentlyDenied
            ? 'Denied (Settings)'
            : 'Not Granted';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(name),
          const Spacer(),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _buildCountRow(String name, int? count, bool noPermission) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(name),
          const Spacer(),
          Text(
            noPermission ? 'N/A' : count?.toString() ?? '...',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: noPermission ? Colors.grey : null,
            ),
          ),
        ],
      ),
    );
  }
}
