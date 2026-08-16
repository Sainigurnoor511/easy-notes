import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../../shared/models/note_models.dart';
import 'block_widgets.dart';
import 'checklist_editor.dart';

class BlockEditor extends ConsumerStatefulWidget {
  final String noteId;

  const BlockEditor({super.key, required this.noteId});

  @override
  ConsumerState<BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends ConsumerState<BlockEditor> {
  final Map<String, TextEditingController> _controllers = {};
  Timer? _debounce;
  int _blockCount = 0;

  TextEditingController _controllerFor(Block block) => _controllers.putIfAbsent(
      block.id,
      () => TextEditingController(text: block.content));

  void _onContent(String blockId, String content) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final dao = ref.read(notesDaoProvider);
      await dao.updateBlockContent(blockId, content);
      await _refreshPreview();
      await dao.touch(widget.noteId);
      _kickSync();
    });
  }

  Future<void> _addBlock(int position, BlockType type) async {
    final dao = ref.read(notesDaoProvider);
    await dao.insertBlockAt(widget.noteId,
        position: position, type: type);
    await _refreshPreview();
    await dao.touch(widget.noteId);
    _kickSync();
  }

  Future<void> _deleteBlock(String blockId) async {
    final dao = ref.read(notesDaoProvider);
    final blocks = await dao.getBlocks(widget.noteId);
    final block = blocks.firstWhere((b) => b.id == blockId);
    if (BlockType.fromDb(block.type) == BlockType.checklist) {
      await dao.removeChecklistItemsForBlock(blockId);
    }
    await dao.deleteBlockAt(widget.noteId, blockId);
    await _refreshPreview();
    await dao.touch(widget.noteId);
    _kickSync();
  }

  Future<void> _moveBlock(String blockId, bool up) async {
    final dao = ref.read(notesDaoProvider);
    await dao.moveBlock(widget.noteId, blockId, up: up);
    await dao.touch(widget.noteId);
    _kickSync();
  }

  Future<void> _pickImage(String blockId) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final sourcePath = result.files.first.path!;
    final fileName = result.files.first.name;
    final path = await ref.read(attachmentStorageProvider).save(
        noteId: widget.noteId, sourcePath: sourcePath, fileName: fileName);
    final dao = ref.read(notesDaoProvider);
    await dao.updateBlockContent(blockId, path);
    await _refreshPreview();
    await dao.touch(widget.noteId);
    _kickSync();
  }

  /// Derives a plain-text preview of the document into `notes.content`
  /// so cards and search keep working for document notes.
  Future<void> _refreshPreview() async {
    final dao = ref.read(notesDaoProvider);
    final blocks = await dao.getBlocks(widget.noteId);
    final parts = <String>[];
    for (final b in blocks) {
      final t = BlockType.fromDb(b.type);
      final include = switch (t) {
        BlockType.text ||
        BlockType.bullet ||
        BlockType.numberedList ||
        BlockType.quote ||
        BlockType.code =>
          b.content.trim(),
        BlockType.heading => _stripHeadingMarker(b.content),
        _ => '',
      };
      if (include.isNotEmpty) parts.add(include);
    }
    var preview = parts.join('\n');
    if (preview.length > 250) preview = preview.substring(0, 250);
    await dao.updateNote(widget.noteId, content: preview);
  }

  String _stripHeadingMarker(String content) {
    final idx = content.indexOf('|');
    if (idx > 0 && idx < 4) return content.substring(idx + 1);
    return content;
  }

  void _kickSync() {
    unawaited(ref.read(syncControllerProvider.notifier).syncNow());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(notesDaoProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: StreamBuilder<List<Block>>(
            stream: dao.watchBlocks(widget.noteId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snapshot.data!;
              _blockCount = list.length;
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: list.length,
                itemBuilder: (context, i) => _buildBlock(list[i], i),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _showAddMenu(listLength: _blockCount),
              icon: const Icon(Icons.add),
              label: const Text('Add block'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlock(Block block, int index) {
    final type = BlockType.fromDb(block.type);
    if (type == BlockType.checklist) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: BlockRow(
          blockId: block.id,
          onDelete: _deleteBlock,
          onMove: _moveBlock,
          child: ChecklistEditor(
            noteId: widget.noteId,
            blockId: block.id,
            onChanged: _kickSync,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: BlockTile(
        block: block,
        controller: _controllerFor(block),
        onContent: _onContent,
        onDelete: _deleteBlock,
        onMove: _moveBlock,
        onPickImage: (id) => _pickImage(id),
        onAddBlock: (id) => _showAddMenu(listLength: index + 1),
      ),
    );
  }

  Future<void> _showAddMenu({required int listLength}) async {
    final type = await showModalBottomSheet<BlockType>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final entry in _blockTypeEntries)
              ListTile(
                leading: Icon(entry.$2),
                title: Text(entry.$1),
                onTap: () => Navigator.pop(context, entry.$3),
              ),
          ],
        ),
      ),
    );
    if (type != null) {
      await _addBlock(listLength, type);
    }
  }
}

const List<(String, IconData, BlockType)> _blockTypeEntries = [
  ('Text', Icons.title, BlockType.text),
  ('Heading', Icons.text_fields, BlockType.heading),
  ('Checklist', Icons.checklist, BlockType.checklist),
  ('Bullet list', Icons.format_list_bulleted, BlockType.bullet),
  ('Numbered list', Icons.format_list_numbered, BlockType.numberedList),
  ('Quote', Icons.format_quote, BlockType.quote),
  ('Code', Icons.code, BlockType.code),
  ('Table', Icons.table_chart, BlockType.table),
  ('Image', Icons.image, BlockType.image),
  ('Divider', Icons.horizontal_rule, BlockType.divider),
];