import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
import '../editor/checklist_editor.dart';
import 'note_actions.dart';

/// The document canvas.
///
/// The page background takes the note's tone; the document itself is a centred
/// `surface` sheet with `lg` corners at Level 1. A property block sits between
/// hairline rules under the title, the way a database page reads.
class NoteEditorScreen extends ConsumerStatefulWidget {
  final String noteId;

  const NoteEditorScreen({super.key, required this.noteId});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();
  Timer? _debounce;
  bool _loaded = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _hydrate(Note? note) {
    if (note == null || _loaded) return;
    _loaded = true;
    _title.text = note.title;
    _content.text = note.content;
  }

  void _scheduleSave(Future<void> Function() write) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      await write();
      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
    });
  }

  void _saveTitle(String value) {
    _scheduleSave(() =>
        ref.read(notesDaoProvider).updateNote(widget.noteId, title: value));
  }

  void _saveContent(String value) {
    _scheduleSave(() =>
        ref.read(notesDaoProvider).updateNote(widget.noteId, content: value));
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
          builder: (context, labelsSnapshot) =>
              _buildScaffold(context, note, labelsSnapshot.data),
        );
      },
    );
  }

  Widget _buildScaffold(BuildContext context, Note note, List<Label>? labels) {
    final palette = context.palette;
    final surface = NoteSurface.of(context, note.color, raised: false);
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;

    return Scaffold(
      backgroundColor: surface.background,
      appBar: AppBar(
        backgroundColor: surface.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: surface.foreground,
        titleSpacing: 0,
        title: _Breadcrumbs(note: note, surface: surface),
        actions: [
          if (wide) ...[
            _SwatchRow(
              current: note.color,
              onSelected: (key) =>
                  NoteActions.setColor(ref, widget.noteId, key),
            ),
            const SizedBox(width: Spacing.md),
          ],
          if (note.reminderAt != null)
            Padding(
              padding: const EdgeInsets.only(right: Spacing.sm),
              child: _ReminderButton(
                when: note.reminderAt!,
                onTap: () => _onMenu('reminder', note),
              ),
            ),
          GhostIconButton(
            icon: Symbols.push_pin,
            fill: note.isPinned ? 1 : 0,
            tooltip: note.isPinned ? 'Unpin' : 'Pin',
            color: note.isPinned ? palette.primary : surface.mutedForeground,
            onPressed: () =>
                NoteActions.setPinned(ref, widget.noteId, !note.isPinned),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: Icon(Symbols.more_horiz, color: surface.mutedForeground),
            onSelected: (v) => _onMenu(v, note),
            itemBuilder: (context) => _menuItems(note),
          ),
          const SizedBox(width: Spacing.sm),
        ],
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
            child: SurfacePanel(
              radius: AppRadii.lg,
              padding: EdgeInsets.all(wide ? Spacing.xxl : Spacing.lg),
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
                  IconTile(
                    icon: _typeIcon(note.noteType),
                    size: 44,
                    background: palette.primaryWash,
                    color: palette.onPrimaryWash,
                  ),
                  const SizedBox(height: Spacing.lg),
                  TextField(
                    controller: _title,
                    style: context.display,
                    maxLines: null,
                    decoration: InputDecoration(
                      filled: false,
                      hintText: 'Untitled',
                      hintStyle: context.display
                          .copyWith(color: palette.textTertiary),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: _saveTitle,
                  ),
                  const SizedBox(height: Spacing.xl),
                  _PropertyBlock(
                    note: note,
                    labels: labels ?? const <Label>[],
                    onEditLabels: () => _onMenu('labels', note),
                    onEditReminder: () => _onMenu('reminder', note),
                    onEditColour: () => _onMenu('color', note),
                  ),
                  const SizedBox(height: Spacing.xl),
                  if (note.noteType == 'text')
                    TextField(
                      controller: _content,
                      maxLines: null,
                      minLines: 8,
                      keyboardType: TextInputType.multiline,
                      style: context.texts.bodyLarge,
                      decoration: InputDecoration(
                        filled: false,
                        hintText: "Start writing, or press '/' for blocks…",
                        hintStyle: context.texts.bodyLarge
                            ?.copyWith(color: palette.textTertiary),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: _saveContent,
                    ),
                  if (note.noteType == 'checklist')
                    ChecklistEditor(
                      noteId: widget.noteId,
                      onChanged: _refreshChecklistPreview,
                    ),
                  if (note.noteType == 'document')
                    BlockEditor(noteId: widget.noteId),
                  const SizedBox(height: Spacing.xl),
                  AttachmentsSection(noteId: widget.noteId),
                  const SizedBox(height: Spacing.xl),
                  Divider(color: palette.border, height: 1),
                  const SizedBox(height: Spacing.md),
                  Text(
                    'Created ${_stamp(note.createdAt)}  ·  '
                    'Updated ${_stamp(note.updatedAt)}',
                    style: context.mono.copyWith(color: palette.textTertiary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _stamp(DateTime when) => DateFormat('d MMM yyyy, HH:mm').format(when);

  IconData _typeIcon(String type) => switch (type) {
        'checklist' => Symbols.checklist,
        'document' => Symbols.article,
        _ => Symbols.notes,
      };

  List<PopupMenuEntry<String>> _menuItems(Note note) {
    return [
      PopupMenuItem(
          value: 'pin', child: Text(note.isPinned ? 'Unpin' : 'Pin')),
      if (note.isTrashed) ...[
        const PopupMenuItem(value: 'restore', child: Text('Restore')),
        const PopupMenuItem(
            value: 'delete_forever', child: Text('Delete forever')),
      ] else ...[
        PopupMenuItem(
            value: 'archive',
            child: Text(note.isArchived ? 'Unarchive' : 'Archive')),
        const PopupMenuItem(value: 'labels', child: Text('Labels')),
        const PopupMenuItem(value: 'color', child: Text('Change colour')),
        const PopupMenuItem(value: 'reminder', child: Text('Reminder')),
        const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
        PopupMenuItem(
          value: 'delete',
          child: Text('Move to trash',
              style: TextStyle(color: context.palette.error)),
        ),
      ],
    ];
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
        await showNoteColorDialog(context, note.color,
            (key) => NoteActions.setColor(ref, widget.noteId, key));
      case 'reminder':
        await showReminderDialog(
          context,
          ref,
          widget.noteId,
          current: note.reminderAt,
          onSet: (when) => NoteActions.setReminder(
              ref, widget.noteId, _title.text, when),
        );
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

  Future<void> _refreshChecklistPreview() async {
    final dao = ref.read(notesDaoProvider);
    final items = await dao.getChecklistItems(widget.noteId);
    final preview = items
        .map((i) => '${i.isCompleted ? '\u2611' : '\u2610'} ${i.content}')
        .join('\n');
    await dao.updateNote(widget.noteId, content: preview);
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
    final crumbStyle =
        context.texts.labelMedium?.copyWith(color: surface.mutedForeground);
    final title = note.title.trim();

    return Row(
      children: [
        InkWell(
          borderRadius: AppRadii.all(AppRadii.handle + 2),
          onTap: () => context.go(note.isTrashed
              ? '/trash'
              : note.isArchived
                  ? '/archive'
                  : '/notes'),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm - 2, vertical: 2),
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
              fontWeight: FontWeight.w600,
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
          horizontal: Spacing.sm, vertical: Spacing.xs + 1),
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
                        color: selectedKey == tone.key
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

/// The reminder as a tappable pill in the app bar, urgency-coloured.
class _ReminderButton extends StatelessWidget {
  final DateTime when;
  final VoidCallback onTap;

  const _ReminderButton({required this.when, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final overdue = when.isBefore(DateTime.now());
    return InkWell(
      borderRadius: AppRadii.all(AppRadii.full),
      onTap: onTap,
      child: StatusPill(
        label: DateFormat('EEE d MMM, h:mm a').format(when),
        background: overdue ? palette.errorWash : palette.surfaceSunken,
        foreground: overdue ? palette.onErrorWash : palette.textSecondary,
        icon: Symbols.alarm,
      ),
    );
  }
}

/// Property rows: an outline icon, a fixed-width label column, then the value.
class _PropertyBlock extends StatelessWidget {
  final Note note;
  final List<Label> labels;
  final VoidCallback onEditLabels;
  final VoidCallback onEditReminder;
  final VoidCallback onEditColour;

  const _PropertyBlock({
    required this.note,
    required this.labels,
    required this.onEditLabels,
    required this.onEditReminder,
    required this.onEditColour,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: palette.border, height: 1),
        const SizedBox(height: Spacing.md),
        _row(
          context,
          icon: Symbols.circle,
          label: 'Status',
          child: StatusPill(
            label: note.isTrashed
                ? 'In trash'
                : note.isArchived
                    ? 'Archived'
                    : 'Active',
            background: note.isTrashed
                ? palette.errorWash
                : note.isArchived
                    ? palette.surfaceSunken
                    : palette.primaryWash,
            foreground: note.isTrashed
                ? palette.onErrorWash
                : note.isArchived
                    ? palette.textSecondary
                    : palette.onPrimaryWash,
            dot: true,
          ),
        ),
        _row(
          context,
          icon: Symbols.sell,
          label: 'Labels',
          child: Wrap(
            spacing: Spacing.sm - 2,
            runSpacing: Spacing.sm - 2,
            children: [
              for (final label in labels) TagChip(label: '#${label.name}'),
              TagChip(
                label: labels.isEmpty ? 'Add label' : '+',
                icon: labels.isEmpty ? Symbols.add : null,
                onTap: onEditLabels,
              ),
            ],
          ),
        ),
        _row(
          context,
          icon: Symbols.alarm,
          label: 'Reminder',
          child: note.reminderAt == null
              ? TagChip(
                  label: 'Set reminder',
                  icon: Symbols.add,
                  onTap: onEditReminder,
                )
              : InkWell(
                  borderRadius: AppRadii.all(AppRadii.handle + 2),
                  onTap: onEditReminder,
                  child: Text(
                    DateFormat('EEE d MMM yyyy, HH:mm').format(note.reminderAt!),
                    style: context.mono.copyWith(color: palette.textPrimary),
                  ),
                ),
        ),
        _row(
          context,
          icon: Symbols.palette,
          label: 'Colour',
          child: InkWell(
            borderRadius: AppRadii.all(AppRadii.handle + 2),
            onTap: onEditColour,
            child: Text(
              noteColorByKey(note.color)?.label ?? 'White',
              style: context.texts.bodyMedium,
            ),
          ),
        ),
        _row(
          context,
          icon: Symbols.description,
          label: 'Type',
          child: Text(
            switch (note.noteType) {
              'checklist' => 'Checklist',
              'document' => 'Document',
              _ => 'Note',
            },
            style: context.texts.bodyMedium,
          ),
        ),
        const SizedBox(height: Spacing.md),
        Divider(color: palette.border, height: 1),
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm - 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 148,
            child: Row(
              children: [
                Icon(icon, size: 17, color: palette.textTertiary),
                const SizedBox(width: Spacing.sm),
                Text(
                  label,
                  style: context.texts.bodySmall
                      ?.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(child: child),
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
          Spacing.md, Spacing.sm, Spacing.sm, Spacing.sm),
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
              style: context.texts.bodySmall
                  ?.copyWith(color: palette.onErrorWash),
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
