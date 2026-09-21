import 'package:drift/drift.dart';
import 'academic_years.dart';

class DuesPeriods extends Table {
  TextColumn get id => text()();
  TextColumn get academicYearId => text().references(AcademicYears, #id, onDelete: KeyAction.cascade)();
  TextColumn get periodLabel => text()(); // Contoh: "Minggu 2 September 2026"
  DateTimeColumn get dueDate => dateTime()();
  IntColumn get targetAmount => integer()(); // Standar per siswa (e.g. 5000)
  BoolColumn get isReconciled => boolean().withDefault(const Constant(false))();
  IntColumn get reconciledAmount => integer().withDefault(const Constant(0))();
  TextColumn get transactionId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {academicYearId, periodLabel}
  ];
}
