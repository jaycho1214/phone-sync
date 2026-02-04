import 'dart:io';
import 'dart:isolate';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

/// Service for exporting phone entries to Excel.
/// Runs in isolate to prevent UI freeze on large datasets.
class ExportService {
  /// Export phone entries to Excel file.
  /// Runs in isolate for 50k+ rows performance.
  Future<void> exportToExcel({
    required List<Map<String, dynamic>> entries,
    required String filePath,
  }) async {
    // Run in isolate for large datasets
    await Isolate.run(() {
      final excel = Excel.createExcel();
      final sheet = excel['Phone Numbers'];

      // Header row
      sheet.appendRow([
        TextCellValue('Phone Number'),
        TextCellValue('Name'),
        TextCellValue('Sources'),
        TextCellValue('First Seen'),
        TextCellValue('Last Seen'),
      ]);

      // Data rows
      for (final entry in entries) {
        final firstSeen = entry['firstSeen'] as int?;
        final lastSeen = entry['lastSeen'] as int?;

        sheet.appendRow([
          TextCellValue(entry['phoneNumber'] as String),
          TextCellValue(entry['displayName'] as String? ?? ''),
          TextCellValue(entry['sourceTypes'] as String),
          firstSeen != null
              ? DateTimeCellValue.fromDateTime(
                  DateTime.fromMillisecondsSinceEpoch(firstSeen))
              : TextCellValue(''),
          lastSeen != null
              ? DateTimeCellValue.fromDateTime(
                  DateTime.fromMillisecondsSinceEpoch(lastSeen))
              : TextCellValue(''),
        ]);
      }

      // Remove default Sheet1
      excel.delete('Sheet1');

      // Save
      final bytes = excel.save()!;
      File(filePath).writeAsBytesSync(bytes);
    });
  }

  /// Generate filename: {DeviceName}_{YYYY-MM-DD}_{HHMMSS}.xlsx
  String generateFilename(String deviceName) {
    final now = DateTime.now();
    final date = DateFormat('yyyy-MM-dd').format(now);
    final time = DateFormat('HHmmss').format(now);
    // Remove special characters from device name
    final safeName = deviceName.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    return '${safeName}_${date}_$time.xlsx';
  }
}
