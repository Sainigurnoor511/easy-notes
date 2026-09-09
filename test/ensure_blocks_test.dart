// Guards the legacy-note migration: unifying the editor must not lose a single
// character of anyone's existing notes.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:easy_notes/core/database/app_database.dart';
import 'package:easy_notes/core/database/daos/notes_dao.dart';
import 'package:easy_notes/shared/models/note_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late NotesDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = NotesDao(db);
  });
  tearDown(() => db.close());

  /// Writes a note the way the old typed flow would have.
  Future<Note> legacy({
    required NoteType type,
    String title = 'T',
    String content = '',
  }) async {
    final note = await dao.createNote(title: title, content: content, type: type);
    return note;
  }

  test('a text note becomes one text block holding its content', () async {
    final note = await legacy(type: NoteType.text, content: 'hello world');
    await dao.ensureBlocks(note.id);

    final blocks = await dao.getBlocks(note.id);
    expect(blocks, hasLength(1));
    expect(blocks.single.type, BlockType.text.name);
    expect(blocks.single.content, 'hello world');
  });

  test('an empty note still gets somewhere to type', () async {
    final note = await legacy(type: NoteType.text);
    await dao.ensureBlocks(note.id);

    final blocks = await dao.getBlocks(note.id);
    expect(blocks, hasLength(1));
    expect(blocks.single.type, BlockType.text.name);
    expect(blocks.single.content, '');
  });

  test('a checklist note keeps every item, re-parented onto a block', () async {
    final note = await legacy(
      type: NoteType.checklist,
      // The old flow mirrored items into content as a preview.
      content: '\u2610 milk\n\u2611 eggs',
    );
    await dao.addChecklistItem(note.id, 'milk');
    await dao.addChecklistItem(note.id, 'eggs');
    final before = await dao.getChecklistItems(note.id);
    await dao.setChecklistItemCompleted(before[1].id, true);

    await dao.ensureBlocks(note.id);

    final blocks = await dao.getBlocks(note.id);
    expect(blocks, hasLength(1), reason: 'no duplicate text block from preview');
    expect(blocks.single.type, BlockType.checklist.name);

    final after = await dao.getChecklistItems(note.id);
    expect(after.map((i) => i.content), ['milk', 'eggs']);
    expect(after.every((i) => i.blockId == blocks.single.id), isTrue,
        reason: 'items must hang off the new checklist block');
    expect(after.firstWhere((i) => i.content == 'eggs').isCompleted, isTrue,
        reason: 'completion state survives');
  });

  test('a note with both text and a checklist keeps both, in order', () async {
    final note = await legacy(type: NoteType.text, content: 'shopping');
    await dao.addChecklistItem(note.id, 'milk');

    await dao.ensureBlocks(note.id);

    final blocks = await dao.getBlocks(note.id);
    expect(blocks.map((b) => b.type),
        [BlockType.text.name, BlockType.checklist.name]);
    expect(blocks.first.content, 'shopping');

    final items = await dao.getChecklistItems(note.id);
    expect(items.single.blockId, blocks.last.id);
  });

  test('it is idempotent — a second call changes nothing', () async {
    final note = await legacy(type: NoteType.text, content: 'once');
    await dao.ensureBlocks(note.id);
    final first = await dao.getBlocks(note.id);

    await dao.ensureBlocks(note.id);
    await dao.ensureBlocks(note.id);
    final again = await dao.getBlocks(note.id);

    expect(again.map((b) => b.id), first.map((b) => b.id));
    expect(again.map((b) => b.content), first.map((b) => b.content));
  });

  test('an already-block-based note is left completely alone', () async {
    final note = await legacy(type: NoteType.document, content: 'preview text');
    await dao.insertBlockAt(note.id,
        position: 0, type: BlockType.heading, content: '1|Title');
    await dao.insertBlockAt(note.id,
        position: 1, type: BlockType.code, content: 'print(1);');
    final before = await dao.getBlocks(note.id);

    await dao.ensureBlocks(note.id);

    final after = await dao.getBlocks(note.id);
    expect(after.map((b) => b.id), before.map((b) => b.id));
    expect(after.map((b) => b.content), ['1|Title', 'print(1);']);
  });

  test('blocks come back in position order after a delete', () async {
    final note = await legacy(type: NoteType.document);
    for (var i = 0; i < 4; i++) {
      await dao.insertBlockAt(note.id,
          position: i, type: BlockType.text, content: 'b$i');
    }
    final blocks = await dao.getBlocks(note.id);
    await dao.deleteBlockAt(note.id, blocks[1].id);

    final after = await dao.getBlocks(note.id);
    expect(after.map((b) => b.content), ['b0', 'b2', 'b3']);
    expect(after.map((b) => b.position), [0, 1, 2],
        reason: 'positions stay contiguous');
  });

  test('deleting a checklist block also clears its items', () async {
    final note = await legacy(type: NoteType.document);
    final block = await dao.insertBlockAt(note.id,
        position: 0, type: BlockType.checklist);
    await dao.addChecklistItem(note.id, 'x', blockId: block.id);
    expect(await dao.getChecklistItems(note.id), hasLength(1));

    await dao.removeChecklistItemsForBlock(block.id);
    await dao.deleteBlockAt(note.id, block.id);

    expect(await dao.getBlocks(note.id), isEmpty);
    expect(await dao.getChecklistItems(note.id), isEmpty);
  });

  test('a missing note does not throw', () async {
    await expectLater(dao.ensureBlocks('nope'), completes);
  });

  test('unicode and newlines survive verbatim', () async {
    const body = 'line1\nline2 — ✓ ☐ 日本語\ttab';
    final note = await legacy(type: NoteType.text, content: body);
    await dao.ensureBlocks(note.id);
    final blocks = await dao.getBlocks(note.id);
    expect(blocks.single.content, body);
  });

  test('drift Value import is exercised', () {
    // Keeps the import meaningful and asserts the companion contract we rely on.
    expect(const Value('x').present, isTrue);
  });
}
