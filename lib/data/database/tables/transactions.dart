import 'package:drift/drift.dart';
import 'academic_years.dart';
import 'categories.dart';

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get academicYearId => text().references(AcademicYears, #id, onDelete: KeyAction.restrict)();
  TextColumn get categoryId => text().references(Categories, #id, onDelete: KeyAction.restrict)();
  TextColumn get type => text()(); // 'income' atau 'expense'
  IntColumn get amount => integer()(); // Nominal bulat dalam Rupiah
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get receiptImagePath => text().nullable()();
  DateTimeColumn get transactionDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
