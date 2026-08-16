import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../shared/models/note_models.dart';
import 'attachment_preview_io.dart'
    if (dart.library.js_interop) 'attachment_preview_web.dart';

/// Shared callbacks every block tile reports to.
typedef BlockOnContent = void Function(String blockId, String content);
typedef BlockOnDelete = void Function(String blockId);
typedef BlockOnMove = void Function(String blockId, bool up);

const int kHeadingDefault = 2;

int _headingLevelOf(String content) {
  if (content.isEmpty) return kHeadingDefault;
  final idx = content.indexOf('|');
  if (idx > 0 && idx < 4) {
    final level = int.tryParse(content.substring(0, idx));
    if (level != null && level >= 1 && level <= 3) return level;
  }
  return kHeadingDefault;
}

String _headingTextOf(String content) {
  final idx = content.indexOf('|');
  if (idx > 0 && idx < 4) return content.substring(idx + 1);
  return content;
}

String _encodeHeading(String text, int level) => '$level|$text';

class BlockTile extends StatelessWidget {
  final Block block;
  final TextEditingController controller;
  final BlockOnContent onContent;
  final BlockOnDelete onDelete;
  final BlockOnMove onMove;
  final Future<void> Function(String blockId)? onPickImage;
  final void Function(String blockId)? onAddBlock;

  const BlockTile({
    super.key,
    required this.block,
    required this.controller,
    required this.onContent,
    required this.onDelete,
    required this.onMove,
    this.onPickImage,
    this.onAddBlock,
  });

  @override
  Widget build(BuildContext context) {
    final type = BlockType.fromDb(block.type);
    return switch (type) {
      BlockType.text => _textBlock(context),
      BlockType.heading => _headingBlock(context),
      BlockType.bullet => _bulletBlock(context),
      BlockType.numberedList => _numberedBlock(context),
      BlockType.quote => _quoteBlock(context),
      BlockType.code => _codeBlock(context),
      BlockType.divider => _dividerBlock(context),
      BlockType.table => TableBlockWidget(
          block: block,
          onContent: onContent,
          onDelete: onDelete,
          onMove: onMove,
        ),
      BlockType.checklist => Container(),
      BlockType.image => _imageBlock(context),
    };
  }

  Widget _textBlock(BuildContext context) {
    return BlockRow(
      onDelete: onDelete,
      onMove: onMove,
      onAddBlock: onAddBlock,
      blockId: block.id,
      child: TextField(
        controller: controller,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: const InputDecoration(
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
        onChanged: (v) => onContent(block.id, v),
      ),
    );
  }

  Widget _headingBlock(BuildContext context) {
    return HeadingBlock(
      block: block,
      onContent: onContent,
      onDelete: onDelete,
      onMove: onMove,
      onAddBlock: onAddBlock,
    );
  }

  Widget _bulletBlock(BuildContext context) {
    return BlockRow(
      onDelete: onDelete,
      onMove: onMove,
      onAddBlock: onAddBlock,
      blockId: block.id,
      leading: const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: Text('\u2022'),
      ),
      child: TextField(
        controller: controller,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
        onChanged: (v) => onContent(block.id, v),
      ),
    );
  }

