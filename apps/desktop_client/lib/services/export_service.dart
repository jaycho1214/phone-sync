import 'dart:io';
import 'dart:isolate';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import 'phone_normalizer.dart';

/// Service for exporting phone data to Excel.
/// Runs in isolate to prevent UI freeze on large datasets.
class ExportService {
  /// Export data to Excel file with separate sheets for each data type.
  /// Runs in isolate for performance.
  Future<void> exportDataToExcel({
    List<Map<String, dynamic>>? contacts,
    List<Map<String, dynamic>>? smsMessages,
    List<Map<String, dynamic>>? callLogs,
    required String filePath,
    required bool koreanMobileOnly,
    DateTime? sinceDate,
    required String deviceName,
  }) async {
    final exportTime = DateTime.now();
    final sinceDateMs = sinceDate?.millisecondsSinceEpoch;

    await Isolate.run(() {
      final excel = Excel.createExcel();
      final normalizer = PhoneNormalizer();

      // Export summary sheet first
      _exportSummarySheet(
        excel,
        deviceName: deviceName,
        exportTime: exportTime,
        sinceDate: sinceDateMs != null ? DateTime.fromMillisecondsSinceEpoch(sinceDateMs) : null,
        koreanMobileOnly: koreanMobileOnly,
        contactsCount: contacts?.length ?? 0,
        smsCount: smsMessages?.length ?? 0,
        callsCount: callLogs?.length ?? 0,
      );

      // Build contact lookup map (normalized phone -> name)
      final contactLookup = _buildContactLookup(contacts, normalizer);

      // Export contacts sheet
      if (contacts != null && contacts.isNotEmpty) {
        _exportContactsSheet(excel, contacts, normalizer, koreanMobileOnly);
      }

      // Export SMS sheet
      if (smsMessages != null && smsMessages.isNotEmpty) {
        _exportSmsSheet(excel, smsMessages, normalizer, koreanMobileOnly, contactLookup);
      }

      // Export calls sheet
      if (callLogs != null && callLogs.isNotEmpty) {
        _exportCallsSheet(excel, callLogs, normalizer, koreanMobileOnly, contactLookup);
      }

      // Export All Numbers sheet (deduplicated from all sources)
      _exportAllNumbersSheet(
        excel,
        contacts,
        smsMessages,
        callLogs,
        normalizer,
        koreanMobileOnly,
        contactLookup,
      );

      // Remove default Sheet1
      excel.delete('Sheet1');

      // Save
      final bytes = excel.save()!;
      File(filePath).writeAsBytesSync(bytes);
    });
  }

  /// Generate filename: {DeviceName}_{Suffix}_{YYYY-MM-DD}_{HHMMSS}.xlsx
  String generateFilename(String deviceName, String suffix) {
    final now = DateTime.now();
    final date = DateFormat('yyyy-MM-dd').format(now);
    final time = DateFormat('HHmmss').format(now);
    // Remove special characters from device name
    final safeName = deviceName.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    return '${safeName}_${suffix}_${date}_$time.xlsx';
  }
}

/// Build a lookup map from normalized phone number to contact name.
Map<String, String> _buildContactLookup(
  List<Map<String, dynamic>>? contacts,
  PhoneNormalizer normalizer,
) {
  final lookup = <String, String>{};
  if (contacts == null) return lookup;

  for (final contact in contacts) {
    final name = contact['displayName'] as String? ?? '';
    if (name.isEmpty) continue;

    final phones = contact['phones'] as List<dynamic>?;
    if (phones != null) {
      for (final phone in phones) {
        final rawNumber = phone['number'] as String?;
        if (rawNumber != null) {
          final normalized = normalizer.normalize(rawNumber);
          if (normalized != null && !lookup.containsKey(normalized)) {
            lookup[normalized] = name;
          }
        }
      }
    }
  }
  return lookup;
}

