import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/design_tokens.dart';
import '../../app/spacing.dart';
import '../../core/app_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../../shared/models/note_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/note_dialogs.dart';
import '../../shared/widgets/note_surface.dart';
import '../editor/attachments_section.dart';
import '../editor/block_editor.dart';
import 'note_actions.dart';
import 'note_card.dart' show ReminderChip;

/// The document canvas.
///
/// The page background takes the note's tone; the document itself is a centred
/// `surface` sheet with `lg` corners at Level 1. A property block sits between
/// hairline rules under the title, the way a database page reads.
class NoteEditorScreen extends ConsumerStatefulWidget {
  final String noteId;
  final bool openReminder;

  const NoteEditorScreen({
    super.key,
    required this.noteId,
    this.openReminder = false,
  });

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final TextEditingController _title = TextEditingController();
  final BlockEditorController _blockEditor = BlockEditorController();
  Timer? _debounce;
  Future<void> _titleWrite = Future<void>.value();
  bool _titleDirty = false;
  int _titleGeneration = 0;
  bool _loaded = false;
  bool _blocksReady = false;
  bool _reminderOpened = false;
  Future<void>? _blocksInitialization;
  Object? _blocksError;

  @override
  void dispose() {
    _debounce?.cancel();
    if (_titleDirty) {
      final sync = ref.read(syncControllerProvider.notifier);
      unawaited(_titleWrite.then((_) => sync.syncNow()));
    }
    _title.dispose();
    super.dispose();
  }

