import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';

class LabelsDao {
  final AppDatabase _db;
  const LabelsDao(this._db);

  static const _uuid = Uuid();

  Stream<List<Label>> watchAll() {
    return (_db.select(_db.labels)
          ..orderBy([(l) => OrderingTerm(expression: l.name)]))
        .watch();
  }

  Future<List<Label>> getAll() {
    return (_db.select(_db.labels)
          ..orderBy([(l) => OrderingTerm(expression: l.name)]))
        .get();
  }

  Future<Label> create(String name, {String? color}) async {
    final id = _uuid.v4();
    await _db.into(_db.labels).insert(LabelsCompanion.insert(
          id: id,
          name: name,
          color: Value(color),
          createdAt: Value(DateTime.now()),
        ),
        onConflict: DoUpdate((_) => LabelsCompanion(name: Value(name)),
            target: [_db.labels.name]));
    return await (_db.select(_db.labels)..where((l) => l.id.equals(id)))
        .getSingle();
  }

  Future<void> rename(String id, String name) async {
    await (_db.update(_db.labels)..where((l) => l.id.equals(id)))
        .write(LabelsCompanion(name: Value(name)));
  }

  Future<void> setColor(String id, String? color) async {
    await (_db.update(_db.labels)..where((l) => l.id.equals(id)))
        .write(LabelsCompanion(color: Value(color)));
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.labels)..where((l) => l.id.equals(id))).go();
  }

  Stream<List<Label>> watchForNote(String noteId) {
    final q = _db.select(_db.labels).join([
      innerJoin(_db.noteLabels, _db.noteLabels.labelId.equalsExp(_db.labels.id)),
    ])
      ..where(_db.noteLabels.noteId.equals(noteId))
      ..orderBy([OrderingTerm(expression: _db.labels.name)]);
    return q.watch().map((rows) =>
        rows.map((r) => r.readTable(_db.labels)).toList());
  }

  Future<List<Label>> forNote(String noteId) async {
    final rows = await (_db.select(_db.labels).join([
      innerJoin(
          _db.noteLabels, _db.noteLabels.labelId.equalsExp(_db.labels.id)),
    ])
          ..where(_db.noteLabels.noteId.equals(noteId))
          ..orderBy([OrderingTerm(expression: _db.labels.name)]))
        .get();
    return rows.map((r) => r.readTable(_db.labels)).toList();
  }

  Future<void> addToNote(String noteId, String labelId) async {
    await _db.into(_db.noteLabels).insert(NoteLabelsCompanion.insert(
        noteId: noteId, labelId: labelId));
  }

  Future<void> removeFromNote(String noteId, String labelId) async {
    await (_db.delete(_db.noteLabels)
          ..where((nl) =>
              nl.noteId.equals(noteId) & nl.labelId.equals(labelId)))
        .go();
  }
}