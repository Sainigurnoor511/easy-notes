import 'package:drift_flutter/drift_flutter.dart';

import 'app_database.dart';

/// Web has no filesystem: DB lives in IndexedDB via drift_flutter/WASM.
/// Export/restore/backup are unsupported on this platform.
class DatabaseManager {
  final AppDatabase _db;

  DatabaseManager._(this._db);

  AppDatabase get db => _db;

  static Future<DatabaseManager> open() async {
    return DatabaseManager._(
      AppDatabase(
        driftDatabase(
          name: 'easy_notes',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      ),
    );
  }

  Future<int> dbSize() async => 0;
}
