import 'package:drift/drift.dart';

import '../app_database.dart';

class SettingsDao {
  final AppDatabase _db;
  const SettingsDao(this._db);

  Future<String?> get(String key) async {
    final row =
        await (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) async {
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: Value(value)),
        );
  }

  Future<Map<String, String>> all() async {
    final rows = await _db.select(_db.appSettings).get();
    return {for (final r in rows) r.key: r.value};
  }

  /// Raw values used by sync: last sync timestamp + remote revision.
  Future<DateTime?> lastSync() async {
    final v = await get('last_sync_at');
    if (v == null) return null;
    return DateTime.tryParse(v);
  }

  Future<void> setLastSync(DateTime time) =>
      set('last_sync_at', time.toIso8601String());

  Future<DateTime?> lastChangedAt() async {
    final value = await get('local_change_at');
    return value == null ? null : DateTime.tryParse(value);
  }

  Future<void> markChanged() =>
      set('local_change_at', DateTime.now().toIso8601String());

  Future<int?> lastRevision() async {
    final v = await get('sync_revision');
    if (v == null) return null;
    return int.tryParse(v);
  }

  Future<void> setRevision(int revision) => set('sync_revision', '$revision');
}