  void _hydrate(Note? note) {
    if (note == null || _loaded) return;
    _loaded = true;
    _title.text = note.title;
    _blocksInitialization = _initializeBlocks(note.id);
    if (widget.openReminder && !_reminderOpened) {
      _reminderOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onMenu('reminder', note);
      });
    }
  }

  Future<void> _initializeBlocks(String noteId) async {
    try {
      await ref.read(notesDaoProvider).ensureBlocks(noteId);
    } catch (error) {
      _blocksError = error;
    } finally {
      if (mounted) setState(() => _blocksReady = true);
    }
  }

  Future<void> _showAddBlock(String noteId) async {
    await _blocksInitialization;
    if (!mounted || _blocksError != null) return;
    final type = await BlockEditor.showBlockPalette(context);
    if (type == null) return;
    await _blockEditor.runStructural(() async {
      final dao = ref.read(notesDaoProvider);
      final blocks = await dao.getBlocks(noteId);
      await dao.insertBlockAt(noteId, position: blocks.length, type: type);
      await dao.touch(noteId);
      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
    });
  }

  void _saveTitle(String value) {
    final dao = ref.read(notesDaoProvider);
    _titleDirty = true;
    final generation = ++_titleGeneration;
    _titleWrite = _titleWrite
        .catchError((_) {})
        .then((_) => dao.updateNote(widget.noteId, title: value));
    unawaited(_titleWrite.catchError((_) {}));

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      await _titleWrite;
      if (!mounted || generation != _titleGeneration) return;
      _titleDirty = false;
      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Note?>(
      stream: ref.watch(notesDaoProvider).watchById(widget.noteId),
      builder: (context, snapshot) {
        final note = snapshot.data;
        _hydrate(note);

        if (note == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Symbols.description,
              title: 'This note no longer exists',
              message: 'It may have been deleted on another device.',
            ),
          );
        }

        return StreamBuilder<List<Label>>(
          stream: ref.watch(labelsDaoProvider).watchForNote(widget.noteId),
          builder:
              (context, labelsSnapshot) =>
                  _buildScaffold(context, note, labelsSnapshot.data),
        );
      },
    );
  }

  Widget _buildScaffold(BuildContext context, Note note, List<Label>? labels) {
    final palette = context.palette;
    final surface = NoteSurface.of(context, note.color);
    final chromeSurface = NoteSurface.of(context, null);
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        titleSpacing: 0,
        // On a phone the bar carries nothing but actions, the way Keep's does:
        // the note names itself in the title field a few pixels below, so a
        // breadcrumb would be a second label for the same thing.
        title: wide ? _Breadcrumbs(note: note, surface: chromeSurface) : null,
        actions: [
          // Colour and reminder now live in the note's own header, so the app
          // bar keeps only what the note body has no place for.
          if (wide) ...[
            GhostIconButton(
              icon: Symbols.push_pin,
              fill: note.isPinned ? 1 : 0,
              tooltip: note.isPinned ? 'Unpin' : 'Pin',
              color: note.isPinned ? palette.primary : palette.textSecondary,
              onPressed:
                  () =>
                      NoteActions.setPinned(ref, widget.noteId, !note.isPinned),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: Icon(Symbols.more_horiz, color: palette.textSecondary),
              onSelected: (v) => _onMenu(v, note),
              itemBuilder: (context) => _menuItems(note),
            ),
          ] else ...[
            // Filled rounded squares grouped at the right. Overflow lives in the
            // bottom bar's menu, so no action appears in both bars.
            _BarButton(
              icon: Symbols.push_pin,
              fill: note.isPinned ? 1 : 0,
              tooltip: note.isPinned ? 'Unpin' : 'Pin',
              active: note.isPinned,
              surface: chromeSurface,
              onPressed:
                  () =>
                      NoteActions.setPinned(ref, widget.noteId, !note.isPinned),
            ),
            const SizedBox(width: Spacing.xs),
            _BarButton(
              icon: Symbols.add_alert,
              tooltip: 'Reminder',
              active: note.reminderAt != null,
              surface: chromeSurface,
              onPressed: () => _onMenu('reminder', note),
            ),
            const SizedBox(width: Spacing.xs),
            _BarButton(
              icon: note.isArchived ? Symbols.unarchive : Symbols.archive,
              tooltip: note.isArchived ? 'Unarchive' : 'Archive',
              surface: chromeSurface,
              onPressed:
                  () => NoteActions.setArchived(
                    ref,
                    widget.noteId,
                    !note.isArchived,
                  ),
            ),
          ],
          const SizedBox(width: Spacing.sm),
        ],
      ),
      bottomNavigationBar:
          wide
              ? null
              : _EditorBottomBar(
                surface: chromeSurface,
                onAdd: () => _showInsertMenu(note),
                onColour: () => _onMenu('color', note),
                onFormat: () => _showAddBlock(note.id),
                onUndo: _undo,
                onRedo: _redo,
                onMore: () => _showMoreMenu(note),
              ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          wide ? Spacing.xl : Spacing.lg,
          0,
          wide ? Spacing.xl : Spacing.lg,
          Spacing.xxxl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.sheet),
            // On a phone the note sits flat on the page. A raised sheet inside a
            // full-screen route is a card with nothing beside it, and the inset
            // it costs is reading width on the narrowest screen.
            child: _Sheet(
              surface: surface,
              raised: wide,
              padding: EdgeInsets.all(wide ? Spacing.xxl : Spacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (note.isTrashed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.lg),
                      child: _TrashBanner(
                        onRestore: () => _onMenu('restore', note),
                      ),
                    ),
                  AttachmentImageStrip(noteId: widget.noteId),
                  // Title on the left, the note's properties on the right, one
                  // row. Nothing above it: the icon tile was decoration on a
                  // page that already announces itself with a display-size
                  // title.
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _titleField(context)),
                        const SizedBox(width: Spacing.xl),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: _NoteProperties(
                            note: note,
                            labels: labels ?? const <Label>[],
                            onEditLabels: () => _onMenu('labels', note),
                            onEditReminder: () => _onMenu('reminder', note),
                            onColour:
                                (key) => NoteActions.setColor(
                                  ref,
                                  widget.noteId,
                                  key,
                                ),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _titleField(context),
                    const SizedBox(height: Spacing.md),
                    _CompactMeta(
                      note: note,
                      labels: labels ?? const <Label>[],
                      surface: surface,
                      onEditReminder: () => _onMenu('reminder', note),
                    ),
                    _EditedStatusRow(
                      edited: _stamp(note.updatedAt),
                      surface: surface,
                      onDone:
                          () => FocusManager.instance.primaryFocus?.unfocus(),
                    ),
                    const SizedBox(height: Spacing.md),
                  ],
                  if (wide) ...[
                    const SizedBox(height: Spacing.lg),
                    Divider(color: palette.border, height: 1),
                    const SizedBox(height: Spacing.xl),
                  ],
                  // Every note is the same kind of note: a title and a stack of
                  // blocks. Checklists, headings and code are things you add
                  // with `/`, not a type you commit to when creating the note.
                  if (!_blocksReady)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: Spacing.xl),
                      child: CenteredLoader(),
                    )
                  else if (_blocksError != null)
                    const InlineError(
                      message: 'This document could not be prepared.',
                    )
                  else
                    BlockEditor(
                      noteId: widget.noteId,
                      controller: _blockEditor,
                    ),
                  const SizedBox(height: Spacing.lg),
                  AttachmentsSection(noteId: widget.noteId),
                  // The phone puts these in its bottom bar instead, so repeating
                  // them here would be the same two controls twice.
                  if (wide) ...[
                    const SizedBox(height: Spacing.lg),
                    Divider(color: palette.border, height: 1),
                    const SizedBox(height: Spacing.md),
                    Row(
                      children: [
                        _FooterAction(
                          icon: Symbols.add,
                          tooltip: 'Add a block',
                          onPressed: () => _showAddBlock(widget.noteId),
                        ),
                        const SizedBox(width: Spacing.sm),
                        _FooterAction(
                          icon: Symbols.attach_file,
                          tooltip: 'Add an attachment',
                          onPressed:
                              () => AttachmentsSection.pickAndAdd(
                                ref,
                                widget.noteId,
                              ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            'Created ${_stamp(note.createdAt)}  ·  '
                            'Updated ${_stamp(note.updatedAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.mono.copyWith(
                              color: palette.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _titleField(BuildContext context) {
    final palette = context.palette;
    return TextField(
      controller: _title,
      style: context.display,
      maxLines: null,
      decoration: InputDecoration(
        filled: false,
        hintText: 'Untitled',
        hintStyle: context.display.copyWith(color: palette.textTertiary),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      textCapitalization: TextCapitalization.sentences,
      onChanged: _saveTitle,
    );
  }

  void _undo() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null) {
      Actions.maybeInvoke(
        focusContext,
        const UndoTextIntent(SelectionChangedCause.toolbar),
      );
    }
  }

  void _redo() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null) {
      Actions.maybeInvoke(
        focusContext,
        const RedoTextIntent(SelectionChangedCause.toolbar),
      );
    }
  }

  String _stamp(DateTime when) => DateFormat('d MMM yyyy, HH:mm').format(when);

  List<PopupMenuEntry<String>> _menuItems(Note note) {
    return [
      PopupMenuItem(value: 'pin', child: Text(note.isPinned ? 'Unpin' : 'Pin')),
      if (note.isTrashed) ...[
        const PopupMenuItem(value: 'restore', child: Text('Restore')),
        const PopupMenuItem(
          value: 'delete_forever',
          child: Text('Delete forever'),
        ),
      ] else ...[
        PopupMenuItem(
          value: 'archive',
          child: Text(note.isArchived ? 'Unarchive' : 'Archive'),
        ),
        const PopupMenuItem(value: 'reminder', child: Text('Reminder')),
        const PopupMenuItem(value: 'find', child: Text('Find in note')),
        const PopupMenuItem(value: 'duplicate', child: Text('Make a copy')),
        const PopupMenuItem(value: 'send', child: Text('Send')),
        const PopupMenuItem(value: 'labels', child: Text('Labels')),
        const PopupMenuItem(value: 'color', child: Text('Change colour')),
        const PopupMenuItem(value: 'help', child: Text('Help & feedback')),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            'Move to trash',
            style: TextStyle(color: context.palette.error),
          ),
        ),
      ],
    ];
  }

  Future<void> _showInsertMenu(Note note) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: Spacing.md),
              children: [
                ListTile(
                  leading: const Icon(Symbols.photo_camera, size: 27),
                  title: const Text('Take photo'),
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
                ListTile(
                  leading: const Icon(Symbols.image, size: 27),
                  title: const Text('Add image'),
                  onTap: () => Navigator.pop(context, 'image'),
                ),
                ListTile(
                  leading: const Icon(Symbols.mic, size: 27),
                  title: const Text('Recording'),
                  onTap: () => Navigator.pop(context, 'recording'),
                ),
                ListTile(
                  leading: const Icon(Symbols.draw, size: 27),
                  title: const Text('Drawing'),
                  onTap: () => Navigator.pop(context, 'drawing'),
                ),
                ListTile(
                  leading: const Icon(Symbols.check_box, size: 27),
                  title: const Text('Checkboxes'),
                  onTap: () => Navigator.pop(context, 'checklist'),
                ),
              ],
            ),
          ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'camera':
        await AttachmentsSection.pickImage(
          ref,
          note.id,
          source: ImageSource.camera,
        );
      case 'image':
        await AttachmentsSection.pickImage(
          ref,
          note.id,
          source: ImageSource.gallery,
        );
      case 'recording':
        await AttachmentsSection.recordAndAdd(context, ref, note.id);
      case 'drawing':
        await AttachmentsSection.drawAndAdd(context, ref, note.id);
      case 'checklist':
        await _blocksInitialization;
        await _blockEditor.runStructural(() async {
          final dao = ref.read(notesDaoProvider);
          final blocks = await dao.getBlocks(note.id);
          await dao.insertBlockAt(
            note.id,
            position: blocks.length,
            type: BlockType.checklist,
          );
          await dao.touch(note.id);
          unawaited(ref.read(syncControllerProvider.notifier).syncNow());
        });
    }
  }

  Future<void> _showMoreMenu(Note note) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: Spacing.md),
              children: [
                ListTile(
                  leading: const Icon(Symbols.notifications_active, size: 26),
                  title: const Text('Reminder'),
                  onTap: () => Navigator.pop(context, 'reminder'),
                ),
                ListTile(
                  leading: const Icon(Symbols.search, size: 26),
                  title: const Text('Find in note'),
                  onTap: () => Navigator.pop(context, 'find'),
                ),
                ListTile(
                  leading: const Icon(Symbols.content_copy, size: 26),
                  title: const Text('Make a copy'),
                  onTap: () => Navigator.pop(context, 'duplicate'),
                ),
                ListTile(
                  leading: const Icon(Symbols.share, size: 26),
                  title: const Text('Send'),
                  onTap: () => Navigator.pop(context, 'send'),
                ),
                ListTile(
                  leading: const Icon(Symbols.label, size: 26),
                  title: const Text('Labels'),
                  onTap: () => Navigator.pop(context, 'labels'),
                ),
                ListTile(
                  leading: Icon(
                    Symbols.delete,
                    size: 26,
                    color: context.palette.error,
                  ),
                  title: Text(
                    'Delete',
                    style: TextStyle(color: context.palette.error),
                  ),
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
                ListTile(
                  leading: const Icon(Symbols.help, size: 26),
                  title: const Text('Help & feedback'),
                  onTap: () => Navigator.pop(context, 'help'),
                ),
              ],
            ),
          ),
    );
    if (value != null && mounted) await _onMenu(value, note);
  }

  Future<String> _noteText() async {
    await _titleWrite;
    await _blockEditor.flush();
    final dao = ref.read(notesDaoProvider);
    final blocks = await dao.getBlocks(widget.noteId);
    final items = await dao.getChecklistItems(widget.noteId);
    final parts = <String>[_title.text.trim()];

    for (final block in blocks) {
      final content = block.content.trim();
      switch (BlockType.fromDb(block.type)) {
        case BlockType.image || BlockType.divider || BlockType.checklist:
          break;
        case BlockType.heading:
          final separator = content.indexOf('|');
          parts.add(
            separator >= 0 ? content.substring(separator + 1) : content,
          );
        case BlockType.table:
          final table = TableBlockData.fromJson(content);
          parts.add(table.columns.join(' | '));
          parts.addAll(table.rows.map((row) => row.join(' | ')));
        default:
          parts.add(content);
      }
    }
    parts.addAll(
      items.map((item) => '${item.isCompleted ? '☑' : '☐'} ${item.content}'),
    );
    parts.removeWhere((part) => part.trim().isEmpty);
    return parts.join('\n');
  }

  Future<void> _findInNote() async {
    final text = (await _noteText()).toLowerCase();
    if (!mounted) return;
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              final query = controller.text.trim().toLowerCase();
              var matches = 0;
              if (query.isNotEmpty) {
                var start = 0;
                while (true) {
                  final index = text.indexOf(query, start);
                  if (index < 0) break;
                  matches++;
                  start = index + query.length;
                }
              }
              return AlertDialog(
                title: const Text('Find in note'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search this note',
                    suffixText: query.isEmpty ? null : '$matches found',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              );
            },
          ),
    );
    controller.dispose();
  }

  Future<void> _sendNote() async {
    final text = await _noteText();
    if (!mounted || text.isEmpty) return;
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      text,
      subject: _title.text.trim(),
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  Future<void> _onMenu(String value, Note note) async {
    switch (value) {
      case 'pin':
        await NoteActions.setPinned(ref, widget.noteId, !note.isPinned);
      case 'archive':
        await NoteActions.setArchived(ref, widget.noteId, !note.isArchived);
      case 'labels':
        await showLabelPickerDialog(context, ref, widget.noteId);
      case 'color':
        await showNoteColorDialog(
          context,
          note.color,
          (key) => NoteActions.setColor(ref, widget.noteId, key),
        );
      case 'reminder':
        await showReminderDialog(
          context,
          ref,
          widget.noteId,
          current: note.reminderAt,
          onSet:
              (when) => NoteActions.setReminder(
                ref,
                widget.noteId,
                _title.text,
                when,
              ),
        );
      case 'find':
        await _findInNote();
      case 'send':
        await _sendNote();
      case 'help':
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Note help'),
                  content: const Text(
                    "Use + to add blocks, the paperclip to attach files, and '/' in a text block to change its type.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
          );
        }
      case 'duplicate':
        await NoteActions.duplicate(ref, widget.noteId);
      case 'delete':
        await NoteActions.trash(ref, widget.noteId);
        if (mounted) context.pop();
      case 'restore':
        await NoteActions.restore(ref, widget.noteId);
      case 'delete_forever':
        await NoteActions.deleteForever(ref, widget.noteId);
        if (mounted) context.pop();
    }
  }
}

