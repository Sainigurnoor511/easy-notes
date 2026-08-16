import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/spacing.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../../shared/models/note_models.dart';
import 'note_card.dart';
import 'note_composer.dart';
import 'notes_section.dart';

class NotesScreen extends ConsumerStatefulWidget {
  final NotesSection section;
  final String? labelId;

  const NotesScreen({super.key, required this.section, this.labelId});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  bool _grid = true;

  @override
  void initState() {
    super.initState();
    _loadViewPref();
  }

  Future<void> _loadViewPref() async {
    final value = await ref.read(settingsDaoProvider).get('view_mode');
    if (mounted) {
      setState(() => _grid = value != 'list');
    }
  }

  Future<void> _setView(bool grid) async {
    setState(() => _grid = grid);
    await ref
        .read(settingsDaoProvider)
        .set('view_mode', grid ? 'grid' : 'list');
  }

  @override
  Widget build(BuildContext context) {
    final notes = _notesStream();
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final showComposer = widget.section == NotesSection.notes;

    return Scaffold(
      floatingActionButton: showComposer && !wide
          ? FloatingActionButton(
              onPressed: _showCreateSheet,
              tooltip: 'New note',
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showComposer)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.md, Spacing.lg, Spacing.md, Spacing.sm),
              child: Center(child: NoteComposer()),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md, vertical: Spacing.sm),
            child: Row(
              children: [
                _SectionTitle(section: widget.section),
                const Spacer(),
                if (showComposer)
                  IconButton(
                    tooltip: _grid ? 'List view' : 'Grid view',
                    icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
                    onPressed: () => _setView(!_grid),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Note>>(
              stream: notes,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snapshot.data!;
                if (list.isEmpty) return _EmptyState(section: widget.section);
                return _grid ? _buildGrid(list) : _buildList(list);
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<List<Note>> _notesStream() {
    final dao = ref.watch(notesDaoProvider);
    switch (widget.section) {
      case NotesSection.notes:
        return dao.watchActive();
      case NotesSection.archive:
        return dao.watchArchived();
      case NotesSection.trash:
        return dao.watchTrashed();
      case NotesSection.reminders:
        return dao.watchReminders();
      case NotesSection.label:
        return dao.watchByLabel(widget.labelId!);
    }
  }

  Widget _buildGrid(List<Note> notes) {
    final width = MediaQuery.of(context).size.width;
    // Column counts keyed to the standard 375/768/1024/1440 breakpoints.
    final columns = width >= Breakpoints.wide
        ? 5
        : width >= Breakpoints.desktop
            ? 4
            : width >= Breakpoints.tablet
                ? 3
                : width >= Breakpoints.mobile
                    ? 2
                    : 1;
    const spacing = Spacing.md;
    final padding = width >= Breakpoints.tablet ? Spacing.lg : Spacing.md;
    final itemWidth =
        (width - padding * 2 - spacing * (columns - 1)) / columns;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final note in notes)
            SizedBox(
              width: itemWidth,
              child: NoteCard(note: note, section: widget.section),
            ),
        ],
      ),
    );
  }

  Widget _buildList(List<Note> notes) {
    final width = MediaQuery.of(context).size.width;
    final padding = width >= Breakpoints.tablet ? Spacing.lg : Spacing.md;
    return ListView.builder(
      padding: EdgeInsets.all(padding),
      itemCount: notes.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.sm),
        child: NoteCard(note: notes[i], section: widget.section),
      ),
    );
  }

  void _showCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('New Note'),
              onTap: () {
                Navigator.pop(context);
                _create(NoteType.text);
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('New Checklist'),
              onTap: () {
                Navigator.pop(context);
                _create(NoteType.checklist);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _create(NoteType type) async {
    final dao = ref.read(notesDaoProvider);
    final note = await dao.createNote(title: '', type: type);
    if (mounted) context.push('/editor/${note.id}');
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.section});

  final NotesSection section;

  @override
  Widget build(BuildContext context) {
    final text = switch (section) {
      NotesSection.notes => 'Notes',
      NotesSection.archive => 'Archive',
      NotesSection.trash => 'Trash',
      NotesSection.reminders => 'Reminders',
      NotesSection.label => 'Label',
    };
    return Text(text, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _EmptyState extends StatelessWidget {
  final NotesSection section;

  const _EmptyState({required this.section});

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (section) {
      NotesSection.notes => (Icons.lightbulb_outline, 'Notes you add appear here'),
      NotesSection.archive => (Icons.archive_outlined, 'No archived notes'),
      NotesSection.trash => (Icons.delete_outline, 'Trash is empty'),
      NotesSection.reminders => (Icons.alarm, 'No reminders'),
      NotesSection.label => (Icons.label_outline, 'No notes with this label'),
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: Spacing.sm),
          Text(text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
