import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_notes/core/database/app_database.dart';
import 'package:easy_notes/core/database/daos/notes_dao.dart';
import 'package:easy_notes/shared/models/note_models.dart';

void main() {
  late AppDatabase db;
  late NotesDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = NotesDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('createNote persists and getById returns it', () async {
    final note = await dao.createNote(title: 'Hello', content: 'World');
    final fetched = await dao.getById(note.id);
    expect(fetched?.title, 'Hello');
    expect(fetched?.content, 'World');
  });

  test('setPinned updates the note', () async {
    final note = await dao.createNote(title: 'Pin me');
    await dao.setPinned(note.id, true);
    final fetched = await dao.getById(note.id);
    expect(fetched?.isPinned, true);
  });

  test('trash then restore clears and resets isTrashed', () async {
    final note = await dao.createNote(title: 'Trash me');
    await dao.trash(note.id);
    expect((await dao.getById(note.id))?.isTrashed, true);
    await dao.restore(note.id);
    expect((await dao.getById(note.id))?.isTrashed, false);
  });

  test('addChecklistItem then getChecklistItems returns it', () async {
    final note = await dao.createNote(title: 'List', type: NoteType.checklist);
    await dao.addChecklistItem(note.id, 'Buy milk');
    final items = await dao.getChecklistItems(note.id);
    expect(items, hasLength(1));
    expect(items.first.content, 'Buy milk');
  });
}
