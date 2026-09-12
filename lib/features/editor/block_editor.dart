import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_tokens.dart';
import '../../app/spacing.dart';
import '../../core/app_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/database/daos/notes_dao.dart';
import '../../core/database/database_providers.dart';
import '../../shared/models/note_models.dart';
import '../../shared/widgets/app_widgets.dart';
import 'block_widgets.dart';
import 'checklist_editor.dart';

class BlockEditorController {
  Future<void> Function()? _flush;
  Future<void> Function(Future<void> Function())? _runStructural;

  Future<void> flush() => _flush?.call() ?? Future<void>.value();

  Future<void> runStructural(Future<void> Function() action) =>
      _runStructural?.call(action) ?? action();
}

class BlockEditor extends ConsumerStatefulWidget {
  final String noteId;
  final BlockEditorController? controller;

  const BlockEditor({super.key, required this.noteId, this.controller});

  @override
  ConsumerState<BlockEditor> createState() => _BlockEditorState();

  static Future<BlockType?> showBlockPalette(BuildContext context) {
    return showModalBottomSheet<BlockType>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final height = math.min(
          560.0,
          math.max(320.0, MediaQuery.sizeOf(context).height * 0.72),
        );
        return SafeArea(
          child: SizedBox(
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    Spacing.lg,
                    0,
                    Spacing.lg,
                    Spacing.sm,
                  ),
                  child: Eyebrow('Basic blocks'),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.sm,
                      0,
                      Spacing.sm,
                      Spacing.lg,
                    ),
                    itemCount: kBlockPalette.length,
                    itemBuilder: (context, index) {
                      final entry = kBlockPalette[index];
                      return ListTile(
                        leading: IconTile(icon: entry.icon, size: 36),
                        title: Text(
                          entry.label,
                          style: context.texts.titleSmall,
                        ),
                        subtitle: Text(
                          entry.description,
                          style: context.texts.bodySmall,
                        ),
                        trailing: Text(
                          entry.command,
                          style: context.mono.copyWith(
                            color: context.palette.textTertiary,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, entry.type),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BlockEditorState extends ConsumerState<BlockEditor> {
  final Map<String, TextEditingController> _controllers = {};
  Future<void> _writeQueue = Future<void>.value();
  Timer? _debounce;
  bool _previewDirty = false;
  int _editGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?._flush = _flushPendingWrites;
    widget.controller?._runStructural = _runStructural;
  }

  TextEditingController _controllerFor(Block block) => _controllers.putIfAbsent(
    block.id,
    () => TextEditingController(text: block.content),
  );

  void _onContent(String blockId, String content) {
    final dao = ref.read(notesDaoProvider);
    _writeQueue = _writeQueue
        .catchError((_) {})
        .then((_) => dao.updateBlockContent(blockId, content));
    unawaited(_writeQueue.catchError((_) {}));

    _previewDirty = true;
    final generation = ++_editGeneration;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _finalizeGeneration(generation),
    );
  }

  Future<void> _finalizeGeneration(int generation) async {
    final queued = _writeQueue;
    await queued;
    if (!mounted || generation != _editGeneration || queued != _writeQueue) {
      return;
    }
    final dao = ref.read(notesDaoProvider);
    await _refreshPreviewWithDao(dao);
    await dao.touch(widget.noteId);
    if (!mounted || generation != _editGeneration) return;
    _previewDirty = false;
    _kickSync();
  }

  Future<void> _flushPendingWrites() => _runStructural(() async {});

  Future<void> _runStructural(Future<void> Function() action) {
    _debounce?.cancel();
    final completer = Completer<void>();
    final operation = _writeQueue.catchError((_) {}).then((_) async {
      final dao = ref.read(notesDaoProvider);
      if (_previewDirty) {
        await _refreshPreviewWithDao(dao);
        await dao.touch(widget.noteId);
        _previewDirty = false;
      }
      await action();
    });
    _writeQueue = operation;
    unawaited(
      operation.then(completer.complete).catchError(completer.completeError),
    );
    return completer.future;
  }

  Future<void> _addBlock(int position, BlockType type) {
    return _runStructural(() async {
      final dao = ref.read(notesDaoProvider);
      await dao.insertBlockAt(widget.noteId, position: position, type: type);
      await _refreshPreviewWithDao(dao);
      await dao.touch(widget.noteId);
      _kickSync();
    });
  }

  Future<void> _deleteBlock(String blockId) {
    return _runStructural(() async {
      final dao = ref.read(notesDaoProvider);
      final blocks = await dao.getBlocks(widget.noteId);
      final block = blocks.firstWhere((block) => block.id == blockId);
      if (BlockType.fromDb(block.type) == BlockType.checklist) {
        await dao.removeChecklistItemsForBlock(blockId);
      }
      await dao.deleteBlockAt(widget.noteId, blockId);
      _controllers.remove(blockId)?.dispose();
      await _refreshPreviewWithDao(dao);
      await dao.touch(widget.noteId);
      _kickSync();
    });
  }

  Future<void> _moveBlock(String blockId, bool up) {
    return _runStructural(() async {
      final dao = ref.read(notesDaoProvider);
      await dao.moveBlock(widget.noteId, blockId, up: up);
      await dao.touch(widget.noteId);
      _kickSync();
    });
  }

  Future<void> _pickImage(String blockId) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    await _runStructural(() async {
      final path = await ref
          .read(attachmentStorageProvider)
          .save(
            noteId: widget.noteId,
            sourcePath: result.files.first.path!,
            fileName: result.files.first.name,
          );
      final dao = ref.read(notesDaoProvider);
      await dao.updateBlockContent(blockId, path);
      await _refreshPreviewWithDao(dao);
      await dao.touch(widget.noteId);
      _kickSync();
    });
  }

  Future<void> _refreshPreviewWithDao(NotesDao dao) async {
    final blocks = await dao.getBlocks(widget.noteId);
    final parts = <String>[];
    for (final b in blocks) {
      final include = switch (BlockType.fromDb(b.type)) {
        BlockType.text ||
        BlockType.bullet ||
        BlockType.numberedList ||
        BlockType.quote ||
        BlockType.code => b.content.trim(),
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
    widget.controller?._flush = null;
    widget.controller?._runStructural = null;
    _debounce?.cancel();
    if (_previewDirty) {
      final dao = ref.read(notesDaoProvider);
      final sync = ref.read(syncControllerProvider.notifier);
      final queued = _writeQueue;
      unawaited(
        queued.then((_) async {
          await _refreshPreviewWithDao(dao);
          await dao.touch(widget.noteId);
          await sync.syncNow();
        }),
      );
    }
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
                  style: context.texts.bodyMedium?.copyWith(
                    color: palette.textTertiary,
                  ),
                ),
              ),
            // No trailing "Add block" button: both layouts now carry one in
            // their own action row, and a third in the flow would be the same
            // command in two places on one screen.
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

  Future<void> _convertBlock(String blockId, BlockType type) {
    return _runStructural(() async {
      final dao = ref.read(notesDaoProvider);
      final blocks = await dao.getBlocks(widget.noteId);
      final block = blocks.firstWhere((block) => block.id == blockId);
      if (BlockType.fromDb(block.type) == BlockType.checklist &&
          type != BlockType.checklist) {
        await dao.removeChecklistItemsForBlock(blockId);
      }
      await dao.setBlockType(blockId, type);
      _controllers.remove(blockId)?.dispose();
      await _refreshPreviewWithDao(dao);
      await dao.touch(widget.noteId);
      _kickSync();
    });
  }

  Future<void> _showBlockMenu({required int position}) async {
    final type = await BlockEditor.showBlockPalette(context);
    if (type != null) await _addBlock(position, type);
  }
}
