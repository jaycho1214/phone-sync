import 'package:flutter/material.dart';

/// Widget displaying sync progress with phase name and count.
class SyncProgress extends StatelessWidget {
  final String phase;
  final int currentCount;
  final int totalCount;

  const SyncProgress({
    super.key,
    required this.phase,
    required this.currentCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final phaseName = phase[0].toUpperCase() + phase.substring(1);
    final progress = totalCount > 0 ? currentCount / totalCount : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Syncing $phaseName... $currentCount / $totalCount',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
