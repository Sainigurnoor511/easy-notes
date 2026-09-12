import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

/// Owns the [AppDatabase] and its backing file.
///
/// Keeps the SQLite file path explicit so export/restore can safely replace
/// the live database (close -> copy -> reopen).
class DatabaseManager {
  final File dbFile;
  AppDatabase _db;

  DatabaseManager._(this._db, this.dbFile);

  AppDatabase get db => _db;

  static Future<DatabaseManager> open() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'easy_notes.sqlite'));
    await file.parent.create(recursive: true);
    return DatabaseManager._(
      AppDatabase(NativeDatabase.createInBackground(file)),
      file,
    );
  }

  /// Replaces the live database with [source] (e.g. a restored file).
  Future<void> replaceWith(File source) async {
    await _db.close();
    for (final suffix in const ['', '-wal', '-shm']) {
      final f = File('${dbFile.path}$suffix');
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    await source.copy(dbFile.path);
    _db = AppDatabase(NativeDatabase.createInBackground(dbFile));
  }

  /// Checkpoints WAL and copies the main DB file to [dest].
  Future<void> exportTo(File dest) async {
    await _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    if (await dest.exists()) {
      await dest.delete();
    }
    await dbFile.copy(dest.path);
  }

  Future<int> dbSize() async {
    await _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    if (!await dbFile.exists()) return 0;
    return dbFile.length();
  }
}
