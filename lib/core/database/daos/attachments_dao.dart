import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';

class AttachmentsDao {
  final AppDatabase _db;
  const AttachmentsDao(this._db);

  static const _uuid = Uuid();

  Stream<List<Attachment>> watchForNote(String noteId) {
    return (_db.select(_db.attachments)
          ..where((a) => a.noteId.equals(noteId))
          ..orderBy([(a) => OrderingTerm(expression: a.createdAt)]))
        .watch();
  }

  Future<List<Attachment>> forNote(String noteId) {
    return (_db.select(_db.attachments)
          ..where((a) => a.noteId.equals(noteId))
          ..orderBy([(a) => OrderingTerm(expression: a.createdAt)]))
        .get();
  }

  Future<List<Attachment>> forNotes(List<String> noteIds) {
    if (noteIds.isEmpty) return Future.value(const []);
    return (_db.select(_db.attachments)
          ..where((a) => a.noteId.isIn(noteIds)))
        .get();
  }

  Future<Attachment> add({
    required String noteId,
    required String fileName,
    required String localPath,
    String? mimeType,
    required int size,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.attachments).insert(AttachmentsCompanion.insert(
          id: id,
          noteId: noteId,
          fileName: fileName,
          localPath: localPath,
          mimeType: Value(mimeType),
          size: Value(size),
          createdAt: Value(DateTime.now()),
        ));
    return await (_db.select(_db.attachments)..where((a) => a.id.equals(id)))
        .getSingle();
  }

  Future<void> remove(String id) async {
    await (_db.delete(_db.attachments)..where((a) => a.id.equals(id))).go();
  }
}