void _exportSummarySheet(
  Excel excel, {
  required String deviceName,
  required DateTime exportTime,
  DateTime? sinceDate,
  required bool koreanMobileOnly,
  required int contactsCount,
  required int smsCount,
  required int callsCount,
}) {
  final sheet = excel['Summary'];
  final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  // Title
  sheet.appendRow([TextCellValue('PhoneSync Export Summary')]);
  sheet.appendRow([TextCellValue('')]);

  // Device info
  sheet.appendRow([TextCellValue('Device'), TextCellValue(deviceName)]);
  sheet.appendRow([TextCellValue('Export Date'), TextCellValue(dateFormat.format(exportTime))]);
  sheet.appendRow([TextCellValue('')]);

  // Filters
  sheet.appendRow([TextCellValue('Filters')]);
  sheet.appendRow([
    TextCellValue('Date Filter'),
    TextCellValue(
      sinceDate != null ? 'Since ${DateFormat('yyyy-MM-dd').format(sinceDate)}' : 'All dates',
    ),
  ]);
  sheet.appendRow([
    TextCellValue('Phone Filter'),
    TextCellValue(koreanMobileOnly ? 'Korean mobile only (010)' : 'All numbers'),
  ]);
  sheet.appendRow([TextCellValue('')]);

  // Counts
  sheet.appendRow([TextCellValue('Record Counts')]);
  sheet.appendRow([TextCellValue('Contacts'), IntCellValue(contactsCount)]);
  sheet.appendRow([TextCellValue('SMS'), IntCellValue(smsCount)]);
  sheet.appendRow([TextCellValue('Calls'), IntCellValue(callsCount)]);
  sheet.appendRow([TextCellValue('Total'), IntCellValue(contactsCount + smsCount + callsCount)]);
}

void _exportContactsSheet(
  Excel excel,
  List<Map<String, dynamic>> contacts,
  PhoneNormalizer normalizer,
  bool koreanMobileOnly,
) {
  final sheet = excel['Contacts'];

  // Header row
  sheet.appendRow([
    TextCellValue('Name'),
    TextCellValue('Phone Number'),
    TextCellValue('Normalized'),
  ]);

  // Flatten contacts (one row per phone number)
  for (final contact in contacts) {
    final name = contact['displayName'] as String? ?? '';
    final phones = contact['phones'] as List<dynamic>?;

    if (phones != null) {
      for (final phone in phones) {
        final rawNumber = phone['number'] as String?;
        if (rawNumber != null) {
          final normalized = normalizer.normalize(rawNumber);

          // Skip if Korean mobile filter is on and number doesn't start with 010
          if (koreanMobileOnly && (normalized == null || !normalized.startsWith('010'))) {
            continue;
          }

          sheet.appendRow([
            TextCellValue(name),
            TextCellValue(rawNumber),
            TextCellValue(normalized ?? rawNumber),
          ]);
        }
      }
    }
  }
}

void _exportSmsSheet(
  Excel excel,
  List<Map<String, dynamic>> messages,
  PhoneNormalizer normalizer,
  bool koreanMobileOnly,
  Map<String, String> contactLookup,
) {
  final sheet = excel['SMS'];

  // Header row - Name and Phone Number first
  sheet.appendRow([
    TextCellValue('Name'),
    TextCellValue('Phone Number'),
    TextCellValue('Normalized'),
    TextCellValue('Date'),
    TextCellValue('Type'),
  ]);

  for (final message in messages) {
    final address = message['address'] as String?;
    final date = message['date'] as int?;
    final type = message['type'] as String?;

    if (address != null) {
      final normalized = normalizer.normalize(address);

      // Skip if Korean mobile filter is on and number doesn't start with 010
      if (koreanMobileOnly && (normalized == null || !normalized.startsWith('010'))) {
        continue;
      }

      // Look up contact name from normalized number
      final name = normalized != null ? (contactLookup[normalized] ?? '') : '';

      sheet.appendRow([
        TextCellValue(name),
        TextCellValue(address),
        TextCellValue(normalized ?? address),
        date != null
            ? DateTimeCellValue.fromDateTime(DateTime.fromMillisecondsSinceEpoch(date))
            : TextCellValue(''),
        TextCellValue(type ?? ''),
      ]);
    }
  }
}

