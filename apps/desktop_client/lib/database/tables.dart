import 'package:drift/drift.dart';

/// Phone entries table - stores normalized phone numbers with metadata.
/// Primary key is the normalized phone number (digits-only for Korean, E.164 for international).
class PhoneEntries extends Table {
  /// Normalized phone number - primary key
  /// Korean: digits only (e.g., "01012345678")
  /// International: E.164 format (e.g., "+15551234567")
  TextColumn get phoneNumber => text()();

  /// Contact name if available (from contacts or call log)
  TextColumn get displayName => text().nullable()();

  /// JSON array of sources: ["contact", "sms", "call"]
  TextColumn get sourceTypes => text()();

  /// Earliest timestamp from all sources (milliseconds)
  IntColumn get firstSeen => integer().nullable()();

  /// Latest timestamp from all sources (milliseconds)
  IntColumn get lastSeen => integer().nullable()();

  /// JSON array of original raw number formats for debugging
  TextColumn get rawNumbers => text()();

  @override
  Set<Column> get primaryKey => {phoneNumber};
}

/// Sync metadata table - stores sync timestamps and other metadata.
class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
