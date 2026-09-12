import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';

import '../../app/design_tokens.dart';
import '../../app/spacing.dart';
import '../../core/database/app_database.dart';
import '../../shared/models/note_models.dart';
import '../../shared/widgets/app_widgets.dart';
import 'attachment_preview_io.dart'
    if (dart.library.js_interop) 'attachment_preview_web.dart';

/// Shared callbacks every block tile reports to.
typedef BlockOnContent = void Function(String blockId, String content);
typedef BlockOnDelete = void Function(String blockId);
typedef BlockOnMove = void Function(String blockId, bool up);
typedef BlockOnConvert = void Function(String blockId, BlockType type);

/// One entry in the block palette, shared by the `/` menu and the add-block
/// sheet so the two can never drift apart.
class BlockPaletteEntry {
  final String label;
  final String description;

  /// The `/command` form, also used to match what the user types.
  final String command;
  final IconData icon;
  final BlockType type;

  const BlockPaletteEntry({
    required this.label,
    required this.description,
    required this.command,
    required this.icon,
    required this.type,
  });

  /// Matches against the label and the command, so `//todo`, `to`, `check` and
  /// `list` all find the to-do block.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return label.toLowerCase().contains(q) ||
        command.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q);
  }
}

const List<BlockPaletteEntry> kBlockPalette = [
  BlockPaletteEntry(
    label: 'Text',
    description: 'Plain paragraph',
    command: '/text',
    icon: Symbols.notes,
    type: BlockType.text,
  ),
  BlockPaletteEntry(
    label: 'Heading',
    description: 'Section title, H1 to H3',
    command: '/heading',
    icon: Symbols.title,
    type: BlockType.heading,
  ),
  BlockPaletteEntry(
    label: 'To-do list',
    description: 'Tickable items with progress',
    command: '/todo',
    icon: Symbols.checklist,
    type: BlockType.checklist,
  ),
  BlockPaletteEntry(
    label: 'Bulleted list',
    description: 'Simple unordered list',
    command: '/bullet',
    icon: Symbols.format_list_bulleted,
    type: BlockType.bullet,
  ),
  BlockPaletteEntry(
    label: 'Numbered list',
    description: 'Ordered steps',
    command: '/number',
    icon: Symbols.format_list_numbered,
    type: BlockType.numberedList,
  ),
  BlockPaletteEntry(
    label: 'Quote',
    description: 'Set text apart',
    command: '/quote',
    icon: Symbols.format_quote,
    type: BlockType.quote,
  ),
  BlockPaletteEntry(
    label: 'Code',
    description: 'Monospaced block',
    command: '/code',
    icon: Symbols.code,
    type: BlockType.code,
  ),
  BlockPaletteEntry(
    label: 'Table',
    description: 'Rows and columns',
    command: '/table',
    icon: Symbols.table_chart,
    type: BlockType.table,
  ),
  BlockPaletteEntry(
    label: 'Image',
    description: 'Attach a picture',
    command: '/image',
    icon: Symbols.image,
    type: BlockType.image,
  ),
  BlockPaletteEntry(
    label: 'Divider',
    description: 'Horizontal rule',
    command: '/divider',
    icon: Symbols.horizontal_rule,
    type: BlockType.divider,
  ),
];

const int kHeadingDefault = 2;

/// The left margin that holds the drag handle and the `+` affordance, revealed
/// on hover per `DESIGN.md`'s block-row spec.
const double _kGutter = 46;

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

/// A single block in the document.
class BlockTile extends StatelessWidget {
  final Block block;
  final TextEditingController controller;
  final BlockOnContent onContent;
  final BlockOnDelete onDelete;
  final BlockOnMove onMove;
  final BlockOnConvert onConvert;
  final Future<void> Function(String blockId)? onPickImage;
  final void Function(String blockId)? onAddBlock;

  const BlockTile({
    super.key,
    required this.block,
    required this.controller,
    required this.onContent,
    required this.onDelete,
    required this.onMove,
    required this.onConvert,
    this.onPickImage,
    this.onAddBlock,
  });

