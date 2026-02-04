import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';

/// Repository for phone entry operations.
/// Handles deduplication and merging of entries from multiple sources.
class PhoneRepository {
  final AppDatabase _db;

  PhoneRepository(this._db);

  /// Upsert a phone entry with deduplication.
  /// On conflict: merges sources, updates timestamps, appends raw numbers.
  Future<void> upsertPhoneEntry({
    required String normalizedNumber,
    String? displayName,
    required String source,
    int? timestamp,
    required String rawNumber,
  }) async {
    // Try to get existing entry
    final existing = await (_db.select(_db.phoneEntries)
          ..where((t) => t.phoneNumber.equals(normalizedNumber)))
        .getSingleOrNull();

    if (existing != null) {
      // Merge with existing entry
      final existingSources =
          (jsonDecode(existing.sourceTypes) as List).cast<String>();
      final existingRawNumbers =
          (jsonDecode(existing.rawNumbers) as List).cast<String>();

      // Add source if not already present
      if (!existingSources.contains(source)) {
        existingSources.add(source);
      }

      // Add raw number if not already present
      if (!existingRawNumbers.contains(rawNumber)) {
        existingRawNumbers.add(rawNumber);
      }

      // Update timestamps (min firstSeen, max lastSeen)
      final newFirstSeen = timestamp != null && existing.firstSeen != null
          ? (timestamp < existing.firstSeen! ? timestamp : existing.firstSeen)
          : timestamp ?? existing.firstSeen;
      final newLastSeen = timestamp != null && existing.lastSeen != null
          ? (timestamp > existing.lastSeen! ? timestamp : existing.lastSeen)
          : timestamp ?? existing.lastSeen;

      // Prefer non-null name
      final newName = displayName ?? existing.displayName;

      await (_db.update(_db.phoneEntries)
            ..where((t) => t.phoneNumber.equals(normalizedNumber)))
          .write(PhoneEntriesCompanion(
        displayName: Value(newName),
        sourceTypes: Value(jsonEncode(existingSources)),
        firstSeen: Value(newFirstSeen),
        lastSeen: Value(newLastSeen),
        rawNumbers: Value(jsonEncode(existingRawNumbers)),
      ));
    } else {
      // Insert new entry
      await _db.into(_db.phoneEntries).insert(PhoneEntriesCompanion.insert(
            phoneNumber: normalizedNumber,
            displayName: Value(displayName),
            sourceTypes: jsonEncode([source]),
            firstSeen: Value(timestamp),
            lastSeen: Value(timestamp),
            rawNumbers: jsonEncode([rawNumber]),
          ));
    }
  }

  /// Get all phone entries, optionally filtered to Korean mobile only.
  Future<List<PhoneEntry>> getAllEntries({bool koreanMobileOnly = true}) async {
    if (koreanMobileOnly) {
      // Korean mobile numbers start with 010 (digits-only format)
      return (_db.select(_db.phoneEntries)
            ..where((t) => t.phoneNumber.like('010%')))
          .get();
    }
    return _db.select(_db.phoneEntries).get();
  }

  /// Get the count of phone entries.
  Future<int> getEntryCount({bool koreanMobileOnly = true}) async {
    final countExp = _db.phoneEntries.phoneNumber.count();

    if (koreanMobileOnly) {
      final query = _db.selectOnly(_db.phoneEntries)
        ..addColumns([countExp])
        ..where(_db.phoneEntries.phoneNumber.like('010%'));
      final result = await query.getSingle();
      return result.read(countExp) ?? 0;
    }

    final query = _db.selectOnly(_db.phoneEntries)..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  /// Clear all phone entries (for re-sync).
  Future<void> clearAllEntries() async {
    await _db.delete(_db.phoneEntries).go();
    // Also clear sync timestamps
    await _db.delete(_db.syncMetadata).go();
  }

  /// Get a sync metadata value.
  Future<String?> getSyncTimestamp(String key) async {
    final result = await (_db.select(_db.syncMetadata)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return result?.value;
  }

  /// Set a sync metadata value.
  Future<void> setSyncTimestamp(String key, String value) async {
    await _db.into(_db.syncMetadata).insertOnConflictUpdate(
          SyncMetadataCompanion.insert(key: key, value: value),
        );
  }

  /// Dispose (no-op, database manages its own lifecycle).
  void dispose() {
    // Database is managed by the app lifecycle
  }
}