/// The document container: a raised sheet on pointer layouts, nothing at all on
/// a phone.
class _Sheet extends StatelessWidget {
  final NoteSurface surface;
  final bool raised;
  final EdgeInsets padding;
  final Widget child;

  const _Sheet({
    required this.surface,
    required this.raised,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: surface.background,
        borderRadius: AppRadii.all(AppRadii.lg),
        border: Border.all(color: surface.border),
        boxShadow: raised ? AppShadows.e1(palette) : const [],
      ),
      child: child,
    );
  }
}

/// An outlined icon button for the document footer.
///
/// Icon-only: "Add block" and "Add attachment" were the two widest controls in
/// the document, sitting mid-flow where they broke the note in half. As glyphs in
/// the footer they read as tools belonging to the page rather than content in it.
class _FooterAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _FooterAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: AppRadii.shape(
          AppRadii.base,
          side: BorderSide(color: palette.borderStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 22, color: palette.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// The note's properties, as a right-aligned cluster beside the title.
///
/// Replaces the four-row property table. Those rows ran the full width of the
/// document to say four short things, and pushed the note itself below the fold;
/// the same values fit in the header's spare right-hand space.
///
/// Status is a read-only readout — a note becomes archived or trashed through the
/// actions that do it, not by editing a field here.
class _NoteProperties extends StatelessWidget {
  final Note note;
  final List<Label> labels;
  final VoidCallback onEditLabels;
  final VoidCallback onEditReminder;
  final ValueChanged<String?> onColour;

  const _NoteProperties({
    required this.note,
    required this.labels,
    required this.onEditLabels,
    required this.onEditReminder,
    required this.onColour,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final (statusLabel, statusColor) = switch (note) {
      _ when note.isTrashed => ('In trash', palette.error),
      _ when note.isArchived => ('Archived', palette.textSecondary),
      _ => ('Active', palette.primary),
    };

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        StatusPill(
          label: statusLabel,
          background: palette.surfaceSunken,
          foreground: statusColor,
          dot: true,
        ),
        if (note.reminderAt != null)
          InkWell(
            borderRadius: AppRadii.all(AppRadii.full),
            onTap: onEditReminder,
            child: ReminderChip(when: note.reminderAt!),
          )
        else
          _MiniAction(
            icon: Symbols.alarm,
            label: 'Reminder',
            onPressed: onEditReminder,
          ),
        for (final label in labels) TagChip(label: '#${label.name}'),
        _MiniAction(
          icon: Symbols.sell,
          label: labels.isEmpty ? 'Add label' : 'Edit',
          onPressed: onEditLabels,
        ),
        _SwatchRow(current: note.color, onSelected: onColour),
      ],
    );
  }
}

/// A small outlined pill: glyph, then a `label-sm` word.
class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: Colors.transparent,
      shape: AppRadii.shape(
        AppRadii.full,
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.xs + 1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: palette.textSecondary),
              const SizedBox(width: Spacing.xs),
              Text(
                label,
                style: context.texts.labelSmall?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A filled rounded-square action, as the phone editor's bars use.
class _BarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final double fill;
  final bool active;
  final NoteSurface surface;
  final VoidCallback onPressed;

  const _BarButton({
    required this.icon,
    required this.tooltip,
    required this.surface,
    required this.onPressed,
    this.fill = 0,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GhostIconButton(
      icon: icon,
      fill: fill,
      tooltip: tooltip,
      iconSize: 24,
      target: 44,
      radius: AppRadii.md,
      // Tinted rather than tonal, so the fill still reads as chrome on any of
      // the nine note colours rather than fighting them.
      background:
          surface.isTinted ? surface.chipBackground : palette.surfaceSunken,
      color: active ? palette.primary : surface.foreground,
      onPressed: onPressed,
    );
  }
}

/// Reminder and label chips under the title, in place of the property block.
class _CompactMeta extends StatelessWidget {
  final Note note;
  final List<Label> labels;
  final NoteSurface surface;
  final VoidCallback onEditReminder;

  const _CompactMeta({
    required this.note,
    required this.labels,
    required this.surface,
    required this.onEditReminder,
  });

  @override
  Widget build(BuildContext context) {
    if (note.reminderAt == null && labels.isEmpty) {
      return const SizedBox(height: Spacing.sm);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Wrap(
        spacing: Spacing.sm,
        runSpacing: Spacing.sm,
        children: [
          if (note.reminderAt != null)
            InkWell(
              borderRadius: AppRadii.all(AppRadii.full),
              onTap: onEditReminder,
              child: ReminderChip(when: note.reminderAt!),
            ),
          for (final label in labels)
            TagChip(
              label: '#${label.name}',
              background: surface.chipBackground,
              foreground: surface.mutedForeground,
            ),
        ],
      ),
    );
  }
}

class _EditedStatusRow extends StatelessWidget {
  final String edited;
  final NoteSurface surface;
  final VoidCallback onDone;

  const _EditedStatusRow({
    required this.edited,
    required this.surface,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Edited $edited',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.mono.copyWith(color: surface.mutedForeground),
          ),
        ),
        GhostIconButton(
          icon: Symbols.check,
          tooltip: 'Done editing',
          iconSize: 23,
          target: 42,
          color: surface.foreground,
          onPressed: onDone,
        ),
      ],
    );
  }
}

