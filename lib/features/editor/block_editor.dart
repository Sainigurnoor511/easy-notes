import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_tokens.dart';
import '../../app/spacing.dart';
import '../../core/app_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../../shared/models/note_models.dart';
import '../../shared/widgets/app_widgets.dart';
import 'block_widgets.dart';
import 'checklist_editor.dart';

/// The modular block editor.
///
/// Shrink-wrapped on purpose: this sits inside the note editor's own scroll
/// view, so it must not introduce a second scrollable or an unbounded
/// [Expanded].
class BlockEditor extends ConsumerStatefulWidget {
  final String noteId;

  const BlockEditor({super.key, required this.noteId});

  @override
  ConsumerState<BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends ConsumerState<BlockEditor> {
  final Map<String, TextEditingController> _controllers = {};
  Timer? _debounce;

  TextEditingController _controllerFor(Block block) => _controllers.putIfAbsent(
      block.id, () => TextEditingController(text: block.content));

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
    await dao.insertBlockAt(widget.noteId, position: position, type: type);
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
    _controllers.remove(blockId)?.dispose();
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
    final path = await ref.read(attachmentStorageProvider).save(
          noteId: widget.noteId,
          sourcePath: result.files.first.path!,
          fileName: result.files.first.name,
        );
    final dao = ref.read(notesDaoProvider);
    await dao.updateBlockContent(blockId, path);
    await _refreshPreview();
    await dao.touch(widget.noteId);
    _kickSync();
  }

  /// Derives a plain-text preview of the document into `notes.content` so cards
  /// and search keep working for document notes.
  Future<void> _refreshPreview() async {
    final dao = ref.read(notesDaoProvider);
    final blocks = await dao.getBlocks(widget.noteId);
    final parts = <String>[];
    for (final b in blocks) {
      final include = switch (BlockType.fromDb(b.type)) {
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
    final palette = context.palette;
    final dao = ref.watch(notesDaoProvider);

    return StreamBuilder<List<Block>>(
      stream: dao.watchBlocks(widget.noteId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const InlineError(message: 'This document could not load.');
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: Spacing.xl),
            child: CenteredLoader(),
          );
        }

        final blocks = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < blocks.length; i++) _buildBlock(blocks[i], i),
            if (blocks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: Text(
                  'This document is empty. Add a block to start.',
                  style: context.texts.bodyMedium
                      ?.copyWith(color: palette.textTertiary),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: OutlinedButton.icon(
                onPressed: () => _showBlockMenu(position: blocks.length),
                icon: const Icon(Symbols.add, size: 17),
                label: const Text('Add block'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBlock(Block block, int index) {
    if (BlockType.fromDb(block.type) == BlockType.checklist) {
      return BlockRow(
        blockId: block.id,
        onDelete: _deleteBlock,
        onMove: _moveBlock,
        onAddBlock: (_) => _showBlockMenu(position: index + 1),
        child: ChecklistEditor(
          noteId: widget.noteId,
          blockId: block.id,
          onChanged: _kickSync,
        ),
      );
    }

    return BlockTile(
      block: block,
      controller: _controllerFor(block),
      onContent: _onContent,
      onDelete: _deleteBlock,
      onMove: _moveBlock,
      onConvert: _convertBlock,
      onPickImage: _pickImage,
      onAddBlock: (_) => _showBlockMenu(position: index + 1),
    );
  }

  /// Turns an existing block into another type — how the `/` palette works.
  Future<void> _convertBlock(String blockId, BlockType type) async {
    final dao = ref.read(notesDaoProvider);
    final blocks = await dao.getBlocks(widget.noteId);
    final block = blocks.firstWhere((b) => b.id == blockId);

    // Leaving a checklist behind means its items no longer have an owner.
    if (BlockType.fromDb(block.type) == BlockType.checklist &&
        type != BlockType.checklist) {
      await dao.removeChecklistItemsForBlock(blockId);
    }

    await dao.setBlockType(blockId, type);
    _controllers.remove(blockId)?.dispose();
    await _refreshPreview();
    await dao.touch(widget.noteId);
    _kickSync();
  }

  /// The slash menu, as a Level 3 sheet: an eyebrow, then rows of icon tile,
  /// monospaced command, and description.
  Future<void> _showBlockMenu({required int position}) async {
    final type = await showModalBottomSheet<BlockType>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(Spacing.sm, 0, Spacing.sm, Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                    Spacing.md, 0, Spacing.md, Spacing.sm),
                child: Eyebrow('Basic blocks'),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final entry in kBlockPalette)
                        ListTile(
                          leading: IconTile(icon: entry.icon, size: 36),
                          title: Text(entry.label,
                              style: context.texts.titleSmall),
                          subtitle: Text(entry.description,
                              style: context.texts.bodySmall),
                          trailing: Text(
                            entry.command,
                            style: context.mono
                                .copyWith(color: context.palette.textTertiary),
                          ),
                          onTap: () => Navigator.pop(context, entry.type),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (type != null) await _addBlock(position, type);
  }
}