  Widget _numberedBlock(BuildContext context) {
    return BlockRow(
      onDelete: onDelete,
      onMove: onMove,
      onAddBlock: onAddBlock,
      blockId: block.id,
      leading: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text('${block.position + 1}.'),
      ),
      child: TextField(
        controller: controller,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
        onChanged: (v) => onContent(block.id, v),
      ),
    );
  }

  Widget _quoteBlock(BuildContext context) {
    return BlockRow(
      onDelete: onDelete,
      onMove: onMove,
      onAddBlock: onAddBlock,
      blockId: block.id,
      leading: Container(width: 3, height: 36, color: Colors.grey),
      child: TextField(
        controller: controller,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(fontStyle: FontStyle.italic),
        decoration: const InputDecoration(
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
        onChanged: (v) => onContent(block.id, v),
      ),
    );
  }

  Widget _codeBlock(BuildContext context) {
    return BlockRow(
      onDelete: onDelete,
      onMove: onMove,
      onAddBlock: onAddBlock,
      blockId: block.id,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(10),
        child: TextField(
          controller: controller,
          maxLines: null,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: const InputDecoration(
              border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
          onChanged: (v) => onContent(block.id, v),
        ),
      ),
    );
  }

  Widget _dividerBlock(BuildContext context) {
    return BlockRow(
      onDelete: onDelete,
      onMove: onMove,
      onAddBlock: onAddBlock,
      blockId: block.id,
      child: const Divider(height: 24),
    );
  }

  Widget _imageBlock(BuildContext context) {
    return BlockRow(
      onDelete: onDelete,
      onMove: onMove,
      onAddBlock: onAddBlock,
      blockId: block.id,
      onTap: () => onPickImage?.call(block.id),
      child: blockImagePreview(block.content, () => _pickHint(context)),
    );
  }

  Widget _pickHint(BuildContext context) => Container(
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Tap to attach image'),
      );
}

class HeadingBlock extends StatefulWidget {
  final Block block;
  final BlockOnContent onContent;
  final BlockOnDelete onDelete;
  final BlockOnMove onMove;
  final void Function(String blockId)? onAddBlock;

  const HeadingBlock({
    super.key,
    required this.block,
    required this.onContent,
    required this.onDelete,
    required this.onMove,
    this.onAddBlock,
  });

  @override
  State<HeadingBlock> createState() => _HeadingBlockState();
}

class _HeadingBlockState extends State<HeadingBlock> {
  late int _level;
  late TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _level = _headingLevelOf(widget.block.content);
    _text = TextEditingController(text: _headingTextOf(widget.block.content));
  }

  void _save() {
    widget.onContent(widget.block.id, _encodeHeading(_text.text, _level));
  }

  @override
  Widget build(BuildContext context) {
    final style = switch (_level) {
      1 => Theme.of(context).textTheme.headlineSmall,
      2 => Theme.of(context).textTheme.titleLarge,
      _ => Theme.of(context).textTheme.titleMedium,
    };
    return BlockRow(
      onDelete: widget.onDelete,
      onMove: widget.onMove,
      onAddBlock: widget.onAddBlock,
      blockId: widget.block.id,
      leading: DropdownButton<int>(
        value: _level,
        underline: const SizedBox.shrink(),
        isDense: true,
        onChanged: (l) {
          setState(() => _level = l ?? kHeadingDefault);
          _save();
        },
        items: const [
          DropdownMenuItem(value: 1, child: Text('H1')),
          DropdownMenuItem(value: 2, child: Text('H2')),
          DropdownMenuItem(value: 3, child: Text('H3')),
        ],
      ),
      child: TextField(
        controller: _text,
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        style: style,
        decoration: const InputDecoration(
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
        onChanged: (_) => _save(),
      ),
    );
  }
}

class BlockRow extends StatelessWidget {
  final Widget child;
  final Widget? leading;
  final String blockId;
  final BlockOnDelete onDelete;
  final BlockOnMove onMove;
  final void Function(String blockId)? onAddBlock;
  final VoidCallback? onTap;