/// Keep-style phone editing tools. Add opens the insertion sheet, while the
/// format control opens this app's block-type palette.
class _EditorBottomBar extends StatelessWidget {
  final NoteSurface surface;
  final VoidCallback onAdd;
  final VoidCallback onColour;
  final VoidCallback onFormat;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onMore;

  const _EditorBottomBar({
    required this.surface,
    required this.onAdd,
    required this.onColour,
    required this.onFormat,
    required this.onUndo,
    required this.onRedo,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: 64,
        color: surface.background,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _BarButton(
              icon: Symbols.add_box,
              tooltip: 'Add',
              surface: surface,
              onPressed: onAdd,
            ),
            _BarButton(
              icon: Symbols.palette,
              tooltip: 'Colour',
              surface: surface,
              onPressed: onColour,
            ),
            _BarButton(
              icon: Symbols.format_size,
              tooltip: 'Formatting and blocks',
              surface: surface,
              onPressed: onFormat,
            ),
            GhostIconButton(
              icon: Symbols.undo,
              tooltip: 'Undo',
              iconSize: 25,
              target: 44,
              color: surface.foreground,
              onPressed: onUndo,
            ),
            GhostIconButton(
              icon: Symbols.redo,
              tooltip: 'Redo',
              iconSize: 25,
              target: 44,
              color: surface.foreground,
              onPressed: onRedo,
            ),
            GhostIconButton(
              icon: Symbols.more_vert,
              tooltip: 'More',
              iconSize: 25,
              target: 44,
              color: surface.foreground,
              onPressed: onMore,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Notes › Untitled" — orientation without a second app bar row.
class _Breadcrumbs extends StatelessWidget {
  final Note note;
  final NoteSurface surface;

  const _Breadcrumbs({required this.note, required this.surface});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final crumbStyle = context.texts.labelMedium?.copyWith(
      color: surface.mutedForeground,
    );
    final title = note.title.trim();

    return Row(
      children: [
        InkWell(
          borderRadius: AppRadii.all(AppRadii.handle + 2),
          onTap:
              () => context.go(
                note.isTrashed
                    ? '/trash'
                    : note.isArchived
                    ? '/archive'
                    : '/notes',
              ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm - 2,
              vertical: 2,
            ),
            child: Text(
              note.isTrashed
                  ? 'Trash'
                  : note.isArchived
                  ? 'Archive'
                  : 'All notes',
              style: crumbStyle,
            ),
          ),
        ),
        Icon(Symbols.chevron_right, size: 15, color: palette.textTertiary),
        const SizedBox(width: Spacing.xs),
        Flexible(
          child: Text(
            title.isEmpty ? 'Untitled' : title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.labelMedium?.copyWith(
              color: surface.foreground,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// The tone picker as a row of swatch dots, straight in the app bar.
class _SwatchRow extends StatelessWidget {
  final String? current;
  final ValueChanged<String?> onSelected;

  const _SwatchRow({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final brightness = Theme.of(context).brightness;
    final selectedKey = current ?? 'default';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadii.all(AppRadii.full),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tone in kNoteColors)
            Tooltip(
              message: tone.label,
              child: InkWell(
                borderRadius: AppRadii.all(AppRadii.full),
                onTap: () => onSelected(tone.isDefault ? null : tone.key),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: tone.surfaceFor(brightness) ?? palette.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            selectedKey == tone.key
                                ? palette.primary
                                : tone.borderFor(brightness) ??
                                    palette.borderStrong,
                        width: selectedKey == tone.key ? 2 : 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrashBanner extends StatelessWidget {
  final VoidCallback onRestore;

  const _TrashBanner({required this.onRestore});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.sm,
        Spacing.sm,
        Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.errorWash,
        borderRadius: AppRadii.all(AppRadii.base),
      ),
      child: Row(
        children: [
          Icon(Symbols.delete, size: 18, color: palette.onErrorWash),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              'This note is in the trash.',
              style: context.texts.bodySmall?.copyWith(
                color: palette.onErrorWash,
              ),
            ),
          ),
          TextButton(
            onPressed: onRestore,
            style: TextButton.styleFrom(foregroundColor: palette.onErrorWash),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}
