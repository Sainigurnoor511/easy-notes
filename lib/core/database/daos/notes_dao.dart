import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/note_models.dart';
import '../app_database.dart';

/// Wraps all note, block and checklist-item queries.
class NotesDao {
  final AppDatabase _db;
  const NotesDao(this._db);

  static const _uuid = Uuid();

  // ---------------------------------------------------------------------------
  // Note streams
  // ---------------------------------------------------------------------------

  Stream<List<Note>> watchActive() {
    final q = _orderedQuery();
    q.where((n) => n.isTrashed.equals(false) & n.isArchived.equals(false));
    return q.watch();
  }

  Stream<List<Note>> watchArchived() {
    final q = _orderedQuery();
    q.where((n) => n.isTrashed.equals(false) & n.isArchived.equals(true));
    return q.watch();
  }

  Stream<List<Note>> watchTrashed() {
    final q = _orderedQuery();
    q.where((n) => n.isTrashed.equals(true));
    return q.watch();
  }

  Stream<List<Note>> watchReminders() {
    final q = _orderedQuery();
    q.where((n) => n.isTrashed.equals(false) & n.reminderAt.isNotNull());
    return q.watch();
  }

  Stream<List<Note>> watchByLabel(String labelId) {
    final q = _db.select(_db.notes).join([
      innerJoin(_db.noteLabels, _db.noteLabels.noteId.equalsExp(_db.notes.id)),
    ])
      ..where(_db.notes.isTrashed.equals(false) &
          _db.noteLabels.labelId.equals(labelId))
      ..orderBy([
        OrderingTerm(expression: _db.notes.isPinned, mode: OrderingMode.desc),
        OrderingTerm(expression: _db.notes.updatedAt, mode: OrderingMode.desc),
      ]);
    return q.watch().map((rows) =>
        rows.map((r) => r.readTable(_db.notes)).toList());
  }

  SimpleSelectStatement<$NotesTable, Note> _orderedQuery() {
    final q = _db.select(_db.notes)
      ..orderBy([
        (n) =>
            OrderingTerm(expression: n.isPinned, mode: OrderingMode.desc),
        (n) => OrderingTerm(
            expression: n.updatedAt, mode: OrderingMode.desc),
      ]);
    return q;
  }

  Future<Note?> getById(String id) {
    return (_db.select(_db.notes)..where((n) => n.id.equals(id))).getSingleOrNull();
  }

