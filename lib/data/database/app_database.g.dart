// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AcademicYearsTable extends AcademicYears
    with TableInfo<$AcademicYearsTable, AcademicYear> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AcademicYearsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gradeMeta = const VerificationMeta('grade');
  @override
  late final GeneratedColumn<int> grade = GeneratedColumn<int>(
    'grade',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _treasurerNameMeta = const VerificationMeta(
    'treasurerName',
  );
  @override
  late final GeneratedColumn<String> treasurerName = GeneratedColumn<String>(
    'treasurer_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Bendahara'),
  );
  static const VerificationMeta _supervisorNameMeta = const VerificationMeta(
    'supervisorName',
  );
  @override
  late final GeneratedColumn<String> supervisorName = GeneratedColumn<String>(
    'supervisor_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Ibu Pengawas'),
  );
  static const VerificationMeta _defaultDuesAmountMeta = const VerificationMeta(
    'defaultDuesAmount',
  );
  @override
  late final GeneratedColumn<int> defaultDuesAmount = GeneratedColumn<int>(
    'default_dues_amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5000),
  );
  static const VerificationMeta _duesPeriodTypeMeta = const VerificationMeta(
    'duesPeriodType',
  );
  @override
  late final GeneratedColumn<String> duesPeriodType = GeneratedColumn<String>(
    'dues_period_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('weekly'),
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    grade,
    treasurerName,
    supervisorName,
    defaultDuesAmount,
    duesPeriodType,
    startDate,
    endDate,
    isActive,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'academic_years';
  @override
  VerificationContext validateIntegrity(
    Insertable<AcademicYear> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('grade')) {
      context.handle(
        _gradeMeta,
        grade.isAcceptableOrUnknown(data['grade']!, _gradeMeta),
      );
    } else if (isInserting) {
      context.missing(_gradeMeta);
    }
    if (data.containsKey('treasurer_name')) {
      context.handle(
        _treasurerNameMeta,
        treasurerName.isAcceptableOrUnknown(
          data['treasurer_name']!,
          _treasurerNameMeta,
        ),
      );
    }
    if (data.containsKey('supervisor_name')) {
      context.handle(
        _supervisorNameMeta,
        supervisorName.isAcceptableOrUnknown(
          data['supervisor_name']!,
          _supervisorNameMeta,
        ),
      );
    }
    if (data.containsKey('default_dues_amount')) {
      context.handle(
        _defaultDuesAmountMeta,
        defaultDuesAmount.isAcceptableOrUnknown(
          data['default_dues_amount']!,
          _defaultDuesAmountMeta,
        ),
      );
    }
    if (data.containsKey('dues_period_type')) {
      context.handle(
        _duesPeriodTypeMeta,
        duesPeriodType.isAcceptableOrUnknown(
          data['dues_period_type']!,
          _duesPeriodTypeMeta,
        ),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AcademicYear map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AcademicYear(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      grade: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grade'],
      )!,
      treasurerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}treasurer_name'],
      )!,
      supervisorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supervisor_name'],
      )!,
      defaultDuesAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_dues_amount'],
      )!,
      duesPeriodType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dues_period_type'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AcademicYearsTable createAlias(String alias) {
    return $AcademicYearsTable(attachedDatabase, alias);
  }
}

