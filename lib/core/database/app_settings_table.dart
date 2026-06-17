import 'package:drift/drift.dart';

/// Drift table for small app-wide key/value preferences — the port of the web
/// `dexieStorage` settings store (e.g. `currentAssistant`, the sidebar tab
/// index). Each row is a single string [value] stored under a unique [key].
@DataClassName('AppSettingRow')
class AppSettingRows extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
