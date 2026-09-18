import 'package:drift/drift.dart';
import 'academic_years.dart';

class Students extends Table {
  TextColumn get id => text()();
  TextColumn get academicYearId => text().references(AcademicYears, #id, onDelete: KeyAction.cascade)();
  IntColumn get attendanceNumber => integer()();
  TextColumn get name => text()();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active, transferred
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
