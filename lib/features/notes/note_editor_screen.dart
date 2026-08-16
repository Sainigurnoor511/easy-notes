import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../../shared/models/note_models.dart';
import '../../shared/widgets/note_dialogs.dart';
import '../editor/attachments_section.dart';
import '../editor/block_editor.dart';
import '../editor/checklist_editor.dart';
import 'note_actions.dart';

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
            body: const Center(child: Text('This note no longer exists.')),
          );
        }

        return StreamBuilder<List<Label>>(
          stream: ref.watch(labelsDaoProvider).watchForNote(widget.noteId),
          builder: (context, labelsSnapshot) {
            final labels = labelsSnapshot.data;
            return _buildScaffold(context, note, labels);
          },
        );
      },
    );
  }

  Widget _buildScaffold(BuildContext context, Note note, List<Label>? labels) {
    final theme = Theme.of(context);
    final color = noteColorByKey(note.color);

    return Scaffold(
      backgroundColor: color?.background ?? theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor:
            color?.foreground ?? theme.colorScheme.onSurface,
        actions: [
          if (note.isPinned)
            IconButton(
              tooltip: 'Unpin',
              icon: const Icon(Icons.push_pin),
              onPressed: () =>
                  NoteActions.setPinned(ref, widget.noteId, false),
            ),
          PopupMenuButton<String>(
            onSelected: (v) => _onMenu(v, note),
            itemBuilder: (context) => _menuItems(note),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: color?.foreground ?? theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: _saveTitle,
            ),
            if (note.noteType == 'text')
              TextField(
                controller: _content,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: color?.foreground ?? theme.colorScheme.onSurface),
                decoration: const InputDecoration(
                  hintText: 'Take a note...',
                  border: InputBorder.none,
                ),
                onChanged: _saveContent,
              ),
            if (note.noteType == 'checklist')
              ChecklistEditor(
                noteId: widget.noteId,
                onChanged: _refreshChecklistPreview,
              ),
            if (note.noteType == 'document')
              BlockEditor(noteId: widget.noteId),
            const SizedBox(height: 16),
            AttachmentsSection(noteId: widget.noteId),
            if (labels != null && labels.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final l in labels)
                    Chip(
                      label: Text(l.name),
                      labelStyle: TextStyle(
                          color:
                              color?.foreground ?? theme.colorScheme.onSurface),
                      backgroundColor: (color?.foreground ??
                              theme.colorScheme.onSurface)
                          .withValues(alpha: 0.1),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _menuItems(Note note) {
    return [
      PopupMenuItem(
          value: 'pin',
          child: Text(note.isPinned ? 'Unpin' : 'Pin')),
      if (note.isTrashed) ...[
        const PopupMenuItem(value: 'restore', child: Text('Restore')),
        const PopupMenuItem(
            value: 'delete_forever', child: Text('Delete forever')),
      ] else ...[
        PopupMenuItem(
            value: 'archive',
            child: Text(note.isArchived ? 'Unarchive' : 'Archive')),
        const PopupMenuItem(value: 'labels', child: Text('Labels')),
        const PopupMenuItem(value: 'color', child: Text('Change color')),
        const PopupMenuItem(value: 'reminder', child: Text('Reminder')),
        const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
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