  @override
  Widget build(BuildContext context) {
    final type = BlockType.fromDb(block.type);
    return switch (type) {
      BlockType.text => _textBlock(context),
      BlockType.heading => HeadingBlock(
        block: block,
        onContent: onContent,
        onDelete: onDelete,
        onMove: onMove,
        onAddBlock: onAddBlock,
      ),
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
        onAddBlock: onAddBlock,
      ),
      BlockType.checklist => const SizedBox.shrink(),
      BlockType.image => _imageBlock(context),
    };
  }

  InputDecoration _bare(BuildContext context, String hint) {
    return InputDecoration(
      filled: false,
      hintText: hint,
      hintStyle: context.texts.bodyLarge?.copyWith(
        color: context.palette.textTertiary,
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      isDense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _textBlock(BuildContext context) {
    return BlockRow(
      blockId: block.id,
      onDelete: onDelete,
      onMove: onMove,
      onAddBlock: onAddBlock,
      child: _TextBlockBody(
        block: block,
        controller: controller,
        onContent: onContent,
        onConvert: onConvert,
      ),
    );
  }

  Widget _bulletBlock(BuildContext context) {
    final palette = context.palette;
    return BlockRow(
      blockId: block.id,
      onDelete: onDelete,
      onMove: onMove,
      onAddBlock: onAddBlock,
      leading: Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: palette.textSecondary,
            shape: BoxShape.circle,
          ),
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: context.texts.bodyLarge,
        decoration: _bare(context, 'List item'),
        onChanged: (v) => onContent(block.id, v),
      ),
    );
  }

  Widget _numberedBlock(BuildContext context) {
    return BlockRow(
      blockId: block.id,
      onDelete: onDelete,
      onMove: onMove,
      onAddBlock: onAddBlock,
      leading: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          '${block.position + 1}.',
          style: context.mono.copyWith(color: context.palette.textSecondary),
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: context.texts.bodyLarge,
        decoration: _bare(context, 'List item'),
        onChanged: (v) => onContent(block.id, v),
      ),
    );
  }

  Widget _quoteBlock(BuildContext context) {
    final palette = context.palette;
    return BlockRow(
      blockId: block.id,
      onDelete: onDelete,
      onMove: onMove,
      onAddBlock: onAddBlock,
      child: Container(
        padding: const EdgeInsets.only(left: Spacing.md),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: palette.primary, width: 3)),
        ),
        child: TextField(
          controller: controller,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          style: context.texts.bodyLarge?.copyWith(
            fontStyle: FontStyle.italic,
            color: palette.textSecondary,
          ),
          decoration: _bare(context, 'Quote'),
          onChanged: (v) => onContent(block.id, v),
        ),
      ),
    );
  }

  /// Code blocks get a titled header with a copy action, and the body is set in
  /// JetBrains Mono — never Inter.
  Widget _codeBlock(BuildContext context) {
    final palette = context.palette;
    return BlockRow(
      blockId: block.id,
      onDelete: onDelete,
      onMove: onMove,
      onAddBlock: onAddBlock,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: palette.surfaceSunken,
          borderRadius: AppRadii.all(AppRadii.base),
          border: Border.all(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.only(left: Spacing.md),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: [
                  Text(
                    'code',
                    style: context.mono.copyWith(color: palette.textTertiary),
                  ),
                  const Spacer(),
                  GhostIconButton(
                    icon: Symbols.content_copy,
                    tooltip: 'Copy',
                    iconSize: 15,
                    target: 30,
                    color: palette.textTertiary,
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: controller.text),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: TextField(
                controller: controller,
                maxLines: null,
                style: context.mono.copyWith(
                  fontSize: 13,
                  height: 20 / 13,
                  color: palette.textPrimary,
                ),
                decoration: InputDecoration(
                  filled: false,
                  hintText: '// code',
                  hintStyle: context.mono.copyWith(color: palette.textTertiary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (v) => onContent(block.id, v),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dividerBlock(BuildContext context) {
    return BlockRow(
      blockId: block.id,
      onDelete: onDelete,
      onMove: onMove,
      onAddBlock: onAddBlock,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
        child: Divider(height: 1, color: context.palette.borderStrong),
      ),
    );
  }

  Widget _imageBlock(BuildContext context) {
    return BlockRow(
      blockId: block.id,
      onDelete: onDelete,
      onMove: onMove,
      onAddBlock: onAddBlock,
      onTap: () => onPickImage?.call(block.id),
      child: ClipRRect(
        borderRadius: AppRadii.all(AppRadii.base),
        child: blockImagePreview(block.content, () => _pickHint(context)),
      ),
    );
  }

  Widget _pickHint(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: AppRadii.all(AppRadii.base),
        border: Border.all(color: palette.borderStrong),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Symbols.image, size: 22, color: palette.textTertiary),
          const SizedBox(height: Spacing.xs),
          Text(
            'Click to attach an image',
            style: context.texts.bodySmall?.copyWith(
              color: palette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A text block that opens the block palette when the line starts with `/`.
///
/// The menu renders in-flow directly beneath the field rather than in an
/// overlay: it can't be mispositioned, it pushes the rest of the document down
/// so nothing is covered, and it scrolls with the note.
class _TextBlockBody extends StatefulWidget {
  final Block block;
  final TextEditingController controller;
  final BlockOnContent onContent;
  final BlockOnConvert onConvert;

  const _TextBlockBody({
    required this.block,
    required this.controller,
    required this.onContent,
    required this.onConvert,
  });

  @override
  State<_TextBlockBody> createState() => _TextBlockBodyState();
}

class _TextBlockBodyState extends State<_TextBlockBody> {
  /// The text after the leading `/`, or null when the palette isn't open.
  String? _query;

  @override
  void initState() {
    super.initState();
    _query = _queryFor(widget.controller.text);
  }

  /// Finds a slash command at the start of the current single-line block.
  static String? _queryFor(String text) {
    if (text.contains('\n')) return null;
    final trimmed = text.trimLeft();
    if (!trimmed.startsWith('/')) return null;
    return trimmed.substring(1);
  }

  void _onChanged(String value) {
    final next = _queryFor(value);
    if (next != _query) setState(() => _query = next);
    widget.onContent(widget.block.id, value);
  }

  void _pick(BlockPaletteEntry entry) {
    // Drop the "/command" text — it was an instruction, not content.
    widget.controller.clear();
    widget.onContent(widget.block.id, '');
    setState(() => _query = null);
    widget.onConvert(widget.block.id, entry.type);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final query = _query;
    final matches =
        query == null
            ? const <BlockPaletteEntry>[]
            : kBlockPalette.where((e) => e.matches(query)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          style: context.texts.bodyLarge,
          decoration: InputDecoration(
            filled: false,
            hintText: "Write, or press '/' for blocks…",
            hintStyle: context.texts.bodyLarge?.copyWith(
              color: palette.textTertiary,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: _onChanged,
        ),
        if (query != null)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.sm),
            child: _SlashMenu(query: query, matches: matches, onPick: _pick),
          ),
      ],
    );
  }
}

/// The in-flow `/` palette: a Level 3 surface listing the matching blocks.
class _SlashMenu extends StatelessWidget {
  final String query;
  final List<BlockPaletteEntry> matches;
  final ValueChanged<BlockPaletteEntry> onPick;

  const _SlashMenu({
    required this.query,
    required this.matches,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      constraints: const BoxConstraints(maxWidth: 340, maxHeight: 268),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadii.all(AppRadii.base),
        border: Border.all(color: palette.borderStrong),
        boxShadow: AppShadows.e3(palette),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          matches.isEmpty
              ? Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Text(
                  'No block matches "$query"',
                  style: context.texts.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.md,
                      Spacing.md,
                      Spacing.md,
                      Spacing.sm,
                    ),
                    child: Eyebrow(
                      query.isEmpty ? 'Blocks' : 'Matching blocks',
                    ),
                  ),
                  SizedBox(
                    height: (matches.length * 48.0).clamp(48.0, 220.0),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: matches.length,
                      itemBuilder: (context, i) {
                        final entry = matches[i];
                        // The top match is what Enter-style selection would take,
                        // so it gets the indigo wash.
                        final highlighted = i == 0 && query.isNotEmpty;
                        return InkWell(
                          onTap: () => onPick(entry),
                          child: Container(
                            color: highlighted ? palette.primaryWash : null,
                            padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.md,
                              vertical: Spacing.sm,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  entry.icon,
                                  size: 19,
                                  color:
                                      highlighted
                                          ? palette.primary
                                          : palette.textSecondary,
                                ),
                                const SizedBox(width: Spacing.md),
                                Expanded(
                                  child: Text(
                                    entry.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.texts.titleSmall?.copyWith(
                                      color:
                                          highlighted
                                              ? palette.onPrimaryWash
                                              : palette.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Spacing.sm),
                                Text(
                                  entry.command,
                                  style: context.mono.copyWith(
                                    color: palette.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}

/// A heading block with an H1/H2/H3 selector in the gutter.
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

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() =>
      widget.onContent(widget.block.id, _encodeHeading(_text.text, _level));

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = switch (_level) {
      1 => context.texts.headlineLarge,
      2 => context.texts.headlineMedium,
      _ => context.texts.headlineSmall,
    };

    return BlockRow(
      blockId: widget.block.id,
      onDelete: widget.onDelete,
      onMove: widget.onMove,
      onAddBlock: widget.onAddBlock,
      leading: PopupMenuButton<int>(
        tooltip: 'Heading level',
        initialValue: _level,
        position: PopupMenuPosition.under,
        onSelected: (l) {
          setState(() => _level = l);
          _save();
        },
        itemBuilder:
            (context) => [
              for (final l in const [1, 2, 3])
                PopupMenuItem(value: l, child: Text('Heading $l')),
            ],
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'H$_level',
            style: context.mono.copyWith(
              fontWeight: FontWeight.w500,
              color: palette.textTertiary,
            ),
          ),
        ),
      ),
      child: TextField(
        controller: _text,
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        style: style,
        decoration: InputDecoration(
          filled: false,
          hintText: 'Heading',
          hintStyle: style?.copyWith(color: palette.textTertiary),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (_) => _save(),
      ),
    );
  }
}

/// The block chrome: a hover-revealed gutter holding `+` and a drag handle, the
/// content, and a hover-revealed overflow menu.
class BlockRow extends StatefulWidget {
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
  State<BlockRow> createState() => _BlockRowState();
}

class _BlockRowState extends State<BlockRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Touch layouts never fire hover, so a hover-only gutter made the drag
    // handle — and with it the delete action — permanently unreachable on a
    // phone. There, the gutter is simply always shown.
    final touch = MediaQuery.sizeOf(context).width < Breakpoints.tablet;
    final revealed = touch || _hovering;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xxs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gutter: affordances live outside the text column so the reading
            // measure never shifts when they appear.
            SizedBox(
              width: _kGutter,
              child: AnimatedOpacity(
                opacity: revealed ? 1 : 0,
                duration: AppMotion.fast,
                child: IgnorePointer(
                  ignoring: !revealed,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.onAddBlock != null)
                        GhostIconButton(
                          icon: Symbols.add,
                          tooltip: 'Add block below',
                          iconSize: 16,
                          target: 22,
                          color: palette.textTertiary,
                          onPressed: () => widget.onAddBlock!(widget.blockId),
                        ),
                      _HandleMenu(
                        blockId: widget.blockId,
                        onDelete: widget.onDelete,
                        onMove: widget.onMove,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.leading != null) ...[
              widget.leading!,
              const SizedBox(width: Spacing.sm),
            ],
            Expanded(
              child:
                  widget.onTap == null
                      ? widget.child
                      : InkWell(
                        borderRadius: AppRadii.all(AppRadii.base),
                        onTap: widget.onTap,
                        child: widget.child,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The `⋮⋮` drag handle, which doubles as the block's context menu.
class _HandleMenu extends StatelessWidget {
  final String blockId;
  final BlockOnDelete onDelete;
  final BlockOnMove onMove;

  const _HandleMenu({
    required this.blockId,
    required this.onDelete,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: 22,
      height: 26,
      child: PopupMenuButton<String>(
        tooltip: 'Block options',
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        icon: Icon(
          Symbols.drag_indicator,
          size: 16,
          color: palette.textTertiary,
        ),
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
        itemBuilder:
            (context) => [
              const PopupMenuItem(value: 'up', child: Text('Move up')),
              const PopupMenuItem(value: 'down', child: Text('Move down')),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete block',
                  style: TextStyle(color: context.palette.error),
                ),
              ),
            ],
      ),
    );
  }
}

/// A high-density table block: sticky-looking header row, hairline cell rules,
/// monospaced cell text.
class TableBlockWidget extends StatefulWidget {
  final Block block;
  final BlockOnContent onContent;
  final BlockOnDelete onDelete;
  final BlockOnMove onMove;
  final void Function(String blockId)? onAddBlock;

  const TableBlockWidget({
    super.key,
    required this.block,
    required this.onContent,
    required this.onDelete,
    required this.onMove,
    this.onAddBlock,
  });

  @override
  State<TableBlockWidget> createState() => _TableBlockWidgetState();
}

class _TableBlockWidgetState extends State<TableBlockWidget> {
  static const double _cellWidth = 148;

  late TableBlockData _data;
  final Map<String, TextEditingController> _controllers = {};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _data = TableBlockData.fromJson(widget.block.content);
  }

  TextEditingController _cell(int r, int c) {
    return _controllers.putIfAbsent(
      '$r|$c',
      () => TextEditingController(text: _data.rows[r][c]),
    );
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      widget.onContent(widget.block.id, _data.toJson());
    });
  }

  void _resetCellControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
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

    return BlockRow(
      blockId: widget.block.id,
      onDelete: widget.onDelete,
      onMove: widget.onMove,
      onAddBlock: widget.onAddBlock,
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border),
          borderRadius: AppRadii.all(AppRadii.base),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.only(left: Spacing.md),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: [
                  const Eyebrow('Table'),
                  const Spacer(),
                  GhostIconButton(
                    icon: Symbols.view_column,
                    tooltip: 'Add column',
                    iconSize: 16,
                    target: 30,
                    onPressed: () {
                      setState(_data.addColumn);
                      _changed();
                    },
                  ),
                  GhostIconButton(
                    icon: Symbols.playlist_add,
                    tooltip: 'Add row',
                    iconSize: 16,
                    target: 30,
                    onPressed: () {
                      setState(_data.addRow);
                      _changed();
                    },
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _headerRow(context),
                  for (var r = 0; r < _data.rows.length; r++)
                    _dataRow(context, r),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerRow(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          for (var c = 0; c < _data.columns.length; c++)
            Container(
              width: _cellWidth,
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              decoration: BoxDecoration(
                border:
                    c == _data.columns.length - 1
                        ? null
                        : Border(right: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _data.columns[c],
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.labelMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                  if (_data.columns.length > 1)
                    GhostIconButton(
                      icon: Symbols.close,
                      tooltip: 'Delete column',
                      iconSize: 13,
                      target: 20,
                      color: palette.textTertiary,
                      onPressed: () {
                        setState(() {
                          _data.removeColumn(c);
                          _resetCellControllers();
                        });
                        _changed();
                      },
                    ),
                ],
              ),
            ),
          const SizedBox(width: 34),
        ],
      ),
    );
  }

  Widget _dataRow(BuildContext context, int r) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        border:
            r == _data.rows.length - 1
                ? null
                : Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          for (var c = 0; c < _data.columns.length; c++)
            Container(
              width: _cellWidth,
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              decoration: BoxDecoration(
                border:
                    c == _data.columns.length - 1
                        ? null
                        : Border(right: BorderSide(color: palette.border)),
              ),
              child: TextField(
                controller: _cell(r, c),
                maxLines: null,
                style: context.mono.copyWith(
                  fontSize: 13,
                  color: palette.textPrimary,
                ),
                decoration: const InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: Spacing.sm + 2,
                  ),
                ),
                onChanged: (v) {
                  _data.rows[r][c] = v;
                  _changed();
                },
              ),
            ),
          SizedBox(
            width: 34,
            child: PopupMenuButton<String>(
              tooltip: 'Row options',
              padding: EdgeInsets.zero,
              iconSize: 16,
              position: PopupMenuPosition.under,
              icon: Icon(Symbols.more_vert, color: palette.textTertiary),
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
                    setState(() {
                      _data.removeRow(r);
                      _resetCellControllers();
                    });
                    _changed();
                }
              },
              itemBuilder:
                  (context) => const [
                    PopupMenuItem(value: 'up', child: Text('Move row up')),
                    PopupMenuItem(value: 'down', child: Text('Move row down')),
                    PopupMenuItem(value: 'delete', child: Text('Delete row')),
                  ],
            ),
          ),
        ],
      ),
    );
  }
}
