import '../../core/database/database_manager_web.dart';

Future<String> exportDatabase(DatabaseManager manager) async {
  throw UnsupportedError('Database export is not supported on web.');
}

Future<void> restoreDatabase(DatabaseManager manager, String sourcePath) async {
  throw UnsupportedError('Database restore is not supported on web.');
}