  const BlockRow({
    super.key,
    required this.child,
    required this.blockId,
    required this.onDelete,
    required this.onMove,
    this.leading,
    this.onAddBlock,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Expanded(child: InkWell(onTap: onTap, child: child)),
        _Controls(
          blockId: blockId,
          onDelete: onDelete,
          onMove: onMove,
          onAddBlock: onAddBlock,
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  final String blockId;
  final BlockOnDelete onDelete;
  final BlockOnMove onMove;
  final void Function(String blockId)? onAddBlock;

  const _Controls({
    required this.blockId,
    required this.onDelete,
    required this.onMove,
    this.onAddBlock,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onAddBlock != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            icon: const Icon(Icons.add),
            tooltip: 'Add block',
            onPressed: () => onAddBlock!(blockId),
          ),
        PopupMenuButton<String>(
          iconSize: 16,
          onSelected: (v) {
            switch (v) {
              case 'up':
                onMove(blockId, true);
              case 'down':
                onMove(blockId, false);
              case 'delete':
                onDelete(blockId);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'up', child: Text('Move up')),
            PopupMenuItem(value: 'down', child: Text('Move down')),
            PopupMenuItem(value: 'delete', child: Text('Delete block')),
          ],
        ),
      ],
    );
  }
}

class TableBlockWidget extends StatefulWidget {
  final Block block;
  final BlockOnContent onContent;
  final BlockOnDelete onDelete;
  final BlockOnMove onMove;

  const TableBlockWidget({
    super.key,
    required this.block,
    required this.onContent,
    required this.onDelete,
    required this.onMove,
  });

  @override
  State<TableBlockWidget> createState() => _TableBlockWidgetState();
}

class _TableBlockWidgetState extends State<TableBlockWidget> {
  late TableBlockData _data;
  final Map<String, TextEditingController> _controllers = {};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _data = TableBlockData.fromJson(widget.block.content);
  }

  TextEditingController _cell(int r, int c) {
    final key = '$r|$c';
    return _controllers.putIfAbsent(key, () {
      final value = _data.rows[r][c];
      return TextEditingController(text: value);
    });
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      widget.onContent(widget.block.id, _data.toJson());
    });
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
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('Table',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  tooltip: 'Add column',
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      _data.addColumn();
                    });
                    _changed();
                  }),
              IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  tooltip: 'Add row',
                  icon: const Icon(Icons.playlist_add),
                  onPressed: () {
                    setState(() {
                      _data.addRow();
                    });
                    _changed();
                  }),
              _Controls(
                blockId: widget.block.id,
                onDelete: widget.onDelete,
                onMove: widget.onMove,
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              children: [
                for (var c = 0; c < _data.columns.length; c++)
                  _headerCell(c),
                for (var r = 0; r < _data.rows.length; r++) _dataRow(r),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(int c) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(
              right: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Text(_data.columns[c],
              style: theme.textTheme.labelLarge,
              overflow: TextOverflow.ellipsis),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 14,
          tooltip: 'Delete column',
          icon: const Icon(Icons.close),
          onPressed: () {
            setState(() => _data.removeColumn(c));
            _changed();
          },
        ),
      ],
    );
  }

  Widget _dataRow(int r) {
    return Row(
      children: [
        for (var c = 0; c < _data.columns.length; c++)
          SizedBox(
            width: 130,
            child: TextField(
              controller: _cell(r, c),
              maxLines: null,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
              onChanged: (_) {
                _data.rows[r][c] = _cell(r, c).text;
                _changed();
              },
            ),
          ),
        PopupMenuButton<String>(
          iconSize: 16,
          onSelected: (v) {
            switch (v) {
              case 'up':
                if (r > 0) {
                  setState(() {
                    final tmp = _data.rows[r];
                    _data.rows[r] = _data.rows[r - 1];
                    _data.rows[r - 1] = tmp;
                    _resetCellControllers();
                  });
                  _changed();
                }
              case 'down':
                if (r < _data.rows.length - 1) {
                  setState(() {
                    final tmp = _data.rows[r];
                    _data.rows[r] = _data.rows[r + 1];
                    _data.rows[r + 1] = tmp;
                    _resetCellControllers();
                  });
                  _changed();
                }
              case 'delete':
                setState(() => _data.removeRow(r));
                _changed();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'up', child: Text('Move row up')),
            PopupMenuItem(value: 'down', child: Text('Move row down')),
            PopupMenuItem(value: 'delete', child: Text('Delete row')),
          ],
        ),
      ],
    );
  }

  void _resetCellControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
  }
}