import 'package:drift/drift.dart';

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // 'income' atau 'expense'
  TextColumn get name => text()();
  TextColumn get iconName => text()();
  TextColumn get colorHex => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
