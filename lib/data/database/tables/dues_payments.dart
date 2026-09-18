import 'package:drift/drift.dart';
import 'dues_periods.dart';
import 'students.dart';

class DuesPayments extends Table {
  TextColumn get id => text()();
  TextColumn get duesPeriodId => text().references(DuesPeriods, #id, onDelete: KeyAction.cascade)();
  TextColumn get studentId => text().references(Students, #id, onDelete: KeyAction.cascade)();
  IntColumn get amountPaid => integer().withDefault(const Constant(0))();
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();
  DateTimeColumn get paidAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {duesPeriodId, studentId}
  ];
}
