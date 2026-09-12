import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';

class LabelsDao {
  final AppDatabase _db;
  const LabelsDao(this._db);

  static const _uuid = Uuid();

  Future<void> _markChanged() async {
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: 'local_change_at',
            value: Value(DateTime.now().toIso8601String()),
          ),
        );
  }

  Future<T> _change<T>(Future<T> Function() action) {
    return _db.transaction(() async {
      final result = await action();
      await _markChanged();
      return result;
    });
  }

  Stream<List<Label>> watchAll() {
    return (_db.select(_db.labels)
      ..orderBy([(label) => OrderingTerm(expression: label.name)])).watch();
  }

  Future<List<Label>> getAll() {
    return (_db.select(_db.labels)
      ..orderBy([(label) => OrderingTerm(expression: label.name)])).get();
  }

  Future<Label> create(String name, {String? color}) {
    return _change(() async {
      final id = _uuid.v4();
      await _db
          .into(_db.labels)
          .insert(
            LabelsCompanion.insert(
              id: id,
              name: name,
              color: Value(color),
              createdAt: Value(DateTime.now()),
            ),
          );
      return (_db.select(_db.labels)
        ..where((label) => label.id.equals(id))).getSingle();
    });
  }

  Future<void> rename(String id, String name) {
    return _change(() async {
      await (_db.update(_db.labels)..where(
        (label) => label.id.equals(id),
      )).write(LabelsCompanion(name: Value(name)));
    });
  }

  Future<void> setColor(String id, String? color) {
    return _change(() async {
      await (_db.update(_db.labels)..where(
        (label) => label.id.equals(id),
      )).write(LabelsCompanion(color: Value(color)));
    });
  }

  Future<void> delete(String id) {
    return _change(() async {
      await (_db.delete(_db.labels)
        ..where((label) => label.id.equals(id))).go();
    });
  }

  Stream<List<Label>> watchForNote(String noteId) {
    final query =
        _db.select(_db.labels).join([
            innerJoin(
              _db.noteLabels,
              _db.noteLabels.labelId.equalsExp(_db.labels.id),
            ),
          ])
          ..where(_db.noteLabels.noteId.equals(noteId))
          ..orderBy([OrderingTerm(expression: _db.labels.name)]);
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(_db.labels)).toList(),
    );
  }

  Future<List<Label>> forNote(String noteId) async {
    final rows =
        await (_db.select(_db.labels).join([
                innerJoin(
                  _db.noteLabels,
                  _db.noteLabels.labelId.equalsExp(_db.labels.id),
                ),
              ])
              ..where(_db.noteLabels.noteId.equals(noteId))
              ..orderBy([OrderingTerm(expression: _db.labels.name)]))
            .get();
    return rows.map((row) => row.readTable(_db.labels)).toList();
  }

  Future<void> addToNote(String noteId, String labelId) {
    return _change(() async {
      await _db
          .into(_db.noteLabels)
          .insert(NoteLabelsCompanion.insert(noteId: noteId, labelId: labelId));
    });
  }

  Future<void> removeFromNote(String noteId, String labelId) {
    return _change(() async {
      await (_db.delete(_db.noteLabels)..where(
        (mapping) =>
            mapping.noteId.equals(noteId) & mapping.labelId.equals(labelId),
      )).go();
    });
  }
}