  Stream<Note?> watchById(String id) {
    return (_db.select(_db.notes)..where((n) => n.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Latest [Note.updatedAt] across all notes. Used for sync decisions.
  Future<DateTime?> maxUpdatedAt() async {
    final rows = await (_db.select(_db.notes)
          ..orderBy([
            (n) =>
                OrderingTerm(expression: n.updatedAt, mode: OrderingMode.desc)
          ])
          ..limit(1))
        .get();
    return rows.isEmpty ? null : rows.first.updatedAt;
  }

  Future<List<Note>> getNotesByIds(List<String> ids) {
    if (ids.isEmpty) return Future.value(const []);
    return (_db.select(_db.notes)..where((n) => n.id.isIn(ids))).get();
  }

  // ---------------------------------------------------------------------------
  // Note mutations
  // ---------------------------------------------------------------------------

  Future<Note> createNote({
    required String title,
    String content = '',
    NoteType type = NoteType.text,
    String? color,
    DateTime? reminderAt,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.into(_db.notes).insert(NotesCompanion.insert(
          id: id,
          title: Value(title),
          content: Value(content),
          noteType: Value(type.name),
          color: Value(color),
          reminderAt: Value(reminderAt),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
    return (await getById(id))!;
  }

  Future<void> updateNote(
    String id, {
    String? title,
    String? content,
    String? color,
    DateTime? reminderAt,
    bool? clearReminder,
  }) async {
    final now = DateTime.now();
    await (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        title: title == null ? const Value.absent() : Value(title),
        content: content == null ? const Value.absent() : Value(content),
        color: color == null ? const Value.absent() : Value(color),
        reminderAt: clearReminder == true
            ? const Value(null)
            : reminderAt == null
                ? const Value.absent()
                : Value(reminderAt),
        updatedAt: Value(now),
      ),
    );
  }

  /// Bumps updatedAt without touching content. Used after child edits.
  Future<void> touch(String id) async {
    await (_db.update(_db.notes)..where((n) => n.id.equals(id)))
        .write(NotesCompanion(updatedAt: Value(DateTime.now())));
  }

  Future<void> setPinned(String id, bool pinned) async {
    await (_db.update(_db.notes)..where((n) => n.id.equals(id)))
        .write(NotesCompanion(
      isPinned: Value(pinned),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> setArchived(String id, bool archived) async {
    await (_db.update(_db.notes)..where((n) => n.id.equals(id)))
        .write(NotesCompanion(
      isArchived: Value(archived),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> trash(String id) async {
    await (_db.update(_db.notes)..where((n) => n.id.equals(id)))
        .write(NotesCompanion(
      isTrashed: Value(true),
      deletedAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> restore(String id) async {
    await (_db.update(_db.notes)..where((n) => n.id.equals(id)))
        .write(NotesCompanion(
      isTrashed: Value(false),
      deletedAt: const Value(null),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Permanent delete. Attachments files must be removed by the caller.
  Future<void> permanentlyDelete(String id) async {
    await (_db.delete(_db.notes)..where((n) => n.id.equals(id))).go();
  }

  Future<String> duplicate(String id) async {
    final note = await getById(id);
    if (note == null) throw StateError('Note $id not found');
    final newId = _uuid.v4();
    final now = DateTime.now();
    await _db.transaction(() async {
      await _db.into(_db.notes).insert(NotesCompanion.insert(
            id: newId,
            title: Value(note.title),
            content: Value(note.content),
            noteType: Value(note.noteType),
            color: Value(note.color),
            isPinned: Value(note.isPinned),
            reminderAt: Value(note.reminderAt),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));
      final blocks =
          await (_db.select(_db.blocks)..where((b) => b.noteId.equals(id)))
              .get();
      for (final b in blocks) {
        await _db.into(_db.blocks).insert(BlocksCompanion.insert(
              id: _uuid.v4(),
              noteId: newId,
              type: b.type,
              position: b.position,
              content: Value(b.content),
              createdAt: Value(now),
              updatedAt: Value(now),
            ));
      }
      final items = await (_db.select(_db.checklistItems)
            ..where((c) => c.noteId.equals(id)))
          .get();
      for (final c in items) {
        await _db.into(_db.checklistItems).insert(ChecklistItemsCompanion.insert(
              id: _uuid.v4(),
              noteId: newId,
              blockId: Value(c.blockId),
              content: Value(c.content),
              isCompleted: Value(c.isCompleted),
              position: c.position,
            ));
      }
      final noteLabels = await (_db.select(_db.noteLabels)
            ..where((nl) => nl.noteId.equals(id)))
          .get();
      for (final nl in noteLabels) {
        await _db.into(_db.noteLabels).insert(
              NoteLabelsCompanion.insert(
                  noteId: newId, labelId: nl.labelId),
            );
      }
    });
    return newId;
  }

  // ---------------------------------------------------------------------------
  // Blocks
  // ---------------------------------------------------------------------------

  Future<List<Block>> getBlocks(String noteId) {
    return (_db.select(_db.blocks)
          ..where((b) => b.noteId.equals(noteId))
          ..orderBy([(b) => OrderingTerm(expression: b.position)]))
        .get();
  }

  Stream<List<Block>> watchBlocks(String noteId) {
    return (_db.select(_db.blocks)
          ..where((b) => b.noteId.equals(noteId))
          ..orderBy([(b) => OrderingTerm(expression: b.position)]))
        .watch();
  }

  /// Inserts a block at [position] by rebuilding the ordered block list.
  /// Keeps positions contiguous 0..n-1.
  Future<Block> insertBlockAt(
    String noteId, {
    required int position,
    required BlockType type,
    String content = '',
  }) async {
    final blocks = await getBlocks(noteId);
    final now = DateTime.now();
    final block = Block(
      id: _uuid.v4(),
      noteId: noteId,
      type: type.name,
      position: position,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    final updated = [
      ...blocks.take(position),
      block,
      ...blocks.skip(position),
    ];
    await replaceBlocks(noteId, updated);
    return block;
  }

  Future<void> updateBlockContent(String id, String content) async {
    await (_db.update(_db.blocks)..where((b) => b.id.equals(id)))
        .write(BlocksCompanion(
      content: Value(content),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Removes a block and renumbers the rest.
  Future<void> deleteBlockAt(String noteId, String id) async {
    final blocks = await getBlocks(noteId);
    blocks.removeWhere((b) => b.id == id);
    await replaceBlocks(noteId, blocks);
  }

  /// Swaps a block with its neighbour by rebuilding the ordered list.
  /// Returns false when out of bounds.
  Future<bool> moveBlock(String noteId, String blockId, {required bool up}) async {
    final blocks = await getBlocks(noteId);
    final idx = blocks.indexWhere((b) => b.id == blockId);
    final target = up ? idx - 1 : idx + 1;
    if (idx < 0 || target < 0 || target >= blocks.length) return false;
    final a = blocks[idx];
    final b = blocks[target];
    blocks[idx] = b;
    blocks[target] = a;
    await replaceBlocks(noteId, blocks);
    return true;
  }

  /// Rebuilds all blocks of a note in one transaction. Used on full saves.
  Future<void> replaceBlocks(String noteId, List<Block> blocks) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.delete(_db.blocks)..where((b) => b.noteId.equals(noteId))).go();
      for (var i = 0; i < blocks.length; i++) {
        await _db.into(_db.blocks).insert(BlocksCompanion.insert(
              id: blocks[i].id,
              noteId: noteId,
              type: blocks[i].type,
              position: i,
              content: Value(blocks[i].content),
              createdAt: Value(now),
              updatedAt: Value(now),
            ));
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Checklist items
  // ---------------------------------------------------------------------------

  Future<List<ChecklistItem>> getChecklistItems(String noteId) {
    return (_db.select(_db.checklistItems)
          ..where((c) => c.noteId.equals(noteId))
          ..orderBy([(c) => OrderingTerm(expression: c.position)]))
        .get();
  }

  Stream<List<ChecklistItem>> watchChecklistItems(String noteId) {
    return (_db.select(_db.checklistItems)
          ..where((c) => c.noteId.equals(noteId))
          ..orderBy([(c) => OrderingTerm(expression: c.position)]))
        .watch();
  }

  /// Checklist items scoped to a block (blockId != null) or to the note
  /// itself (blockId == null, used by checklist notes).
  Stream<List<ChecklistItem>> watchChecklistItemsFor({
    required String noteId,
    String? blockId,
  }) {
    final q = _db.select(_db.checklistItems)
      ..orderBy([(c) => OrderingTerm(expression: c.position)]);
    if (blockId == null) {
      q.where((c) => c.noteId.equals(noteId) & c.blockId.isNull());
    } else {
      q.where((c) => c.noteId.equals(noteId) & c.blockId.equals(blockId));
    }
    return q.watch();
  }

  Future<void> addChecklistItem(String noteId, String text,
      {String? blockId}) async {
    final items =
        await (_db.select(_db.checklistItems)..where((c) => c.noteId.equals(noteId)))
            .get();
    await _db.into(_db.checklistItems).insert(ChecklistItemsCompanion.insert(
          id: _uuid.v4(),
          noteId: noteId,
          blockId: Value(blockId),
          content: Value(text),
          isCompleted: Value(false),
          position: items.length,
        ));
  }

  Future<void> setChecklistItemText(String id, String text) async {
    await (_db.update(_db.checklistItems)..where((c) => c.id.equals(id)))
        .write(ChecklistItemsCompanion(content: Value(text)));
  }

  Future<void> setChecklistItemCompleted(String id, bool completed) async {
    await (_db.update(_db.checklistItems)..where((c) => c.id.equals(id)))
        .write(ChecklistItemsCompanion(isCompleted: Value(completed)));
  }

  Future<void> removeChecklistItem(String id) async {
    await (_db.delete(_db.checklistItems)..where((c) => c.id.equals(id))).go();
  }

  Future<ChecklistItem?> getChecklistItem(String id) {
    return (_db.select(_db.checklistItems)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// Removes checklist items owned by a (now deleted) checklist block.
  Future<void> removeChecklistItemsForBlock(String blockId) async {
    await (_db.delete(_db.checklistItems)
          ..where((c) => c.blockId.equals(blockId)))
        .go();
  }

  Future<void> replaceChecklistItems(
      String noteId, List<ChecklistItem> items) async {
    await _db.transaction(() async {
      await (_db.delete(_db.checklistItems)
            ..where((c) => c.noteId.equals(noteId)))
          .go();
      for (var i = 0; i < items.length; i++) {
        await _db.into(_db.checklistItems).insert(ChecklistItemsCompanion.insert(
              id: items[i].id,
              noteId: noteId,
              blockId: Value(items[i].blockId),
              content: Value(items[i].content),
              isCompleted: Value(items[i].isCompleted),
              position: i,
            ));
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Search (LIKE-based; offline)
  // ---------------------------------------------------------------------------

  Future<List<Note>> search(String query) async {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return const [];
    final like = '%$term%';
    final noteIds = <String>{};

    final titleHits = await (_db.select(_db.notes)
          ..where((n) =>
              n.isTrashed.equals(false) &
              (n.title.lower().like(like) | n.content.lower().like(like))))
        .get();
    noteIds.addAll(titleHits.map((e) => e.id));

    final blockHits = await (_db.select(_db.blocks)
          ..where((b) => b.content.lower().like(like)))
        .get();
    noteIds.addAll(blockHits.map((e) => e.noteId));

    final itemHits = await (_db.select(_db.checklistItems)
          ..where((c) => c.content.lower().like(like)))
        .get();
    noteIds.addAll(itemHits.map((e) => e.noteId));

    final labelHits = await (_db.select(_db.labels)
          ..where((l) => l.name.lower().like(like)))
        .get();
    if (labelHits.isNotEmpty) {
      final labelIds = labelHits.map((e) => e.id).toList();
      final nlHits = await (_db.select(_db.noteLabels)
            ..where((nl) => nl.labelId.isIn(labelIds)))
          .get();
      noteIds.addAll(nlHits.map((e) => e.noteId));
    }

    if (noteIds.isEmpty) return const [];
    return getNotesByIds(noteIds.toList());
  }
}