void _exportCallsSheet(
  Excel excel,
  List<Map<String, dynamic>> calls,
  PhoneNormalizer normalizer,
  bool koreanMobileOnly,
  Map<String, String> contactLookup,
) {
  final sheet = excel['Calls'];

  // Header row - Name and Phone Number first
  sheet.appendRow([
    TextCellValue('Name'),
    TextCellValue('Phone Number'),
    TextCellValue('Normalized'),
    TextCellValue('Date'),
    TextCellValue('Type'),
    TextCellValue('Duration (sec)'),
  ]);

  for (final call in calls) {
    final number = call['number'] as String?;
    final callName = call['name'] as String?;
    final timestamp = call['timestamp'] as int?;
    final callType = call['callType'] as String?;
    final duration = call['duration'] as int?;

    if (number != null) {
      final normalized = normalizer.normalize(number);

      // Skip if Korean mobile filter is on and number doesn't start with 010
      if (koreanMobileOnly && (normalized == null || !normalized.startsWith('010'))) {
        continue;
      }

      // Use call's name if available, otherwise look up from contacts
      final name = callName ?? (normalized != null ? (contactLookup[normalized] ?? '') : '');

      sheet.appendRow([
        TextCellValue(name),
        TextCellValue(number),
        TextCellValue(normalized ?? number),
        timestamp != null
            ? DateTimeCellValue.fromDateTime(DateTime.fromMillisecondsSinceEpoch(timestamp))
            : TextCellValue(''),
        TextCellValue(callType ?? ''),
        duration != null ? IntCellValue(duration) : TextCellValue(''),
      ]);
    }
  }
}

/// Export All Numbers sheet with deduplicated phone numbers from all sources.
void _exportAllNumbersSheet(
  Excel excel,
  List<Map<String, dynamic>>? contacts,
  List<Map<String, dynamic>>? smsMessages,
  List<Map<String, dynamic>>? callLogs,
  PhoneNormalizer normalizer,
  bool koreanMobileOnly,
  Map<String, String> contactLookup,
) {
  // Collect all unique normalized numbers with their names
  final allNumbers = <String, String>{}; // normalized -> name

  // From contacts
  if (contacts != null) {
    for (final contact in contacts) {
      final name = contact['displayName'] as String? ?? '';
      final phones = contact['phones'] as List<dynamic>?;

      if (phones != null) {
        for (final phone in phones) {
          final rawNumber = phone['number'] as String?;
          if (rawNumber != null) {
            final normalized = normalizer.normalize(rawNumber);
            if (normalized != null) {
              if (koreanMobileOnly && !normalized.startsWith('010')) continue;
              // Keep first name found for this number
              if (!allNumbers.containsKey(normalized)) {
                allNumbers[normalized] = name;
              }
            }
          }
        }
      }
    }
  }

  // From SMS
  if (smsMessages != null) {
    for (final message in smsMessages) {
      final address = message['address'] as String?;
      if (address != null) {
        final normalized = normalizer.normalize(address);
        if (normalized != null) {
          if (koreanMobileOnly && !normalized.startsWith('010')) continue;
          if (!allNumbers.containsKey(normalized)) {
            allNumbers[normalized] = contactLookup[normalized] ?? '';
          }
        }
      }
    }
  }

  // From calls
  if (callLogs != null) {
    for (final call in callLogs) {
      final number = call['number'] as String?;
      final callName = call['name'] as String?;
      if (number != null) {
        final normalized = normalizer.normalize(number);
        if (normalized != null) {
          if (koreanMobileOnly && !normalized.startsWith('010')) continue;
          if (!allNumbers.containsKey(normalized)) {
            // Use call's name if available, otherwise lookup from contacts
            allNumbers[normalized] = callName ?? (contactLookup[normalized] ?? '');
          }
        }
      }
    }
  }

  // Only create sheet if there are numbers
  if (allNumbers.isEmpty) return;

  final sheet = excel['All Numbers'];

  // Header row
  sheet.appendRow([TextCellValue('Name'), TextCellValue('Phone Number')]);

  // Sort by normalized number for consistent output
  final sortedNumbers = allNumbers.keys.toList()..sort();

  for (final normalized in sortedNumbers) {
    final name = allNumbers[normalized] ?? '';
    sheet.appendRow([TextCellValue(name), TextCellValue(normalized)]);
  }
}
