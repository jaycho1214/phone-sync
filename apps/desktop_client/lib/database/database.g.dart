// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PhoneEntriesTable extends PhoneEntries
    with TableInfo<$PhoneEntriesTable, PhoneEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhoneEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _phoneNumberMeta = const VerificationMeta(
    'phoneNumber',
  );
  @override
  late final GeneratedColumn<String> phoneNumber = GeneratedColumn<String>(
    'phone_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceTypesMeta = const VerificationMeta(
    'sourceTypes',
  );
  @override
  late final GeneratedColumn<String> sourceTypes = GeneratedColumn<String>(
    'source_types',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstSeenMeta = const VerificationMeta(
    'firstSeen',
  );
  @override
  late final GeneratedColumn<int> firstSeen = GeneratedColumn<int>(
    'first_seen',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<int> lastSeen = GeneratedColumn<int>(
    'last_seen',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawNumbersMeta = const VerificationMeta(
    'rawNumbers',
  );
  @override
  late final GeneratedColumn<String> rawNumbers = GeneratedColumn<String>(
    'raw_numbers',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    phoneNumber,
    displayName,
    sourceTypes,
    firstSeen,
    lastSeen,
    rawNumbers,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'phone_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhoneEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('phone_number')) {
      context.handle(
        _phoneNumberMeta,
        phoneNumber.isAcceptableOrUnknown(
          data['phone_number']!,
          _phoneNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_phoneNumberMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('source_types')) {
      context.handle(
        _sourceTypesMeta,
        sourceTypes.isAcceptableOrUnknown(
          data['source_types']!,
          _sourceTypesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceTypesMeta);
    }
    if (data.containsKey('first_seen')) {
      context.handle(
        _firstSeenMeta,
        firstSeen.isAcceptableOrUnknown(data['first_seen']!, _firstSeenMeta),
      );
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    }
    if (data.containsKey('raw_numbers')) {
      context.handle(
        _rawNumbersMeta,
        rawNumbers.isAcceptableOrUnknown(data['raw_numbers']!, _rawNumbersMeta),
      );
    } else if (isInserting) {
      context.missing(_rawNumbersMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {phoneNumber};
  @override
  PhoneEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhoneEntry(
      phoneNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone_number'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      sourceTypes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_types'],
      )!,
      firstSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_seen'],
      ),
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen'],
      ),
      rawNumbers: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_numbers'],
      )!,
    );
  }

  @override
  $PhoneEntriesTable createAlias(String alias) {
    return $PhoneEntriesTable(attachedDatabase, alias);
  }
}

class PhoneEntry extends DataClass implements Insertable<PhoneEntry> {
  /// Normalized phone number - primary key
  /// Korean: digits only (e.g., "01012345678")
  /// International: E.164 format (e.g., "+15551234567")
  final String phoneNumber;

  /// Contact name if available (from contacts or call log)
  final String? displayName;

  /// JSON array of sources: ["contact", "sms", "call"]
  final String sourceTypes;

  /// Earliest timestamp from all sources (milliseconds)
  final int? firstSeen;

  /// Latest timestamp from all sources (milliseconds)
  final int? lastSeen;

  /// JSON array of original raw number formats for debugging
  final String rawNumbers;
  const PhoneEntry({
    required this.phoneNumber,
    this.displayName,
    required this.sourceTypes,
    this.firstSeen,
    this.lastSeen,
    required this.rawNumbers,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['phone_number'] = Variable<String>(phoneNumber);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['source_types'] = Variable<String>(sourceTypes);
    if (!nullToAbsent || firstSeen != null) {
      map['first_seen'] = Variable<int>(firstSeen);
    }
    if (!nullToAbsent || lastSeen != null) {
      map['last_seen'] = Variable<int>(lastSeen);
    }
    map['raw_numbers'] = Variable<String>(rawNumbers);
    return map;
  }

  PhoneEntriesCompanion toCompanion(bool nullToAbsent) {
    return PhoneEntriesCompanion(
      phoneNumber: Value(phoneNumber),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      sourceTypes: Value(sourceTypes),
      firstSeen: firstSeen == null && nullToAbsent
          ? const Value.absent()
          : Value(firstSeen),
      lastSeen: lastSeen == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeen),
      rawNumbers: Value(rawNumbers),
    );
  }

  factory PhoneEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhoneEntry(
      phoneNumber: serializer.fromJson<String>(json['phoneNumber']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      sourceTypes: serializer.fromJson<String>(json['sourceTypes']),
      firstSeen: serializer.fromJson<int?>(json['firstSeen']),
      lastSeen: serializer.fromJson<int?>(json['lastSeen']),
      rawNumbers: serializer.fromJson<String>(json['rawNumbers']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'phoneNumber': serializer.toJson<String>(phoneNumber),
      'displayName': serializer.toJson<String?>(displayName),
      'sourceTypes': serializer.toJson<String>(sourceTypes),
      'firstSeen': serializer.toJson<int?>(firstSeen),
      'lastSeen': serializer.toJson<int?>(lastSeen),
      'rawNumbers': serializer.toJson<String>(rawNumbers),
    };
  }

  PhoneEntry copyWith({
    String? phoneNumber,
    Value<String?> displayName = const Value.absent(),
    String? sourceTypes,
    Value<int?> firstSeen = const Value.absent(),
    Value<int?> lastSeen = const Value.absent(),
    String? rawNumbers,
  }) => PhoneEntry(
    phoneNumber: phoneNumber ?? this.phoneNumber,
    displayName: displayName.present ? displayName.value : this.displayName,
    sourceTypes: sourceTypes ?? this.sourceTypes,
    firstSeen: firstSeen.present ? firstSeen.value : this.firstSeen,
    lastSeen: lastSeen.present ? lastSeen.value : this.lastSeen,
    rawNumbers: rawNumbers ?? this.rawNumbers,
  );
  PhoneEntry copyWithCompanion(PhoneEntriesCompanion data) {
    return PhoneEntry(
      phoneNumber: data.phoneNumber.present
          ? data.phoneNumber.value
          : this.phoneNumber,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      sourceTypes: data.sourceTypes.present
          ? data.sourceTypes.value
          : this.sourceTypes,
      firstSeen: data.firstSeen.present ? data.firstSeen.value : this.firstSeen,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      rawNumbers: data.rawNumbers.present
          ? data.rawNumbers.value
          : this.rawNumbers,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhoneEntry(')
          ..write('phoneNumber: $phoneNumber, ')
          ..write('displayName: $displayName, ')
          ..write('sourceTypes: $sourceTypes, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('rawNumbers: $rawNumbers')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    phoneNumber,
    displayName,
    sourceTypes,
    firstSeen,
    lastSeen,
    rawNumbers,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhoneEntry &&
          other.phoneNumber == this.phoneNumber &&
          other.displayName == this.displayName &&
          other.sourceTypes == this.sourceTypes &&
          other.firstSeen == this.firstSeen &&
          other.lastSeen == this.lastSeen &&
          other.rawNumbers == this.rawNumbers);
}

class PhoneEntriesCompanion extends UpdateCompanion<PhoneEntry> {
  final Value<String> phoneNumber;
  final Value<String?> displayName;
  final Value<String> sourceTypes;
  final Value<int?> firstSeen;
  final Value<int?> lastSeen;
  final Value<String> rawNumbers;
  final Value<int> rowid;
  const PhoneEntriesCompanion({
    this.phoneNumber = const Value.absent(),
    this.displayName = const Value.absent(),
    this.sourceTypes = const Value.absent(),
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.rawNumbers = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhoneEntriesCompanion.insert({
    required String phoneNumber,
    this.displayName = const Value.absent(),
    required String sourceTypes,
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
    required String rawNumbers,
    this.rowid = const Value.absent(),
  }) : phoneNumber = Value(phoneNumber),
       sourceTypes = Value(sourceTypes),
       rawNumbers = Value(rawNumbers);
  static Insertable<PhoneEntry> custom({
    Expression<String>? phoneNumber,
    Expression<String>? displayName,
    Expression<String>? sourceTypes,
    Expression<int>? firstSeen,
    Expression<int>? lastSeen,
    Expression<String>? rawNumbers,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (displayName != null) 'display_name': displayName,
      if (sourceTypes != null) 'source_types': sourceTypes,
      if (firstSeen != null) 'first_seen': firstSeen,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (rawNumbers != null) 'raw_numbers': rawNumbers,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhoneEntriesCompanion copyWith({
    Value<String>? phoneNumber,
    Value<String?>? displayName,
    Value<String>? sourceTypes,
    Value<int?>? firstSeen,
    Value<int?>? lastSeen,
    Value<String>? rawNumbers,
    Value<int>? rowid,
  }) {
    return PhoneEntriesCompanion(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      sourceTypes: sourceTypes ?? this.sourceTypes,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      rawNumbers: rawNumbers ?? this.rawNumbers,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (phoneNumber.present) {
      map['phone_number'] = Variable<String>(phoneNumber.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (sourceTypes.present) {
      map['source_types'] = Variable<String>(sourceTypes.value);
    }
    if (firstSeen.present) {
      map['first_seen'] = Variable<int>(firstSeen.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<int>(lastSeen.value);
    }
    if (rawNumbers.present) {
      map['raw_numbers'] = Variable<String>(rawNumbers.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhoneEntriesCompanion(')
          ..write('phoneNumber: $phoneNumber, ')
          ..write('displayName: $displayName, ')
          ..write('sourceTypes: $sourceTypes, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('rawNumbers: $rawNumbers, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMetadataTable extends SyncMetadata
    with TableInfo<$SyncMetadataTable, SyncMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetadataData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncMetadataTable createAlias(String alias) {
    return $SyncMetadataTable(attachedDatabase, alias);
  }
}

class SyncMetadataData extends DataClass
    implements Insertable<SyncMetadataData> {
  final String key;
  final String value;
  const SyncMetadataData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncMetadataCompanion toCompanion(bool nullToAbsent) {
    return SyncMetadataCompanion(key: Value(key), value: Value(value));
  }

  factory SyncMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetadataData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncMetadataData copyWith({String? key, String? value}) =>
      SyncMetadataData(key: key ?? this.key, value: value ?? this.value);
  SyncMetadataData copyWithCompanion(SyncMetadataCompanion data) {
    return SyncMetadataData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetadataData &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncMetadataCompanion extends UpdateCompanion<SyncMetadataData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncMetadataData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PhoneEntriesTable phoneEntries = $PhoneEntriesTable(this);
  late final $SyncMetadataTable syncMetadata = $SyncMetadataTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    phoneEntries,
    syncMetadata,
  ];
}

typedef $$PhoneEntriesTableCreateCompanionBuilder =
    PhoneEntriesCompanion Function({
      required String phoneNumber,
      Value<String?> displayName,
      required String sourceTypes,
      Value<int?> firstSeen,
      Value<int?> lastSeen,
      required String rawNumbers,
      Value<int> rowid,
    });
typedef $$PhoneEntriesTableUpdateCompanionBuilder =
    PhoneEntriesCompanion Function({
      Value<String> phoneNumber,
      Value<String?> displayName,
      Value<String> sourceTypes,
      Value<int?> firstSeen,
      Value<int?> lastSeen,
      Value<String> rawNumbers,
      Value<int> rowid,
    });

class $$PhoneEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $PhoneEntriesTable> {
  $$PhoneEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get phoneNumber => $composableBuilder(
    column: $table.phoneNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTypes => $composableBuilder(
    column: $table.sourceTypes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawNumbers => $composableBuilder(
    column: $table.rawNumbers,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PhoneEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PhoneEntriesTable> {
  $$PhoneEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get phoneNumber => $composableBuilder(
    column: $table.phoneNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTypes => $composableBuilder(
    column: $table.sourceTypes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawNumbers => $composableBuilder(
    column: $table.rawNumbers,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhoneEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhoneEntriesTable> {
  $$PhoneEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get phoneNumber => $composableBuilder(
    column: $table.phoneNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceTypes => $composableBuilder(
    column: $table.sourceTypes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get firstSeen =>
      $composableBuilder(column: $table.firstSeen, builder: (column) => column);

  GeneratedColumn<int> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<String> get rawNumbers => $composableBuilder(
    column: $table.rawNumbers,
    builder: (column) => column,
  );
}

class $$PhoneEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhoneEntriesTable,
          PhoneEntry,
          $$PhoneEntriesTableFilterComposer,
          $$PhoneEntriesTableOrderingComposer,
          $$PhoneEntriesTableAnnotationComposer,
          $$PhoneEntriesTableCreateCompanionBuilder,
          $$PhoneEntriesTableUpdateCompanionBuilder,
          (
            PhoneEntry,
            BaseReferences<_$AppDatabase, $PhoneEntriesTable, PhoneEntry>,
          ),
          PhoneEntry,
          PrefetchHooks Function()
        > {
  $$PhoneEntriesTableTableManager(_$AppDatabase db, $PhoneEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhoneEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhoneEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhoneEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> phoneNumber = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String> sourceTypes = const Value.absent(),
                Value<int?> firstSeen = const Value.absent(),
                Value<int?> lastSeen = const Value.absent(),
                Value<String> rawNumbers = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhoneEntriesCompanion(
                phoneNumber: phoneNumber,
                displayName: displayName,
                sourceTypes: sourceTypes,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                rawNumbers: rawNumbers,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String phoneNumber,
                Value<String?> displayName = const Value.absent(),
                required String sourceTypes,
                Value<int?> firstSeen = const Value.absent(),
                Value<int?> lastSeen = const Value.absent(),
                required String rawNumbers,
                Value<int> rowid = const Value.absent(),
              }) => PhoneEntriesCompanion.insert(
                phoneNumber: phoneNumber,
                displayName: displayName,
                sourceTypes: sourceTypes,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                rawNumbers: rawNumbers,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PhoneEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhoneEntriesTable,
      PhoneEntry,
      $$PhoneEntriesTableFilterComposer,
      $$PhoneEntriesTableOrderingComposer,
      $$PhoneEntriesTableAnnotationComposer,
      $$PhoneEntriesTableCreateCompanionBuilder,
      $$PhoneEntriesTableUpdateCompanionBuilder,
      (
        PhoneEntry,
        BaseReferences<_$AppDatabase, $PhoneEntriesTable, PhoneEntry>,
      ),
      PhoneEntry,
      PrefetchHooks Function()
    >;
typedef $$SyncMetadataTableCreateCompanionBuilder =
    SyncMetadataCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SyncMetadataTableUpdateCompanionBuilder =
    SyncMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SyncMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetadataTable,
          SyncMetadataData,
          $$SyncMetadataTableFilterComposer,
          $$SyncMetadataTableOrderingComposer,
          $$SyncMetadataTableAnnotationComposer,
          $$SyncMetadataTableCreateCompanionBuilder,
          $$SyncMetadataTableUpdateCompanionBuilder,
          (
            SyncMetadataData,
            BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>,
          ),
          SyncMetadataData,
          PrefetchHooks Function()
        > {
  $$SyncMetadataTableTableManager(_$AppDatabase db, $SyncMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetadataTable,
      SyncMetadataData,
      $$SyncMetadataTableFilterComposer,
      $$SyncMetadataTableOrderingComposer,
      $$SyncMetadataTableAnnotationComposer,
      $$SyncMetadataTableCreateCompanionBuilder,
      $$SyncMetadataTableUpdateCompanionBuilder,
      (
        SyncMetadataData,
        BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>,
      ),
      SyncMetadataData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PhoneEntriesTableTableManager get phoneEntries =>
      $$PhoneEntriesTableTableManager(_db, _db.phoneEntries);
  $$SyncMetadataTableTableManager get syncMetadata =>
      $$SyncMetadataTableTableManager(_db, _db.syncMetadata);
}
