import 'package:drift/drift.dart';

class AcademicYears extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()(); // Contoh: "Kelas 7A - SMP Negeri 1"
  IntColumn get grade => integer()(); // 7, 8, 9, 10, 11, 12
  TextColumn get treasurerName => text().withDefault(const Constant('Bendahara'))();
  TextColumn get supervisorName => text().withDefault(const Constant('Ibu Pengawas'))();
  IntColumn get defaultDuesAmount => integer().withDefault(const Constant(5000))();
  TextColumn get duesPeriodType => text().withDefault(const Constant('weekly'))(); // 'daily', 'weekly', 'monthly'
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
