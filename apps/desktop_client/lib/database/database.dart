import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables.dart';

part 'database.g.dart';

/// Main application database using Drift.
/// Stores phone entries and sync metadata.
@DriftDatabase(tables: [PhoneEntries, SyncMetadata])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing - accepts a custom query executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      // Apply platform-specific workarounds for sqlite3
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();

      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'phonesync.db'));

      // Run in background isolate for performance with large datasets
      return NativeDatabase.createInBackground(file);
    });
  }
}