class AcademicYear extends DataClass implements Insertable<AcademicYear> {
  final String id;
  final String name;
  final int grade;
  final String treasurerName;
  final String supervisorName;
  final int defaultDuesAmount;
  final String duesPeriodType;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;
  const AcademicYear({
    required this.id,
    required this.name,
    required this.grade,
    required this.treasurerName,
    required this.supervisorName,
    required this.defaultDuesAmount,
    required this.duesPeriodType,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['grade'] = Variable<int>(grade);
    map['treasurer_name'] = Variable<String>(treasurerName);
    map['supervisor_name'] = Variable<String>(supervisorName);
    map['default_dues_amount'] = Variable<int>(defaultDuesAmount);
    map['dues_period_type'] = Variable<String>(duesPeriodType);
    map['start_date'] = Variable<DateTime>(startDate);
    map['end_date'] = Variable<DateTime>(endDate);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AcademicYearsCompanion toCompanion(bool nullToAbsent) {
    return AcademicYearsCompanion(
      id: Value(id),
      name: Value(name),
      grade: Value(grade),
      treasurerName: Value(treasurerName),
      supervisorName: Value(supervisorName),
      defaultDuesAmount: Value(defaultDuesAmount),
      duesPeriodType: Value(duesPeriodType),
      startDate: Value(startDate),
      endDate: Value(endDate),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
    );
  }

  factory AcademicYear.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AcademicYear(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      grade: serializer.fromJson<int>(json['grade']),
      treasurerName: serializer.fromJson<String>(json['treasurerName']),
      supervisorName: serializer.fromJson<String>(json['supervisorName']),
      defaultDuesAmount: serializer.fromJson<int>(json['defaultDuesAmount']),
      duesPeriodType: serializer.fromJson<String>(json['duesPeriodType']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime>(json['endDate']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'grade': serializer.toJson<int>(grade),
      'treasurerName': serializer.toJson<String>(treasurerName),
      'supervisorName': serializer.toJson<String>(supervisorName),
      'defaultDuesAmount': serializer.toJson<int>(defaultDuesAmount),
      'duesPeriodType': serializer.toJson<String>(duesPeriodType),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime>(endDate),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AcademicYear copyWith({
    String? id,
    String? name,
    int? grade,
    String? treasurerName,
    String? supervisorName,
    int? defaultDuesAmount,
    String? duesPeriodType,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
  }) => AcademicYear(
    id: id ?? this.id,
    name: name ?? this.name,
    grade: grade ?? this.grade,
    treasurerName: treasurerName ?? this.treasurerName,
    supervisorName: supervisorName ?? this.supervisorName,
    defaultDuesAmount: defaultDuesAmount ?? this.defaultDuesAmount,
    duesPeriodType: duesPeriodType ?? this.duesPeriodType,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
  );
  AcademicYear copyWithCompanion(AcademicYearsCompanion data) {
    return AcademicYear(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      grade: data.grade.present ? data.grade.value : this.grade,
      treasurerName: data.treasurerName.present
          ? data.treasurerName.value
          : this.treasurerName,
      supervisorName: data.supervisorName.present
          ? data.supervisorName.value
          : this.supervisorName,
      defaultDuesAmount: data.defaultDuesAmount.present
          ? data.defaultDuesAmount.value
          : this.defaultDuesAmount,
      duesPeriodType: data.duesPeriodType.present
          ? data.duesPeriodType.value
          : this.duesPeriodType,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AcademicYear(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('grade: $grade, ')
          ..write('treasurerName: $treasurerName, ')
          ..write('supervisorName: $supervisorName, ')
          ..write('defaultDuesAmount: $defaultDuesAmount, ')
          ..write('duesPeriodType: $duesPeriodType, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    grade,
    treasurerName,
    supervisorName,
    defaultDuesAmount,
    duesPeriodType,
    startDate,
    endDate,
    isActive,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AcademicYear &&
          other.id == this.id &&
          other.name == this.name &&
          other.grade == this.grade &&
          other.treasurerName == this.treasurerName &&
          other.supervisorName == this.supervisorName &&
          other.defaultDuesAmount == this.defaultDuesAmount &&
          other.duesPeriodType == this.duesPeriodType &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt);
}

class AcademicYearsCompanion extends UpdateCompanion<AcademicYear> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> grade;
  final Value<String> treasurerName;
  final Value<String> supervisorName;
  final Value<int> defaultDuesAmount;
  final Value<String> duesPeriodType;
  final Value<DateTime> startDate;
  final Value<DateTime> endDate;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AcademicYearsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.grade = const Value.absent(),
    this.treasurerName = const Value.absent(),
    this.supervisorName = const Value.absent(),
    this.defaultDuesAmount = const Value.absent(),
    this.duesPeriodType = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AcademicYearsCompanion.insert({
    required String id,
    required String name,
    required int grade,
    this.treasurerName = const Value.absent(),
    this.supervisorName = const Value.absent(),
    this.defaultDuesAmount = const Value.absent(),
    this.duesPeriodType = const Value.absent(),
    required DateTime startDate,
    required DateTime endDate,
    this.isActive = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       grade = Value(grade),
       startDate = Value(startDate),
       endDate = Value(endDate),
       createdAt = Value(createdAt);
  static Insertable<AcademicYear> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? grade,
    Expression<String>? treasurerName,
    Expression<String>? supervisorName,
    Expression<int>? defaultDuesAmount,
    Expression<String>? duesPeriodType,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (grade != null) 'grade': grade,
      if (treasurerName != null) 'treasurer_name': treasurerName,
      if (supervisorName != null) 'supervisor_name': supervisorName,
      if (defaultDuesAmount != null) 'default_dues_amount': defaultDuesAmount,
      if (duesPeriodType != null) 'dues_period_type': duesPeriodType,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AcademicYearsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? grade,
    Value<String>? treasurerName,
    Value<String>? supervisorName,
    Value<int>? defaultDuesAmount,
    Value<String>? duesPeriodType,
    Value<DateTime>? startDate,
    Value<DateTime>? endDate,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AcademicYearsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      grade: grade ?? this.grade,
      treasurerName: treasurerName ?? this.treasurerName,
      supervisorName: supervisorName ?? this.supervisorName,
      defaultDuesAmount: defaultDuesAmount ?? this.defaultDuesAmount,
      duesPeriodType: duesPeriodType ?? this.duesPeriodType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (grade.present) {
      map['grade'] = Variable<int>(grade.value);
    }
    if (treasurerName.present) {
      map['treasurer_name'] = Variable<String>(treasurerName.value);
    }
    if (supervisorName.present) {
      map['supervisor_name'] = Variable<String>(supervisorName.value);
    }
    if (defaultDuesAmount.present) {
      map['default_dues_amount'] = Variable<int>(defaultDuesAmount.value);
    }
    if (duesPeriodType.present) {
      map['dues_period_type'] = Variable<String>(duesPeriodType.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AcademicYearsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('grade: $grade, ')
          ..write('treasurerName: $treasurerName, ')
          ..write('supervisorName: $supervisorName, ')
          ..write('defaultDuesAmount: $defaultDuesAmount, ')
          ..write('duesPeriodType: $duesPeriodType, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudentsTable extends Students with TableInfo<$StudentsTable, Student> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _academicYearIdMeta = const VerificationMeta(
    'academicYearId',
  );
  @override
  late final GeneratedColumn<String> academicYearId = GeneratedColumn<String>(
    'academic_year_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES academic_years (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _attendanceNumberMeta = const VerificationMeta(
    'attendanceNumber',
  );
  @override
  late final GeneratedColumn<int> attendanceNumber = GeneratedColumn<int>(
    'attendance_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    academicYearId,
    attendanceNumber,
    name,
    status,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'students';
  @override
  VerificationContext validateIntegrity(
    Insertable<Student> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('academic_year_id')) {
      context.handle(
        _academicYearIdMeta,
        academicYearId.isAcceptableOrUnknown(
          data['academic_year_id']!,
          _academicYearIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_academicYearIdMeta);
    }
    if (data.containsKey('attendance_number')) {
      context.handle(
        _attendanceNumberMeta,
        attendanceNumber.isAcceptableOrUnknown(
          data['attendance_number']!,
          _attendanceNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attendanceNumberMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Student map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Student(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      academicYearId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}academic_year_id'],
      )!,
      attendanceNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attendance_number'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $StudentsTable createAlias(String alias) {
    return $StudentsTable(attachedDatabase, alias);
  }
}

class Student extends DataClass implements Insertable<Student> {
  final String id;
  final String academicYearId;
  final int attendanceNumber;
  final String name;
  final String status;
  final DateTime createdAt;
  const Student({
    required this.id,
    required this.academicYearId,
    required this.attendanceNumber,
    required this.name,
    required this.status,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['academic_year_id'] = Variable<String>(academicYearId);
    map['attendance_number'] = Variable<int>(attendanceNumber);
    map['name'] = Variable<String>(name);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  StudentsCompanion toCompanion(bool nullToAbsent) {
    return StudentsCompanion(
      id: Value(id),
      academicYearId: Value(academicYearId),
      attendanceNumber: Value(attendanceNumber),
      name: Value(name),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory Student.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Student(
      id: serializer.fromJson<String>(json['id']),
      academicYearId: serializer.fromJson<String>(json['academicYearId']),
      attendanceNumber: serializer.fromJson<int>(json['attendanceNumber']),
      name: serializer.fromJson<String>(json['name']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'academicYearId': serializer.toJson<String>(academicYearId),
      'attendanceNumber': serializer.toJson<int>(attendanceNumber),
      'name': serializer.toJson<String>(name),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Student copyWith({
    String? id,
    String? academicYearId,
    int? attendanceNumber,
    String? name,
    String? status,
    DateTime? createdAt,
  }) => Student(
    id: id ?? this.id,
    academicYearId: academicYearId ?? this.academicYearId,
    attendanceNumber: attendanceNumber ?? this.attendanceNumber,
    name: name ?? this.name,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
  Student copyWithCompanion(StudentsCompanion data) {
    return Student(
      id: data.id.present ? data.id.value : this.id,
      academicYearId: data.academicYearId.present
          ? data.academicYearId.value
          : this.academicYearId,
      attendanceNumber: data.attendanceNumber.present
          ? data.attendanceNumber.value
          : this.attendanceNumber,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Student(')
          ..write('id: $id, ')
          ..write('academicYearId: $academicYearId, ')
          ..write('attendanceNumber: $attendanceNumber, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    academicYearId,
    attendanceNumber,
    name,
    status,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Student &&
          other.id == this.id &&
          other.academicYearId == this.academicYearId &&
          other.attendanceNumber == this.attendanceNumber &&
          other.name == this.name &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class StudentsCompanion extends UpdateCompanion<Student> {
  final Value<String> id;
  final Value<String> academicYearId;
  final Value<int> attendanceNumber;
  final Value<String> name;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const StudentsCompanion({
    this.id = const Value.absent(),
    this.academicYearId = const Value.absent(),
    this.attendanceNumber = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudentsCompanion.insert({
    required String id,
    required String academicYearId,
    required int attendanceNumber,
    required String name,
    this.status = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       academicYearId = Value(academicYearId),
       attendanceNumber = Value(attendanceNumber),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Student> custom({
    Expression<String>? id,
    Expression<String>? academicYearId,
    Expression<int>? attendanceNumber,
    Expression<String>? name,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (academicYearId != null) 'academic_year_id': academicYearId,
      if (attendanceNumber != null) 'attendance_number': attendanceNumber,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudentsCompanion copyWith({
    Value<String>? id,
    Value<String>? academicYearId,
    Value<int>? attendanceNumber,
    Value<String>? name,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return StudentsCompanion(
      id: id ?? this.id,
      academicYearId: academicYearId ?? this.academicYearId,
      attendanceNumber: attendanceNumber ?? this.attendanceNumber,
      name: name ?? this.name,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (academicYearId.present) {
      map['academic_year_id'] = Variable<String>(academicYearId.value);
    }
    if (attendanceNumber.present) {
      map['attendance_number'] = Variable<int>(attendanceNumber.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudentsCompanion(')
          ..write('id: $id, ')
          ..write('academicYearId: $academicYearId, ')
          ..write('attendanceNumber: $attendanceNumber, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconNameMeta = const VerificationMeta(
    'iconName',
  );
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
    'icon_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    name,
    iconName,
    colorHex,
    isDefault,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon_name')) {
      context.handle(
        _iconNameMeta,
        iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta),
      );
    } else if (isInserting) {
      context.missing(_iconNameMeta);
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    } else if (isInserting) {
      context.missing(_colorHexMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      iconName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_name'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final String type;
  final String name;
  final String iconName;
  final String colorHex;
  final bool isDefault;
  final DateTime createdAt;
  const Category({
    required this.id,
    required this.type,
    required this.name,
    required this.iconName,
    required this.colorHex,
    required this.isDefault,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['name'] = Variable<String>(name);
    map['icon_name'] = Variable<String>(iconName);
    map['color_hex'] = Variable<String>(colorHex);
    map['is_default'] = Variable<bool>(isDefault);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      type: Value(type),
      name: Value(name),
      iconName: Value(iconName),
      colorHex: Value(colorHex),
      isDefault: Value(isDefault),
      createdAt: Value(createdAt),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      name: serializer.fromJson<String>(json['name']),
      iconName: serializer.fromJson<String>(json['iconName']),
      colorHex: serializer.fromJson<String>(json['colorHex']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'name': serializer.toJson<String>(name),
      'iconName': serializer.toJson<String>(iconName),
      'colorHex': serializer.toJson<String>(colorHex),
      'isDefault': serializer.toJson<bool>(isDefault),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Category copyWith({
    String? id,
    String? type,
    String? name,
    String? iconName,
    String? colorHex,
    bool? isDefault,
    DateTime? createdAt,
  }) => Category(
    id: id ?? this.id,
    type: type ?? this.type,
    name: name ?? this.name,
    iconName: iconName ?? this.iconName,
    colorHex: colorHex ?? this.colorHex,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt ?? this.createdAt,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('iconName: $iconName, ')
          ..write('colorHex: $colorHex, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, type, name, iconName, colorHex, isDefault, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.type == this.type &&
          other.name == this.name &&
          other.iconName == this.iconName &&
          other.colorHex == this.colorHex &&
          other.isDefault == this.isDefault &&
          other.createdAt == this.createdAt);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> name;
  final Value<String> iconName;
  final Value<String> colorHex;
  final Value<bool> isDefault;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.iconName = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String type,
    required String name,
    required String iconName,
    required String colorHex,
    this.isDefault = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       name = Value(name),
       iconName = Value(iconName),
       colorHex = Value(colorHex),
       createdAt = Value(createdAt);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? name,
    Expression<String>? iconName,
    Expression<String>? colorHex,
    Expression<bool>? isDefault,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (iconName != null) 'icon_name': iconName,
      if (colorHex != null) 'color_hex': colorHex,
      if (isDefault != null) 'is_default': isDefault,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? name,
    Value<String>? iconName,
    Value<String>? colorHex,
    Value<bool>? isDefault,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('iconName: $iconName, ')
          ..write('colorHex: $colorHex, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _academicYearIdMeta = const VerificationMeta(
    'academicYearId',
  );
  @override
  late final GeneratedColumn<String> academicYearId = GeneratedColumn<String>(
    'academic_year_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES academic_years (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receiptImagePathMeta = const VerificationMeta(
    'receiptImagePath',
  );
  @override
  late final GeneratedColumn<String> receiptImagePath = GeneratedColumn<String>(
    'receipt_image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transactionDateMeta = const VerificationMeta(
    'transactionDate',
  );
  @override
  late final GeneratedColumn<DateTime> transactionDate =
      GeneratedColumn<DateTime>(
        'transaction_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    academicYearId,
    categoryId,
    type,
    amount,
    title,
    description,
    receiptImagePath,
    transactionDate,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('academic_year_id')) {
      context.handle(
        _academicYearIdMeta,
        academicYearId.isAcceptableOrUnknown(
          data['academic_year_id']!,
          _academicYearIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_academicYearIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('receipt_image_path')) {
      context.handle(
        _receiptImagePathMeta,
        receiptImagePath.isAcceptableOrUnknown(
          data['receipt_image_path']!,
          _receiptImagePathMeta,
        ),
      );
    }
    if (data.containsKey('transaction_date')) {
      context.handle(
        _transactionDateMeta,
        transactionDate.isAcceptableOrUnknown(
          data['transaction_date']!,
          _transactionDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionDateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      academicYearId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}academic_year_id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      receiptImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_image_path'],
      ),
      transactionDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}transaction_date'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final String id;
  final String academicYearId;
  final String categoryId;
  final String type;
  final int amount;
  final String title;
  final String? description;
  final String? receiptImagePath;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Transaction({
    required this.id,
    required this.academicYearId,
    required this.categoryId,
    required this.type,
    required this.amount,
    required this.title,
    this.description,
    this.receiptImagePath,
    required this.transactionDate,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['academic_year_id'] = Variable<String>(academicYearId);
    map['category_id'] = Variable<String>(categoryId);
    map['type'] = Variable<String>(type);
    map['amount'] = Variable<int>(amount);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || receiptImagePath != null) {
      map['receipt_image_path'] = Variable<String>(receiptImagePath);
    }
    map['transaction_date'] = Variable<DateTime>(transactionDate);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      academicYearId: Value(academicYearId),
      categoryId: Value(categoryId),
      type: Value(type),
      amount: Value(amount),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      receiptImagePath: receiptImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptImagePath),
      transactionDate: Value(transactionDate),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Transaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<String>(json['id']),
      academicYearId: serializer.fromJson<String>(json['academicYearId']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      type: serializer.fromJson<String>(json['type']),
      amount: serializer.fromJson<int>(json['amount']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      receiptImagePath: serializer.fromJson<String?>(json['receiptImagePath']),
      transactionDate: serializer.fromJson<DateTime>(json['transactionDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'academicYearId': serializer.toJson<String>(academicYearId),
      'categoryId': serializer.toJson<String>(categoryId),
      'type': serializer.toJson<String>(type),
      'amount': serializer.toJson<int>(amount),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'receiptImagePath': serializer.toJson<String?>(receiptImagePath),
      'transactionDate': serializer.toJson<DateTime>(transactionDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Transaction copyWith({
    String? id,
    String? academicYearId,
    String? categoryId,
    String? type,
    int? amount,
    String? title,
    Value<String?> description = const Value.absent(),
    Value<String?> receiptImagePath = const Value.absent(),
    DateTime? transactionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Transaction(
    id: id ?? this.id,
    academicYearId: academicYearId ?? this.academicYearId,
    categoryId: categoryId ?? this.categoryId,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    receiptImagePath: receiptImagePath.present
        ? receiptImagePath.value
        : this.receiptImagePath,
    transactionDate: transactionDate ?? this.transactionDate,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      academicYearId: data.academicYearId.present
          ? data.academicYearId.value
          : this.academicYearId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      type: data.type.present ? data.type.value : this.type,
      amount: data.amount.present ? data.amount.value : this.amount,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      receiptImagePath: data.receiptImagePath.present
          ? data.receiptImagePath.value
          : this.receiptImagePath,
      transactionDate: data.transactionDate.present
          ? data.transactionDate.value
          : this.transactionDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('academicYearId: $academicYearId, ')
          ..write('categoryId: $categoryId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('receiptImagePath: $receiptImagePath, ')
          ..write('transactionDate: $transactionDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    academicYearId,
    categoryId,
    type,
    amount,
    title,
    description,
    receiptImagePath,
    transactionDate,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.academicYearId == this.academicYearId &&
          other.categoryId == this.categoryId &&
          other.type == this.type &&
          other.amount == this.amount &&
          other.title == this.title &&
          other.description == this.description &&
          other.receiptImagePath == this.receiptImagePath &&
          other.transactionDate == this.transactionDate &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<String> id;
  final Value<String> academicYearId;
  final Value<String> categoryId;
  final Value<String> type;
  final Value<int> amount;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> receiptImagePath;
  final Value<DateTime> transactionDate;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.academicYearId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.receiptImagePath = const Value.absent(),
    this.transactionDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required String id,
    required String academicYearId,
    required String categoryId,
    required String type,
    required int amount,
    required String title,
    this.description = const Value.absent(),
    this.receiptImagePath = const Value.absent(),
    required DateTime transactionDate,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       academicYearId = Value(academicYearId),
       categoryId = Value(categoryId),
       type = Value(type),
       amount = Value(amount),
       title = Value(title),
       transactionDate = Value(transactionDate),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Transaction> custom({
    Expression<String>? id,
    Expression<String>? academicYearId,
    Expression<String>? categoryId,
    Expression<String>? type,
    Expression<int>? amount,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? receiptImagePath,
    Expression<DateTime>? transactionDate,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (academicYearId != null) 'academic_year_id': academicYearId,
      if (categoryId != null) 'category_id': categoryId,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (receiptImagePath != null) 'receipt_image_path': receiptImagePath,
      if (transactionDate != null) 'transaction_date': transactionDate,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? academicYearId,
    Value<String>? categoryId,
    Value<String>? type,
    Value<int>? amount,
    Value<String>? title,
    Value<String?>? description,
    Value<String?>? receiptImagePath,
    Value<DateTime>? transactionDate,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      academicYearId: academicYearId ?? this.academicYearId,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      title: title ?? this.title,
      description: description ?? this.description,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (academicYearId.present) {
      map['academic_year_id'] = Variable<String>(academicYearId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (receiptImagePath.present) {
      map['receipt_image_path'] = Variable<String>(receiptImagePath.value);
    }
    if (transactionDate.present) {
      map['transaction_date'] = Variable<DateTime>(transactionDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('academicYearId: $academicYearId, ')
          ..write('categoryId: $categoryId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('receiptImagePath: $receiptImagePath, ')
          ..write('transactionDate: $transactionDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DuesPeriodsTable extends DuesPeriods
    with TableInfo<$DuesPeriodsTable, DuesPeriod> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DuesPeriodsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _academicYearIdMeta = const VerificationMeta(
    'academicYearId',
  );
  @override
  late final GeneratedColumn<String> academicYearId = GeneratedColumn<String>(
    'academic_year_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES academic_years (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _periodLabelMeta = const VerificationMeta(
    'periodLabel',
  );
  @override
  late final GeneratedColumn<String> periodLabel = GeneratedColumn<String>(
    'period_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetAmountMeta = const VerificationMeta(
    'targetAmount',
  );
  @override
  late final GeneratedColumn<int> targetAmount = GeneratedColumn<int>(
    'target_amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isReconciledMeta = const VerificationMeta(
    'isReconciled',
  );
  @override
  late final GeneratedColumn<bool> isReconciled = GeneratedColumn<bool>(
    'is_reconciled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_reconciled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _reconciledAmountMeta = const VerificationMeta(
    'reconciledAmount',
  );
  @override
  late final GeneratedColumn<int> reconciledAmount = GeneratedColumn<int>(
    'reconciled_amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    academicYearId,
    periodLabel,
    dueDate,
    targetAmount,
    isReconciled,
    reconciledAmount,
    transactionId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dues_periods';
  @override
  VerificationContext validateIntegrity(
    Insertable<DuesPeriod> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('academic_year_id')) {
      context.handle(
        _academicYearIdMeta,
        academicYearId.isAcceptableOrUnknown(
          data['academic_year_id']!,
          _academicYearIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_academicYearIdMeta);
    }
    if (data.containsKey('period_label')) {
      context.handle(
        _periodLabelMeta,
        periodLabel.isAcceptableOrUnknown(
          data['period_label']!,
          _periodLabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_periodLabelMeta);
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    } else if (isInserting) {
      context.missing(_dueDateMeta);
    }
    if (data.containsKey('target_amount')) {
      context.handle(
        _targetAmountMeta,
        targetAmount.isAcceptableOrUnknown(
          data['target_amount']!,
          _targetAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetAmountMeta);
    }
    if (data.containsKey('is_reconciled')) {
      context.handle(
        _isReconciledMeta,
        isReconciled.isAcceptableOrUnknown(
          data['is_reconciled']!,
          _isReconciledMeta,
        ),
      );
    }
    if (data.containsKey('reconciled_amount')) {
      context.handle(
        _reconciledAmountMeta,
        reconciledAmount.isAcceptableOrUnknown(
          data['reconciled_amount']!,
          _reconciledAmountMeta,
        ),
      );
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {academicYearId, periodLabel},
  ];
  @override
  DuesPeriod map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DuesPeriod(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      academicYearId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}academic_year_id'],
      )!,
      periodLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_label'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      )!,
      targetAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_amount'],
      )!,
      isReconciled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_reconciled'],
      )!,
      reconciledAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reconciled_amount'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DuesPeriodsTable createAlias(String alias) {
    return $DuesPeriodsTable(attachedDatabase, alias);
  }
}

class DuesPeriod extends DataClass implements Insertable<DuesPeriod> {
  final String id;
  final String academicYearId;
  final String periodLabel;
  final DateTime dueDate;
  final int targetAmount;
  final bool isReconciled;
  final int reconciledAmount;
  final String? transactionId;
  final DateTime createdAt;
  const DuesPeriod({
    required this.id,
    required this.academicYearId,
    required this.periodLabel,
    required this.dueDate,
    required this.targetAmount,
    required this.isReconciled,
    required this.reconciledAmount,
    this.transactionId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['academic_year_id'] = Variable<String>(academicYearId);
    map['period_label'] = Variable<String>(periodLabel);
    map['due_date'] = Variable<DateTime>(dueDate);
    map['target_amount'] = Variable<int>(targetAmount);
    map['is_reconciled'] = Variable<bool>(isReconciled);
    map['reconciled_amount'] = Variable<int>(reconciledAmount);
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<String>(transactionId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DuesPeriodsCompanion toCompanion(bool nullToAbsent) {
    return DuesPeriodsCompanion(
      id: Value(id),
      academicYearId: Value(academicYearId),
      periodLabel: Value(periodLabel),
      dueDate: Value(dueDate),
      targetAmount: Value(targetAmount),
      isReconciled: Value(isReconciled),
      reconciledAmount: Value(reconciledAmount),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
      createdAt: Value(createdAt),
    );
  }

  factory DuesPeriod.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DuesPeriod(
      id: serializer.fromJson<String>(json['id']),
      academicYearId: serializer.fromJson<String>(json['academicYearId']),
      periodLabel: serializer.fromJson<String>(json['periodLabel']),
      dueDate: serializer.fromJson<DateTime>(json['dueDate']),
      targetAmount: serializer.fromJson<int>(json['targetAmount']),
      isReconciled: serializer.fromJson<bool>(json['isReconciled']),
      reconciledAmount: serializer.fromJson<int>(json['reconciledAmount']),
      transactionId: serializer.fromJson<String?>(json['transactionId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'academicYearId': serializer.toJson<String>(academicYearId),
      'periodLabel': serializer.toJson<String>(periodLabel),
      'dueDate': serializer.toJson<DateTime>(dueDate),
      'targetAmount': serializer.toJson<int>(targetAmount),
      'isReconciled': serializer.toJson<bool>(isReconciled),
      'reconciledAmount': serializer.toJson<int>(reconciledAmount),
      'transactionId': serializer.toJson<String?>(transactionId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DuesPeriod copyWith({
    String? id,
    String? academicYearId,
    String? periodLabel,
    DateTime? dueDate,
    int? targetAmount,
    bool? isReconciled,
    int? reconciledAmount,
    Value<String?> transactionId = const Value.absent(),
    DateTime? createdAt,
  }) => DuesPeriod(
    id: id ?? this.id,
    academicYearId: academicYearId ?? this.academicYearId,
    periodLabel: periodLabel ?? this.periodLabel,
    dueDate: dueDate ?? this.dueDate,
    targetAmount: targetAmount ?? this.targetAmount,
    isReconciled: isReconciled ?? this.isReconciled,
    reconciledAmount: reconciledAmount ?? this.reconciledAmount,
    transactionId: transactionId.present
        ? transactionId.value
        : this.transactionId,
    createdAt: createdAt ?? this.createdAt,
  );
  DuesPeriod copyWithCompanion(DuesPeriodsCompanion data) {
    return DuesPeriod(
      id: data.id.present ? data.id.value : this.id,
      academicYearId: data.academicYearId.present
          ? data.academicYearId.value
          : this.academicYearId,
      periodLabel: data.periodLabel.present
          ? data.periodLabel.value
          : this.periodLabel,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      targetAmount: data.targetAmount.present
          ? data.targetAmount.value
          : this.targetAmount,
      isReconciled: data.isReconciled.present
          ? data.isReconciled.value
          : this.isReconciled,
      reconciledAmount: data.reconciledAmount.present
          ? data.reconciledAmount.value
          : this.reconciledAmount,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DuesPeriod(')
          ..write('id: $id, ')
          ..write('academicYearId: $academicYearId, ')
          ..write('periodLabel: $periodLabel, ')
          ..write('dueDate: $dueDate, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('isReconciled: $isReconciled, ')
          ..write('reconciledAmount: $reconciledAmount, ')
          ..write('transactionId: $transactionId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    academicYearId,
    periodLabel,
    dueDate,
    targetAmount,
    isReconciled,
    reconciledAmount,
    transactionId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DuesPeriod &&
          other.id == this.id &&
          other.academicYearId == this.academicYearId &&
          other.periodLabel == this.periodLabel &&
          other.dueDate == this.dueDate &&
          other.targetAmount == this.targetAmount &&
          other.isReconciled == this.isReconciled &&
          other.reconciledAmount == this.reconciledAmount &&
          other.transactionId == this.transactionId &&
          other.createdAt == this.createdAt);
}

class DuesPeriodsCompanion extends UpdateCompanion<DuesPeriod> {
  final Value<String> id;
  final Value<String> academicYearId;
  final Value<String> periodLabel;
  final Value<DateTime> dueDate;
  final Value<int> targetAmount;
  final Value<bool> isReconciled;
  final Value<int> reconciledAmount;
  final Value<String?> transactionId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DuesPeriodsCompanion({
    this.id = const Value.absent(),
    this.academicYearId = const Value.absent(),
    this.periodLabel = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.targetAmount = const Value.absent(),
    this.isReconciled = const Value.absent(),
    this.reconciledAmount = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DuesPeriodsCompanion.insert({
    required String id,
    required String academicYearId,
    required String periodLabel,
    required DateTime dueDate,
    required int targetAmount,
    this.isReconciled = const Value.absent(),
    this.reconciledAmount = const Value.absent(),
    this.transactionId = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       academicYearId = Value(academicYearId),
       periodLabel = Value(periodLabel),
       dueDate = Value(dueDate),
       targetAmount = Value(targetAmount),
       createdAt = Value(createdAt);
  static Insertable<DuesPeriod> custom({
    Expression<String>? id,
    Expression<String>? academicYearId,
    Expression<String>? periodLabel,
    Expression<DateTime>? dueDate,
    Expression<int>? targetAmount,
    Expression<bool>? isReconciled,
    Expression<int>? reconciledAmount,
    Expression<String>? transactionId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (academicYearId != null) 'academic_year_id': academicYearId,
      if (periodLabel != null) 'period_label': periodLabel,
      if (dueDate != null) 'due_date': dueDate,
      if (targetAmount != null) 'target_amount': targetAmount,
      if (isReconciled != null) 'is_reconciled': isReconciled,
      if (reconciledAmount != null) 'reconciled_amount': reconciledAmount,
      if (transactionId != null) 'transaction_id': transactionId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DuesPeriodsCompanion copyWith({
    Value<String>? id,
    Value<String>? academicYearId,
    Value<String>? periodLabel,
    Value<DateTime>? dueDate,
    Value<int>? targetAmount,
    Value<bool>? isReconciled,
    Value<int>? reconciledAmount,
    Value<String?>? transactionId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return DuesPeriodsCompanion(
      id: id ?? this.id,
      academicYearId: academicYearId ?? this.academicYearId,
      periodLabel: periodLabel ?? this.periodLabel,
      dueDate: dueDate ?? this.dueDate,
      targetAmount: targetAmount ?? this.targetAmount,
      isReconciled: isReconciled ?? this.isReconciled,
      reconciledAmount: reconciledAmount ?? this.reconciledAmount,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (academicYearId.present) {
      map['academic_year_id'] = Variable<String>(academicYearId.value);
    }
    if (periodLabel.present) {
      map['period_label'] = Variable<String>(periodLabel.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (targetAmount.present) {
      map['target_amount'] = Variable<int>(targetAmount.value);
    }
    if (isReconciled.present) {
      map['is_reconciled'] = Variable<bool>(isReconciled.value);
    }
    if (reconciledAmount.present) {
      map['reconciled_amount'] = Variable<int>(reconciledAmount.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DuesPeriodsCompanion(')
          ..write('id: $id, ')
          ..write('academicYearId: $academicYearId, ')
          ..write('periodLabel: $periodLabel, ')
          ..write('dueDate: $dueDate, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('isReconciled: $isReconciled, ')
          ..write('reconciledAmount: $reconciledAmount, ')
          ..write('transactionId: $transactionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DuesPaymentsTable extends DuesPayments
    with TableInfo<$DuesPaymentsTable, DuesPayment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DuesPaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _duesPeriodIdMeta = const VerificationMeta(
    'duesPeriodId',
  );
  @override
  late final GeneratedColumn<String> duesPeriodId = GeneratedColumn<String>(
    'dues_period_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES dues_periods (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _studentIdMeta = const VerificationMeta(
    'studentId',
  );
  @override
  late final GeneratedColumn<String> studentId = GeneratedColumn<String>(
    'student_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES students (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _amountPaidMeta = const VerificationMeta(
    'amountPaid',
  );
  @override
  late final GeneratedColumn<int> amountPaid = GeneratedColumn<int>(
    'amount_paid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isPaidMeta = const VerificationMeta('isPaid');
  @override
  late final GeneratedColumn<bool> isPaid = GeneratedColumn<bool>(
    'is_paid',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_paid" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _paidAtMeta = const VerificationMeta('paidAt');
  @override
  late final GeneratedColumn<DateTime> paidAt = GeneratedColumn<DateTime>(
    'paid_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    duesPeriodId,
    studentId,
    amountPaid,
    isPaid,
    paidAt,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dues_payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<DuesPayment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dues_period_id')) {
      context.handle(
        _duesPeriodIdMeta,
        duesPeriodId.isAcceptableOrUnknown(
          data['dues_period_id']!,
          _duesPeriodIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_duesPeriodIdMeta);
    }
    if (data.containsKey('student_id')) {
      context.handle(
        _studentIdMeta,
        studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('amount_paid')) {
      context.handle(
        _amountPaidMeta,
        amountPaid.isAcceptableOrUnknown(data['amount_paid']!, _amountPaidMeta),
      );
    }
    if (data.containsKey('is_paid')) {
      context.handle(
        _isPaidMeta,
        isPaid.isAcceptableOrUnknown(data['is_paid']!, _isPaidMeta),
      );
    }
    if (data.containsKey('paid_at')) {
      context.handle(
        _paidAtMeta,
        paidAt.isAcceptableOrUnknown(data['paid_at']!, _paidAtMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {duesPeriodId, studentId},
  ];
  @override
  DuesPayment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DuesPayment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      duesPeriodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dues_period_id'],
      )!,
      studentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}student_id'],
      )!,
      amountPaid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_paid'],
      )!,
      isPaid: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_paid'],
      )!,
      paidAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}paid_at'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $DuesPaymentsTable createAlias(String alias) {
    return $DuesPaymentsTable(attachedDatabase, alias);
  }
}

class DuesPayment extends DataClass implements Insertable<DuesPayment> {
  final String id;
  final String duesPeriodId;
  final String studentId;
  final int amountPaid;
  final bool isPaid;
  final DateTime? paidAt;
  final String? notes;
  const DuesPayment({
    required this.id,
    required this.duesPeriodId,
    required this.studentId,
    required this.amountPaid,
    required this.isPaid,
    this.paidAt,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['dues_period_id'] = Variable<String>(duesPeriodId);
    map['student_id'] = Variable<String>(studentId);
    map['amount_paid'] = Variable<int>(amountPaid);
    map['is_paid'] = Variable<bool>(isPaid);
    if (!nullToAbsent || paidAt != null) {
      map['paid_at'] = Variable<DateTime>(paidAt);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  DuesPaymentsCompanion toCompanion(bool nullToAbsent) {
    return DuesPaymentsCompanion(
      id: Value(id),
      duesPeriodId: Value(duesPeriodId),
      studentId: Value(studentId),
      amountPaid: Value(amountPaid),
      isPaid: Value(isPaid),
      paidAt: paidAt == null && nullToAbsent
          ? const Value.absent()
          : Value(paidAt),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory DuesPayment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DuesPayment(
      id: serializer.fromJson<String>(json['id']),
      duesPeriodId: serializer.fromJson<String>(json['duesPeriodId']),
      studentId: serializer.fromJson<String>(json['studentId']),
      amountPaid: serializer.fromJson<int>(json['amountPaid']),
      isPaid: serializer.fromJson<bool>(json['isPaid']),
      paidAt: serializer.fromJson<DateTime?>(json['paidAt']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'duesPeriodId': serializer.toJson<String>(duesPeriodId),
      'studentId': serializer.toJson<String>(studentId),
      'amountPaid': serializer.toJson<int>(amountPaid),
      'isPaid': serializer.toJson<bool>(isPaid),
      'paidAt': serializer.toJson<DateTime?>(paidAt),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  DuesPayment copyWith({
    String? id,
    String? duesPeriodId,
    String? studentId,
    int? amountPaid,
    bool? isPaid,
    Value<DateTime?> paidAt = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => DuesPayment(
    id: id ?? this.id,
    duesPeriodId: duesPeriodId ?? this.duesPeriodId,
    studentId: studentId ?? this.studentId,
    amountPaid: amountPaid ?? this.amountPaid,
    isPaid: isPaid ?? this.isPaid,
    paidAt: paidAt.present ? paidAt.value : this.paidAt,
    notes: notes.present ? notes.value : this.notes,
  );
  DuesPayment copyWithCompanion(DuesPaymentsCompanion data) {
    return DuesPayment(
      id: data.id.present ? data.id.value : this.id,
      duesPeriodId: data.duesPeriodId.present
          ? data.duesPeriodId.value
          : this.duesPeriodId,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      amountPaid: data.amountPaid.present
          ? data.amountPaid.value
          : this.amountPaid,
      isPaid: data.isPaid.present ? data.isPaid.value : this.isPaid,
      paidAt: data.paidAt.present ? data.paidAt.value : this.paidAt,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DuesPayment(')
          ..write('id: $id, ')
          ..write('duesPeriodId: $duesPeriodId, ')
          ..write('studentId: $studentId, ')
          ..write('amountPaid: $amountPaid, ')
          ..write('isPaid: $isPaid, ')
          ..write('paidAt: $paidAt, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    duesPeriodId,
    studentId,
    amountPaid,
    isPaid,
    paidAt,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DuesPayment &&
          other.id == this.id &&
          other.duesPeriodId == this.duesPeriodId &&
          other.studentId == this.studentId &&
          other.amountPaid == this.amountPaid &&
          other.isPaid == this.isPaid &&
          other.paidAt == this.paidAt &&
          other.notes == this.notes);
}

class DuesPaymentsCompanion extends UpdateCompanion<DuesPayment> {
  final Value<String> id;
  final Value<String> duesPeriodId;
  final Value<String> studentId;
  final Value<int> amountPaid;
  final Value<bool> isPaid;
  final Value<DateTime?> paidAt;
  final Value<String?> notes;
  final Value<int> rowid;
  const DuesPaymentsCompanion({
    this.id = const Value.absent(),
    this.duesPeriodId = const Value.absent(),
    this.studentId = const Value.absent(),
    this.amountPaid = const Value.absent(),
    this.isPaid = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DuesPaymentsCompanion.insert({
    required String id,
    required String duesPeriodId,
    required String studentId,
    this.amountPaid = const Value.absent(),
    this.isPaid = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       duesPeriodId = Value(duesPeriodId),
       studentId = Value(studentId);
  static Insertable<DuesPayment> custom({
    Expression<String>? id,
    Expression<String>? duesPeriodId,
    Expression<String>? studentId,
    Expression<int>? amountPaid,
    Expression<bool>? isPaid,
    Expression<DateTime>? paidAt,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (duesPeriodId != null) 'dues_period_id': duesPeriodId,
      if (studentId != null) 'student_id': studentId,
      if (amountPaid != null) 'amount_paid': amountPaid,
      if (isPaid != null) 'is_paid': isPaid,
      if (paidAt != null) 'paid_at': paidAt,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DuesPaymentsCompanion copyWith({
    Value<String>? id,
    Value<String>? duesPeriodId,
    Value<String>? studentId,
    Value<int>? amountPaid,
    Value<bool>? isPaid,
    Value<DateTime?>? paidAt,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return DuesPaymentsCompanion(
      id: id ?? this.id,
      duesPeriodId: duesPeriodId ?? this.duesPeriodId,
      studentId: studentId ?? this.studentId,
      amountPaid: amountPaid ?? this.amountPaid,
      isPaid: isPaid ?? this.isPaid,
      paidAt: paidAt ?? this.paidAt,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (duesPeriodId.present) {
      map['dues_period_id'] = Variable<String>(duesPeriodId.value);
    }
    if (studentId.present) {
      map['student_id'] = Variable<String>(studentId.value);
    }
    if (amountPaid.present) {
      map['amount_paid'] = Variable<int>(amountPaid.value);
    }
    if (isPaid.present) {
      map['is_paid'] = Variable<bool>(isPaid.value);
    }
    if (paidAt.present) {
      map['paid_at'] = Variable<DateTime>(paidAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DuesPaymentsCompanion(')
          ..write('id: $id, ')
          ..write('duesPeriodId: $duesPeriodId, ')
          ..write('studentId: $studentId, ')
          ..write('amountPaid: $amountPaid, ')
          ..write('isPaid: $isPaid, ')
          ..write('paidAt: $paidAt, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AcademicYearsTable academicYears = $AcademicYearsTable(this);
  late final $StudentsTable students = $StudentsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $DuesPeriodsTable duesPeriods = $DuesPeriodsTable(this);
  late final $DuesPaymentsTable duesPayments = $DuesPaymentsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    academicYears,
    students,
    categories,
    transactions,
    duesPeriods,
    duesPayments,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'academic_years',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('students', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'academic_years',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('dues_periods', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'dues_periods',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('dues_payments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'students',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('dues_payments', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$AcademicYearsTableCreateCompanionBuilder =
    AcademicYearsCompanion Function({
      required String id,
      required String name,
      required int grade,
      Value<String> treasurerName,
      Value<String> supervisorName,
      Value<int> defaultDuesAmount,
      Value<String> duesPeriodType,
      required DateTime startDate,
      required DateTime endDate,
      Value<bool> isActive,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$AcademicYearsTableUpdateCompanionBuilder =
    AcademicYearsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> grade,
      Value<String> treasurerName,
      Value<String> supervisorName,
      Value<int> defaultDuesAmount,
      Value<String> duesPeriodType,
      Value<DateTime> startDate,
      Value<DateTime> endDate,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$AcademicYearsTableReferences
    extends BaseReferences<_$AppDatabase, $AcademicYearsTable, AcademicYear> {
  $$AcademicYearsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$StudentsTable, List<Student>> _studentsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.students,
    aliasName: 'academic_years__id__students__academic_year_id',
  );

  $$StudentsTableProcessedTableManager get studentsRefs {
    final manager = $$StudentsTableTableManager(
      $_db,
      $_db.students,
    ).filter((f) => f.academicYearId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_studentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'academic_years__id__transactions__academic_year_id',
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.academicYearId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DuesPeriodsTable, List<DuesPeriod>>
  _duesPeriodsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.duesPeriods,
    aliasName: 'academic_years__id__dues_periods__academic_year_id',
  );

  $$DuesPeriodsTableProcessedTableManager get duesPeriodsRefs {
    final manager = $$DuesPeriodsTableTableManager(
      $_db,
      $_db.duesPeriods,
    ).filter((f) => f.academicYearId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_duesPeriodsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AcademicYearsTableFilterComposer
    extends Composer<_$AppDatabase, $AcademicYearsTable> {
  $$AcademicYearsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get grade => $composableBuilder(
    column: $table.grade,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get treasurerName => $composableBuilder(
    column: $table.treasurerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supervisorName => $composableBuilder(
    column: $table.supervisorName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultDuesAmount => $composableBuilder(
    column: $table.defaultDuesAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get duesPeriodType => $composableBuilder(
    column: $table.duesPeriodType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> studentsRefs(
    Expression<bool> Function($$StudentsTableFilterComposer f) f,
  ) {
    final $$StudentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.academicYearId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableFilterComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.academicYearId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> duesPeriodsRefs(
    Expression<bool> Function($$DuesPeriodsTableFilterComposer f) f,
  ) {
    final $$DuesPeriodsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.duesPeriods,
      getReferencedColumn: (t) => t.academicYearId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DuesPeriodsTableFilterComposer(
            $db: $db,
            $table: $db.duesPeriods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AcademicYearsTableOrderingComposer
    extends Composer<_$AppDatabase, $AcademicYearsTable> {
  $$AcademicYearsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get grade => $composableBuilder(
    column: $table.grade,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get treasurerName => $composableBuilder(
    column: $table.treasurerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supervisorName => $composableBuilder(
    column: $table.supervisorName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultDuesAmount => $composableBuilder(
    column: $table.defaultDuesAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get duesPeriodType => $composableBuilder(
    column: $table.duesPeriodType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AcademicYearsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AcademicYearsTable> {
  $$AcademicYearsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get grade =>
      $composableBuilder(column: $table.grade, builder: (column) => column);

  GeneratedColumn<String> get treasurerName => $composableBuilder(
    column: $table.treasurerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get supervisorName => $composableBuilder(
    column: $table.supervisorName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultDuesAmount => $composableBuilder(
    column: $table.defaultDuesAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get duesPeriodType => $composableBuilder(
    column: $table.duesPeriodType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> studentsRefs<T extends Object>(
    Expression<T> Function($$StudentsTableAnnotationComposer a) f,
  ) {
    final $$StudentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.academicYearId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableAnnotationComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.academicYearId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> duesPeriodsRefs<T extends Object>(
    Expression<T> Function($$DuesPeriodsTableAnnotationComposer a) f,
  ) {
    final $$DuesPeriodsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.duesPeriods,
      getReferencedColumn: (t) => t.academicYearId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DuesPeriodsTableAnnotationComposer(
            $db: $db,
            $table: $db.duesPeriods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AcademicYearsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AcademicYearsTable,
          AcademicYear,
          $$AcademicYearsTableFilterComposer,
          $$AcademicYearsTableOrderingComposer,
          $$AcademicYearsTableAnnotationComposer,
          $$AcademicYearsTableCreateCompanionBuilder,
          $$AcademicYearsTableUpdateCompanionBuilder,
          (AcademicYear, $$AcademicYearsTableReferences),
          AcademicYear,
          PrefetchHooks Function({
            bool studentsRefs,
            bool transactionsRefs,
            bool duesPeriodsRefs,
          })
        > {
  $$AcademicYearsTableTableManager(_$AppDatabase db, $AcademicYearsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AcademicYearsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AcademicYearsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AcademicYearsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> grade = const Value.absent(),
                Value<String> treasurerName = const Value.absent(),
                Value<String> supervisorName = const Value.absent(),
                Value<int> defaultDuesAmount = const Value.absent(),
                Value<String> duesPeriodType = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime> endDate = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AcademicYearsCompanion(
                id: id,
                name: name,
                grade: grade,
                treasurerName: treasurerName,
                supervisorName: supervisorName,
                defaultDuesAmount: defaultDuesAmount,
                duesPeriodType: duesPeriodType,
                startDate: startDate,
                endDate: endDate,
                isActive: isActive,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int grade,
                Value<String> treasurerName = const Value.absent(),
                Value<String> supervisorName = const Value.absent(),
                Value<int> defaultDuesAmount = const Value.absent(),
                Value<String> duesPeriodType = const Value.absent(),
                required DateTime startDate,
                required DateTime endDate,
                Value<bool> isActive = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AcademicYearsCompanion.insert(
                id: id,
                name: name,
                grade: grade,
                treasurerName: treasurerName,
                supervisorName: supervisorName,
                defaultDuesAmount: defaultDuesAmount,
                duesPeriodType: duesPeriodType,
                startDate: startDate,
                endDate: endDate,
                isActive: isActive,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AcademicYearsTable, AcademicYear>(table),
                  $$AcademicYearsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                studentsRefs = false,
                transactionsRefs = false,
                duesPeriodsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (studentsRefs) db.students,
                    if (transactionsRefs) db.transactions,
                    if (duesPeriodsRefs) db.duesPeriods,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (studentsRefs)
                        await $_getPrefetchedData<
                          AcademicYear,
                          $AcademicYearsTable,
                          Student
                        >(
                          currentTable: table,
                          referencedTable: $$AcademicYearsTableReferences
                              ._studentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AcademicYearsTableReferences(
                                db,
                                table,
                                p0,
                              ).studentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.academicYearId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transactionsRefs)
                        await $_getPrefetchedData<
                          AcademicYear,
                          $AcademicYearsTable,
                          Transaction
                        >(
                          currentTable: table,
                          referencedTable: $$AcademicYearsTableReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AcademicYearsTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.academicYearId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (duesPeriodsRefs)
                        await $_getPrefetchedData<
                          AcademicYear,
                          $AcademicYearsTable,
                          DuesPeriod
                        >(
                          currentTable: table,
                          referencedTable: $$AcademicYearsTableReferences
                              ._duesPeriodsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AcademicYearsTableReferences(
                                db,
                                table,
                                p0,
                              ).duesPeriodsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.academicYearId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AcademicYearsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AcademicYearsTable,
      AcademicYear,
      $$AcademicYearsTableFilterComposer,
      $$AcademicYearsTableOrderingComposer,
      $$AcademicYearsTableAnnotationComposer,
      $$AcademicYearsTableCreateCompanionBuilder,
      $$AcademicYearsTableUpdateCompanionBuilder,
      (AcademicYear, $$AcademicYearsTableReferences),
      AcademicYear,
      PrefetchHooks Function({
        bool studentsRefs,
        bool transactionsRefs,
        bool duesPeriodsRefs,
      })
    >;
typedef $$StudentsTableCreateCompanionBuilder = StudentsCompanion Function({
  required String id,
  required String academicYearId,
  required int attendanceNumber,
  required String name,
  Value<String> status,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$StudentsTableUpdateCompanionBuilder = StudentsCompanion Function({
  Value<String> id,
  Value<String> academicYearId,
  Value<int> attendanceNumber,
  Value<String> name,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$StudentsTableReferences
    extends BaseReferences<_$AppDatabase, $StudentsTable, Student> {
  $$StudentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AcademicYearsTable _academicYearIdTable(_$AppDatabase db) => db
      .academicYears
      .createAlias('students__academic_year_id__academic_years__id');

  $$AcademicYearsTableProcessedTableManager get academicYearId {
    final $_column = $_itemColumn<String>('academic_year_id')!;

    final manager = $$AcademicYearsTableTableManager(
      $_db,
      $_db.academicYears,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_academicYearIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$DuesPaymentsTable, List<DuesPayment>>
  _duesPaymentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.duesPayments,
    aliasName: 'students__id__dues_payments__student_id',
  );

  $$DuesPaymentsTableProcessedTableManager get duesPaymentsRefs {
    final manager = $$DuesPaymentsTableTableManager(
      $_db,
      $_db.duesPayments,
    ).filter((f) => f.studentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_duesPaymentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$StudentsTableFilterComposer
    extends Composer<_$AppDatabase, $StudentsTable> {
  $$StudentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attendanceNumber => $composableBuilder(
    column: $table.attendanceNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AcademicYearsTableFilterComposer get academicYearId {
    final $$AcademicYearsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.academicYearId,
      referencedTable: $db.academicYears,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AcademicYearsTableFilterComposer(
            $db: $db,
            $table: $db.academicYears,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> duesPaymentsRefs(
    Expression<bool> Function($$DuesPaymentsTableFilterComposer f) f,
  ) {
    final $$DuesPaymentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.duesPayments,
      getReferencedColumn: (t) => t.studentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DuesPaymentsTableFilterComposer(
            $db: $db,
            $table: $db.duesPayments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StudentsTableOrderingComposer
    extends Composer<_$AppDatabase, $StudentsTable> {
  $$StudentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attendanceNumber => $composableBuilder(
    column: $table.attendanceNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AcademicYearsTableOrderingComposer get academicYearId {
    final $$AcademicYearsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.academicYearId,
      referencedTable: $db.academicYears,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AcademicYearsTableOrderingComposer(
            $db: $db,
            $table: $db.academicYears,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StudentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudentsTable> {
  $$StudentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get attendanceNumber => $composableBuilder(
    column: $table.attendanceNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$AcademicYearsTableAnnotationComposer get academicYearId {
    final $$AcademicYearsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.academicYearId,
      referencedTable: $db.academicYears,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AcademicYearsTableAnnotationComposer(
            $db: $db,
            $table: $db.academicYears,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> duesPaymentsRefs<T extends Object>(
    Expression<T> Function($$DuesPaymentsTableAnnotationComposer a) f,
  ) {
    final $$DuesPaymentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.duesPayments,
      getReferencedColumn: (t) => t.studentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DuesPaymentsTableAnnotationComposer(
            $db: $db,
            $table: $db.duesPayments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StudentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudentsTable,
          Student,
          $$StudentsTableFilterComposer,
          $$StudentsTableOrderingComposer,
          $$StudentsTableAnnotationComposer,
          $$StudentsTableCreateCompanionBuilder,
          $$StudentsTableUpdateCompanionBuilder,
          (Student, $$StudentsTableReferences),
          Student,
          PrefetchHooks Function({bool academicYearId, bool duesPaymentsRefs})
        > {
  $$StudentsTableTableManager(_$AppDatabase db, $StudentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> academicYearId = const Value.absent(),
                Value<int> attendanceNumber = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudentsCompanion(
                id: id,
                academicYearId: academicYearId,
                attendanceNumber: attendanceNumber,
                name: name,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String academicYearId,
                required int attendanceNumber,
                required String name,
                Value<String> status = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => StudentsCompanion.insert(
                id: id,
                academicYearId: academicYearId,
                attendanceNumber: attendanceNumber,
                name: name,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StudentsTable, Student>(table),
                  $$StudentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({academicYearId = false, duesPaymentsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (duesPaymentsRefs) db.duesPayments,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (academicYearId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.academicYearId,
                            referencedTable: $$StudentsTableReferences
                                ._academicYearIdTable(db),
                            referencedColumn: $$StudentsTableReferences
                                ._academicYearIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (duesPaymentsRefs)
                        await $_getPrefetchedData<
                          Student,
                          $StudentsTable,
                          DuesPayment
                        >(
                          currentTable: table,
                          referencedTable: $$StudentsTableReferences
                              ._duesPaymentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StudentsTableReferences(
                                db,
                                table,
                                p0,
                              ).duesPaymentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.studentId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$StudentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudentsTable,
      Student,
      $$StudentsTableFilterComposer,
      $$StudentsTableOrderingComposer,
      $$StudentsTableAnnotationComposer,
      $$StudentsTableCreateCompanionBuilder,
      $$StudentsTableUpdateCompanionBuilder,
      (Student, $$StudentsTableReferences),
      Student,
      PrefetchHooks Function({bool academicYearId, bool duesPaymentsRefs})
    >;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String id,
  required String type,
  required String name,
  required String iconName,
  required String colorHex,
  Value<bool> isDefault,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> id,
  Value<String> type,
  Value<String> name,
  Value<String> iconName,
  Value<String> colorHex,
  Value<bool> isDefault,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'categories__id__transactions__category_id',
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({bool transactionsRefs})
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> iconName = const Value.absent(),
                Value<String> colorHex = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                type: type,
                name: name,
                iconName: iconName,
                colorHex: colorHex,
                isDefault: isDefault,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String name,
                required String iconName,
                required String colorHex,
                Value<bool> isDefault = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                type: type,
                name: name,
                iconName: iconName,
                colorHex: colorHex,
                isDefault: isDefault,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, Category>(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transactionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (transactionsRefs) db.transactions],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (transactionsRefs)
                    await $_getPrefetchedData<
                      Category,
                      $CategoriesTable,
                      Transaction
                    >(
                      currentTable: table,
                      referencedTable: $$CategoriesTableReferences
                          ._transactionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CategoriesTableReferences(
                            db,
                            table,
                            p0,
                          ).transactionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.categoryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({bool transactionsRefs})
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      required String id,
      required String academicYearId,
      required String categoryId,
      required String type,
      required int amount,
      required String title,
      Value<String?> description,
      Value<String?> receiptImagePath,
      required DateTime transactionDate,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<String> id,
      Value<String> academicYearId,
      Value<String> categoryId,
      Value<String> type,
      Value<int> amount,
      Value<String> title,
      Value<String?> description,
      Value<String?> receiptImagePath,
      Value<DateTime> transactionDate,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$TransactionsTableReferences
    extends BaseReferences<_$AppDatabase, $TransactionsTable, Transaction> {
  $$TransactionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AcademicYearsTable _academicYearIdTable(_$AppDatabase db) => db
      .academicYears
      .createAlias('transactions__academic_year_id__academic_years__id');

  $$AcademicYearsTableProcessedTableManager get academicYearId {
    final $_column = $_itemColumn<String>('academic_year_id')!;

    final manager = $$AcademicYearsTableTableManager(
      $_db,
      $_db.academicYears,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_academicYearIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('transactions__category_id__categories__id');

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptImagePath => $composableBuilder(
    column: $table.receiptImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AcademicYearsTableFilterComposer get academicYearId {
    final $$AcademicYearsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.academicYearId,
      referencedTable: $db.academicYears,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AcademicYearsTableFilterComposer(
            $db: $db,
            $table: $db.academicYears,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptImagePath => $composableBuilder(
    column: $table.receiptImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AcademicYearsTableOrderingComposer get academicYearId {
    final $$AcademicYearsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.academicYearId,
      referencedTable: $db.academicYears,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AcademicYearsTableOrderingComposer(
            $db: $db,
            $table: $db.academicYears,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receiptImagePath => $composableBuilder(
    column: $table.receiptImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$AcademicYearsTableAnnotationComposer get academicYearId {
    final $$AcademicYearsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.academicYearId,
      referencedTable: $db.academicYears,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AcademicYearsTableAnnotationComposer(
            $db: $db,
            $table: $db.academicYears,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          Transaction,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (Transaction, $$TransactionsTableReferences),
          Transaction,
          PrefetchHooks Function({bool academicYearId, bool categoryId})
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> academicYearId = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> receiptImagePath = const Value.absent(),
                Value<DateTime> transactionDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                academicYearId: academicYearId,
                categoryId: categoryId,
                type: type,
                amount: amount,
                title: title,
                description: description,
                receiptImagePath: receiptImagePath,
                transactionDate: transactionDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String academicYearId,
                required String categoryId,
                required String type,
                required int amount,
                required String title,
                Value<String?> description = const Value.absent(),
                Value<String?> receiptImagePath = const Value.absent(),
                required DateTime transactionDate,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                academicYearId: academicYearId,
                categoryId: categoryId,
                type: type,
                amount: amount,
                title: title,
                description: description,
                receiptImagePath: receiptImagePath,
                transactionDate: transactionDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TransactionsTable, Transaction>(table),
                  $$TransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({academicYearId = false, categoryId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (academicYearId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.academicYearId,
                            referencedTable: $$TransactionsTableReferences
                                ._academicYearIdTable(db),
                            referencedColumn: $$TransactionsTableReferences
                                ._academicYearIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (categoryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.categoryId,
                            referencedTable: $$TransactionsTableReferences
                                ._categoryIdTable(db),
                            referencedColumn: $$TransactionsTableReferences
                                ._categoryIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      Transaction,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (Transaction, $$TransactionsTableReferences),
      Transaction,
      PrefetchHooks Function({bool academicYearId, bool categoryId})
    >;
typedef $$DuesPeriodsTableCreateCompanionBuilder =
    DuesPeriodsCompanion Function({
      required String id,
      required String academicYearId,
      required String periodLabel,
      required DateTime dueDate,
      required int targetAmount,
      Value<bool> isReconciled,
      Value<int> reconciledAmount,
      Value<String?> transactionId,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$DuesPeriodsTableUpdateCompanionBuilder =
    DuesPeriodsCompanion Function({
      Value<String> id,
      Value<String> academicYearId,
      Value<String> periodLabel,
      Value<DateTime> dueDate,
      Value<int> targetAmount,
      Value<bool> isReconciled,
      Value<int> reconciledAmount,
      Value<String?> transactionId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$DuesPeriodsTableReferences
    extends BaseReferences<_$AppDatabase, $DuesPeriodsTable, DuesPeriod> {
  $$DuesPeriodsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AcademicYearsTable _academicYearIdTable(_$AppDatabase db) => db
      .academicYears
      .createAlias('dues_periods__academic_year_id__academic_years__id');

  $$AcademicYearsTableProcessedTableManager get academicYearId {
    final $_column = $_itemColumn<String>('academic_year_id')!;

    final manager = $$AcademicYearsTableTableManager(
      $_db,
      $_db.academicYears,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_academicYearIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$DuesPaymentsTable, List<DuesPayment>>
  _duesPaymentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.duesPayments,
    aliasName: 'dues_periods__id__dues_payments__dues_period_id',
  );

  $$DuesPaymentsTableProcessedTableManager get duesPaymentsRefs {
    final manager = $$DuesPaymentsTableTableManager(
      $_db,
      $_db.duesPayments,
    ).filter((f) => f.duesPeriodId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_duesPaymentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DuesPeriodsTableFilterComposer
    extends Composer<_$AppDatabase, $DuesPeriodsTable> {
  $$DuesPeriodsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get periodLabel => $composableBuilder(
    column: $table.periodLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isReconciled => $composableBuilder(
    column: $table.isReconciled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reconciledAmount => $composableBuilder(
    column: $table.reconciledAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AcademicYearsTableFilterComposer get academicYearId {
    final $$AcademicYearsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.academicYearId,
      referencedTable: $db.academicYears,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AcademicYearsTableFilterComposer(
            $db: $db,
            $table: $db.academicYears,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> duesPaymentsRefs(
    Expression<bool> Function($$DuesPaymentsTableFilterComposer f) f,
  ) {
    final $$DuesPaymentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.duesPayments,
      getReferencedColumn: (t) => t.duesPeriodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DuesPaymentsTableFilterComposer(
            $db: $db,
            $table: $db.duesPayments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DuesPeriodsTableOrderingComposer
    extends Composer<_$AppDatabase, $DuesPeriodsTable> {
  $$DuesPeriodsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodLabel => $composableBuilder(
    column: $table.periodLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isReconciled => $composableBuilder(
    column: $table.isReconciled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reconciledAmount => $composableBuilder(
    column: $table.reconciledAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AcademicYearsTableOrderingComposer get academicYearId {
    final $$AcademicYearsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.academicYearId,
      referencedTable: $db.academicYears,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AcademicYearsTableOrderingComposer(
            $db: $db,
            $table: $db.academicYears,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DuesPeriodsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DuesPeriodsTable> {
  $$DuesPeriodsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get periodLabel => $composableBuilder(
    column: $table.periodLabel,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<int> get targetAmount => $composableBuilder(
    column: $table.targetAmount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isReconciled => $composableBuilder(
    column: $table.isReconciled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reconciledAmount => $composableBuilder(
    column: $table.reconciledAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$AcademicYearsTableAnnotationComposer get academicYearId {
    final $$AcademicYearsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.academicYearId,
      referencedTable: $db.academicYears,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AcademicYearsTableAnnotationComposer(
            $db: $db,
            $table: $db.academicYears,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> duesPaymentsRefs<T extends Object>(
    Expression<T> Function($$DuesPaymentsTableAnnotationComposer a) f,
  ) {
    final $$DuesPaymentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.duesPayments,
      getReferencedColumn: (t) => t.duesPeriodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DuesPaymentsTableAnnotationComposer(
            $db: $db,
            $table: $db.duesPayments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DuesPeriodsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DuesPeriodsTable,
          DuesPeriod,
          $$DuesPeriodsTableFilterComposer,
          $$DuesPeriodsTableOrderingComposer,
          $$DuesPeriodsTableAnnotationComposer,
          $$DuesPeriodsTableCreateCompanionBuilder,
          $$DuesPeriodsTableUpdateCompanionBuilder,
          (DuesPeriod, $$DuesPeriodsTableReferences),
          DuesPeriod,
          PrefetchHooks Function({bool academicYearId, bool duesPaymentsRefs})
        > {
  $$DuesPeriodsTableTableManager(_$AppDatabase db, $DuesPeriodsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DuesPeriodsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DuesPeriodsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DuesPeriodsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> academicYearId = const Value.absent(),
                Value<String> periodLabel = const Value.absent(),
                Value<DateTime> dueDate = const Value.absent(),
                Value<int> targetAmount = const Value.absent(),
                Value<bool> isReconciled = const Value.absent(),
                Value<int> reconciledAmount = const Value.absent(),
                Value<String?> transactionId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DuesPeriodsCompanion(
                id: id,
                academicYearId: academicYearId,
                periodLabel: periodLabel,
                dueDate: dueDate,
                targetAmount: targetAmount,
                isReconciled: isReconciled,
                reconciledAmount: reconciledAmount,
                transactionId: transactionId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String academicYearId,
                required String periodLabel,
                required DateTime dueDate,
                required int targetAmount,
                Value<bool> isReconciled = const Value.absent(),
                Value<int> reconciledAmount = const Value.absent(),
                Value<String?> transactionId = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => DuesPeriodsCompanion.insert(
                id: id,
                academicYearId: academicYearId,
                periodLabel: periodLabel,
                dueDate: dueDate,
                targetAmount: targetAmount,
                isReconciled: isReconciled,
                reconciledAmount: reconciledAmount,
                transactionId: transactionId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DuesPeriodsTable, DuesPeriod>(table),
                  $$DuesPeriodsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({academicYearId = false, duesPaymentsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (duesPaymentsRefs) db.duesPayments,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (academicYearId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.academicYearId,
                            referencedTable: $$DuesPeriodsTableReferences
                                ._academicYearIdTable(db),
                            referencedColumn: $$DuesPeriodsTableReferences
                                ._academicYearIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (duesPaymentsRefs)
                        await $_getPrefetchedData<
                          DuesPeriod,
                          $DuesPeriodsTable,
                          DuesPayment
                        >(
                          currentTable: table,
                          referencedTable: $$DuesPeriodsTableReferences
                              ._duesPaymentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DuesPeriodsTableReferences(
                                db,
                                table,
                                p0,
                              ).duesPaymentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.duesPeriodId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DuesPeriodsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DuesPeriodsTable,
      DuesPeriod,
      $$DuesPeriodsTableFilterComposer,
      $$DuesPeriodsTableOrderingComposer,
      $$DuesPeriodsTableAnnotationComposer,
      $$DuesPeriodsTableCreateCompanionBuilder,
      $$DuesPeriodsTableUpdateCompanionBuilder,
      (DuesPeriod, $$DuesPeriodsTableReferences),
      DuesPeriod,
      PrefetchHooks Function({bool academicYearId, bool duesPaymentsRefs})
    >;
typedef $$DuesPaymentsTableCreateCompanionBuilder =
    DuesPaymentsCompanion Function({
      required String id,
      required String duesPeriodId,
      required String studentId,
      Value<int> amountPaid,
      Value<bool> isPaid,
      Value<DateTime?> paidAt,
      Value<String?> notes,
      Value<int> rowid,
    });
typedef $$DuesPaymentsTableUpdateCompanionBuilder =
    DuesPaymentsCompanion Function({
      Value<String> id,
      Value<String> duesPeriodId,
      Value<String> studentId,
      Value<int> amountPaid,
      Value<bool> isPaid,
      Value<DateTime?> paidAt,
      Value<String?> notes,
      Value<int> rowid,
    });

final class $$DuesPaymentsTableReferences
    extends BaseReferences<_$AppDatabase, $DuesPaymentsTable, DuesPayment> {
  $$DuesPaymentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DuesPeriodsTable _duesPeriodIdTable(_$AppDatabase db) => db
      .duesPeriods
      .createAlias('dues_payments__dues_period_id__dues_periods__id');

  $$DuesPeriodsTableProcessedTableManager get duesPeriodId {
    final $_column = $_itemColumn<String>('dues_period_id')!;

    final manager = $$DuesPeriodsTableTableManager(
      $_db,
      $_db.duesPeriods,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_duesPeriodIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $StudentsTable _studentIdTable(_$AppDatabase db) =>
      db.students.createAlias('dues_payments__student_id__students__id');

  $$StudentsTableProcessedTableManager get studentId {
    final $_column = $_itemColumn<String>('student_id')!;

    final manager = $$StudentsTableTableManager(
      $_db,
      $_db.students,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_studentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DuesPaymentsTableFilterComposer
    extends Composer<_$AppDatabase, $DuesPaymentsTable> {
  $$DuesPaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountPaid => $composableBuilder(
    column: $table.amountPaid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPaid => $composableBuilder(
    column: $table.isPaid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$DuesPeriodsTableFilterComposer get duesPeriodId {
    final $$DuesPeriodsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.duesPeriodId,
      referencedTable: $db.duesPeriods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DuesPeriodsTableFilterComposer(
            $db: $db,
            $table: $db.duesPeriods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StudentsTableFilterComposer get studentId {
    final $$StudentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableFilterComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DuesPaymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $DuesPaymentsTable> {
  $$DuesPaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountPaid => $composableBuilder(
    column: $table.amountPaid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPaid => $composableBuilder(
    column: $table.isPaid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$DuesPeriodsTableOrderingComposer get duesPeriodId {
    final $$DuesPeriodsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.duesPeriodId,
      referencedTable: $db.duesPeriods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DuesPeriodsTableOrderingComposer(
            $db: $db,
            $table: $db.duesPeriods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StudentsTableOrderingComposer get studentId {
    final $$StudentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableOrderingComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DuesPaymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DuesPaymentsTable> {
  $$DuesPaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get amountPaid => $composableBuilder(
    column: $table.amountPaid,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPaid =>
      $composableBuilder(column: $table.isPaid, builder: (column) => column);

  GeneratedColumn<DateTime> get paidAt =>
      $composableBuilder(column: $table.paidAt, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$DuesPeriodsTableAnnotationComposer get duesPeriodId {
    final $$DuesPeriodsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.duesPeriodId,
      referencedTable: $db.duesPeriods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DuesPeriodsTableAnnotationComposer(
            $db: $db,
            $table: $db.duesPeriods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StudentsTableAnnotationComposer get studentId {
    final $$StudentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableAnnotationComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DuesPaymentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DuesPaymentsTable,
          DuesPayment,
          $$DuesPaymentsTableFilterComposer,
          $$DuesPaymentsTableOrderingComposer,
          $$DuesPaymentsTableAnnotationComposer,
          $$DuesPaymentsTableCreateCompanionBuilder,
          $$DuesPaymentsTableUpdateCompanionBuilder,
          (DuesPayment, $$DuesPaymentsTableReferences),
          DuesPayment,
          PrefetchHooks Function({bool duesPeriodId, bool studentId})
        > {
  $$DuesPaymentsTableTableManager(_$AppDatabase db, $DuesPaymentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DuesPaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DuesPaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DuesPaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> duesPeriodId = const Value.absent(),
                Value<String> studentId = const Value.absent(),
                Value<int> amountPaid = const Value.absent(),
                Value<bool> isPaid = const Value.absent(),
                Value<DateTime?> paidAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DuesPaymentsCompanion(
                id: id,
                duesPeriodId: duesPeriodId,
                studentId: studentId,
                amountPaid: amountPaid,
                isPaid: isPaid,
                paidAt: paidAt,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String duesPeriodId,
                required String studentId,
                Value<int> amountPaid = const Value.absent(),
                Value<bool> isPaid = const Value.absent(),
                Value<DateTime?> paidAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DuesPaymentsCompanion.insert(
                id: id,
                duesPeriodId: duesPeriodId,
                studentId: studentId,
                amountPaid: amountPaid,
                isPaid: isPaid,
                paidAt: paidAt,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DuesPaymentsTable, DuesPayment>(table),
                  $$DuesPaymentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({duesPeriodId = false, studentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (duesPeriodId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.duesPeriodId,
                        referencedTable: $$DuesPaymentsTableReferences
                            ._duesPeriodIdTable(db),
                        referencedColumn: $$DuesPaymentsTableReferences
                            ._duesPeriodIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (studentId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.studentId,
                        referencedTable: $$DuesPaymentsTableReferences
                            ._studentIdTable(db),
                        referencedColumn: $$DuesPaymentsTableReferences
                            ._studentIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DuesPaymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DuesPaymentsTable,
      DuesPayment,
      $$DuesPaymentsTableFilterComposer,
      $$DuesPaymentsTableOrderingComposer,
      $$DuesPaymentsTableAnnotationComposer,
      $$DuesPaymentsTableCreateCompanionBuilder,
      $$DuesPaymentsTableUpdateCompanionBuilder,
      (DuesPayment, $$DuesPaymentsTableReferences),
      DuesPayment,
      PrefetchHooks Function({bool duesPeriodId, bool studentId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AcademicYearsTableTableManager get academicYears =>
      $$AcademicYearsTableTableManager(_db, _db.academicYears);
  $$StudentsTableTableManager get students =>
      $$StudentsTableTableManager(_db, _db.students);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$DuesPeriodsTableTableManager get duesPeriods =>
      $$DuesPeriodsTableTableManager(_db, _db.duesPeriods);
  $$DuesPaymentsTableTableManager get duesPayments =>
      $$DuesPaymentsTableTableManager(_db, _db.duesPayments);
}
