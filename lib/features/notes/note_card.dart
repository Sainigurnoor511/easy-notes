import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../../shared/models/note_models.dart';
import '../../shared/widgets/note_dialogs.dart';
import '../../app/router.dart';
import '../../app/spacing.dart';
import 'note_actions.dart';
import 'notes_section.dart';

class NoteCard extends ConsumerStatefulWidget {
  final Note note;
  final NotesSection section;

  const NoteCard({super.key, required this.note, required this.section});

  @override
  ConsumerState<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends ConsumerState<NoteCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final color = noteColorByKey(note.color);
    final theme = Theme.of(context);

    final Color background =
        color?.background ?? theme.colorScheme.surfaceContainerHigh;
    final Color foreground = color?.foreground ?? theme.colorScheme.onSurface;

    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final showActions = !wide || _hovering;

    return StreamBuilder<List<Label>>(
      stream: ref.watch(labelsDaoProvider).watchForNote(note.id),
      builder: (context, snapshot) {
        final labels = snapshot.data;
        return MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: Card(
            color: background,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/editor/${note.id}'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.sm, Spacing.sm, Spacing.xs, Spacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: note.title.isEmpty
                              ? const SizedBox.shrink()
                              : Text(
                                  note.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(color: foreground),
                                ),
                        ),
                        AnimatedOpacity(
                          opacity: note.isPinned || showActions ? 1 : 0,
                          duration: const Duration(milliseconds: 120),
                          child: IgnorePointer(
                            ignoring: !note.isPinned && !showActions,
                            child: IconButton(
                              tooltip: note.isPinned ? 'Unpin' : 'Pin',
                              icon: Icon(
                                note.isPinned
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined,
                                size: 18,
                                color: foreground,
                              ),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => NoteActions.setPinned(
                                  ref, note.id, !note.isPinned),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (note.noteType == 'checklist')
                      _ChecklistPreview(noteId: note.id, foreground: foreground)
                    else if (note.content.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          note.content,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: foreground),
                        ),
                      ),
                    if (note.reminderAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Spacing.xs),
                        child: Row(
                          children: [
                            Icon(Icons.alarm, size: 14, color: foreground),
                            const SizedBox(width: Spacing.xs),
                            Flexible(
                              child: Text(
                                DateFormat.MMMd()
                                    .add_jm()
                                    .format(note.reminderAt!),
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: foreground),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (labels != null && labels.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: Spacing.xs),
                        child: Wrap(
                          spacing: Spacing.xs,
                          runSpacing: Spacing.xs,
                          children: [
                            for (final l in labels)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: foreground.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  l.name,
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(color: foreground),
                                ),
                              ),
                          ],
                        ),
                      ),
                    AnimatedOpacity(
                      opacity: showActions ? 1 : 0,
                      duration: const Duration(milliseconds: 120),
                      child: IgnorePointer(
                        ignoring: !showActions,
                        child: _CardActionBar(
                            note: note,
                            section: widget.section,
                            color: foreground),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChecklistPreview extends ConsumerWidget {
  final String noteId;
  final Color foreground;

  const _ChecklistPreview({required this.noteId, required this.foreground});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<ChecklistItem>>(
      stream: ref.watch(notesDaoProvider).watchChecklistItems(noteId),
      builder: (context, snapshot) {
        final shown = (snapshot.data ?? const <ChecklistItem>[])
            .take(4)
            .toList();
        if (shown.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in shown)
                Row(
                  children: [
                    Icon(
                      item.isCompleted
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 16,
                      color: foreground,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: foreground,
                            decoration: item.isCompleted
                                ? TextDecoration.lineThrough
                                : null),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Keep-style footer: a row of quick actions that appears on hover, with
/// less-common actions tucked behind an overflow menu.
class _CardActionBar extends ConsumerWidget {
  final Note note;
  final NotesSection section;
  final Color color;

  const _CardActionBar(
      {required this.note, required this.section, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (section.isTrash) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => NoteActions.restore(ref, note.id),
            child: const Text('Restore'),
          ),
          TextButton(
            onPressed: () => NoteActions.deleteForever(ref, note.id),
            child: const Text('Delete forever'),
          ),
        ],
      );
    }
    return Row(
      children: [
        IconButton(
          tooltip: 'Change color',
          icon: Icon(Icons.palette_outlined, size: 20, color: color),
          visualDensity: VisualDensity.compact,
          onPressed: () => showNoteColorDialog(context, note.color,
              (key) => NoteActions.setColor(ref, note.id, key)),
        ),
        IconButton(
          tooltip: 'Reminder',
          icon: Icon(Icons.notifications_outlined, size: 20, color: color),
          visualDensity: VisualDensity.compact,
          onPressed: () => showReminderDialog(
            context,
            ref,
            note.id,
            current: note.reminderAt,
            onSet: (when) =>
                NoteActions.setReminder(ref, note.id, note.title, when),
          ),
        ),
        IconButton(
          tooltip: 'Labels',
          icon: Icon(Icons.label_outline, size: 20, color: color),
          visualDensity: VisualDensity.compact,
          onPressed: () => showLabelPickerDialog(context, ref, note.id),
        ),
        IconButton(
          tooltip: section.isArchive ? 'Unarchive' : 'Archive',
          icon: Icon(
              section.isArchive
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
              size: 20,
              color: color),
          visualDensity: VisualDensity.compact,
          onPressed: () =>
              NoteActions.setArchived(ref, note.id, !section.isArchive),
        ),
        const Spacer(),
        _MoreMenu(note: note, color: color),
      ],
    );
  }
}

class _MoreMenu extends ConsumerWidget {
  final Note note;
  final Color color;

  const _MoreMenu({required this.note, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 20, color: color),
      onSelected: (value) => _handle(context, ref, value),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }

  Future<void> _handle(
      BuildContext context, WidgetRef ref, String value) async {
    switch (value) {
      case 'duplicate':
        await NoteActions.duplicate(ref, note.id);
      case 'delete':
        await NoteActions.trash(ref, note.id);
    }
  }
}
