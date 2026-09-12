import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/router.dart';
import '../../app/spacing.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../../shared/models/note_models.dart';
import '../../shared/widgets/app_widgets.dart';
import 'create_menu.dart';
import 'note_card.dart';
import 'note_composer.dart';
import 'note_queries.dart';
import 'notes_section.dart';
import 'view_mode.dart';

/// The canvas: quick capture, then grouped masonry.
///
/// Notes and label views group PINNED / OTHERS. Reminders group by time bucket
/// (overdue, today, tomorrow, later) the way a schedule reads.
class NotesScreen extends ConsumerStatefulWidget {
  final NotesSection section;
  final String? labelId;

  const NotesScreen({super.key, required this.section, this.labelId});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  bool get _isNotesWall => widget.section == NotesSection.notes;

  bool _createOpen = false;

  void _setCreateOpen(bool open) {
    if (_createOpen == open) return;
    setState(() => _createOpen = open);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= kWideLayoutBreakpoint;
    final grid = ref.watch(viewModeProvider).valueOrNull ?? true;
    final gutter =
        width >= Breakpoints.laptop
            ? Spacing.xxl
            : width >= Breakpoints.tablet
            ? Spacing.xl
            : Spacing.md;
    // Quick capture is a pointer affordance; on touch the FAB covers creation,
    // and showing both would be two buttons for one job.
    final showComposer = _isNotesWall && wide;

    final query = (section: widget.section, labelId: widget.labelId);
    final notesAsync = ref.watch(sectionNotesProvider(query));

    // Hoisted above the Scaffold so the FAB can react to an empty wall.
    return Builder(
      builder: (context) {
        final notes = notesAsync.valueOrNull;
        final isEmpty = notes != null && notes.isEmpty;
        final groups = notes == null ? const <_NoteGroup>[] : _groupsFor(notes);
        // A header earns its space only when there is more than one group to
        // tell apart. A lone "NOTES — sorted by last modified" rule over a lone
        // wall just repeats the page name in the bar above it.
        final showGroupHeaders = groups.length > 1;

        return Scaffold(
          backgroundColor: palette.surface,
          floatingActionButton: _fab(isEmpty: isEmpty, wide: wide),
          body: Stack(
            children: [
              _canvas(
                notesAsync: notesAsync,
                notes: notes,
                groups: groups,
                showGroupHeaders: showGroupHeaders,
                showComposer: showComposer,
                grid: grid,
                gutter: gutter,
                query: query,
              ),
              // Below the FAB in paint order, so the canvas dims while the
              // create menu and its pills stay lit.
              Positioned.fill(
                child: CreateMenuScrim(
                  open: _createOpen,
                  onDismiss: () => _setCreateOpen(false),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _canvas({
    required AsyncValue<List<Note>> notesAsync,
    required List<Note>? notes,
    required List<_NoteGroup> groups,
    required bool showGroupHeaders,
    required bool showComposer,
    required bool grid,
    required double gutter,
    required NotesQuery query,
  }) {
    return CustomScrollView(
      slivers: [
        // No page banner: the top bar names the page. The canvas goes
        // straight into capture, or straight into the cards.
        if (showComposer)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                gutter,
                Spacing.xl,
                gutter,
                Spacing.xl,
              ),
              child: const Center(child: NoteComposer()),
            ),
          )
        else
          const SliverToBoxAdapter(child: SizedBox(height: Spacing.lg)),
        if (notesAsync.hasError)
          SliverFillRemaining(
            hasScrollBody: false,
            child: InlineError(
              message: 'Those notes could not be loaded.',
              // Rebuilding the widget no longer re-runs the query now that
              // it is cached, so retry has to drop the cached value.
              onRetry: () => ref.invalidate(sectionNotesProvider(query)),
            ),
          )
        else if (notes == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: CenteredLoader(),
          )
        else if (notes.isEmpty)
          // No inline action: creation already has exactly one home per
          // layout — quick capture above on pointer, the extended FAB on
          // touch.
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptySection(section: widget.section),
          )
        else ...[
          for (final group in groups) ...[
            if (showGroupHeaders)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    Spacing.sm,
                    gutter,
                    Spacing.md,
                  ),
                  child: SectionHeader(
                    icon: group.icon,
                    label: group.label,
                    count: group.notes.length,
                  ),
                ),
              ),
            if (grid)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, Spacing.xl),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final available = constraints.crossAxisExtent;
                    final gap = gutterFor(available);
                    return SliverMasonryGrid.count(
                      crossAxisCount: columnsFor(available, group.notes.length),
                      mainAxisSpacing: gap,
                      crossAxisSpacing: gap,
                      childCount: group.notes.length,
                      itemBuilder:
                          (context, i) => NoteCard(
                            note: group.notes[i],
                            section: widget.section,
                          ),
                    );
                  },
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, Spacing.xl),
                sliver: _NoteListSliver(
                  notes: group.notes,
                  section: widget.section,
                ),
              ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: Spacing.xxxl)),
        ],
      ],
    );
  }

  /// The FAB is a touch-only affordance. Pointer layouts already carry quick
  /// capture at the top of the canvas, so a floating button there would be a
  /// second control for one job.
  ///
  /// On an empty wall it is labelled `+ New note` — the one moment the canvas
  /// has nothing to say, so the next action gets a name. Once notes exist it
  /// collapses to a bare `+` that fans out into the block shortcuts.
  Widget? _fab({required bool isEmpty, required bool wide}) {
    if (!_isNotesWall || wide) return null;
    return CreateMenu(
      open: _createOpen,
      labelled: isEmpty,
      onOpenChanged: _setCreateOpen,
      onCreate: _create,
    );
  }

  /// Groups notes for the active section.
  ///
  /// A single group renders bare — the page is already named in the top bar. Two
  /// or more get [SectionHeader]s, so the canvas reads as a schedule or a pin
  /// board rather than one undifferentiated wall.
  List<_NoteGroup> _groupsFor(List<Note> notes) {
    if (widget.section == NotesSection.reminders) {
      return _reminderBuckets(notes);
    }

    if (widget.section == NotesSection.trash) {
      return [
        _NoteGroup(icon: Symbols.delete, label: 'In the bin', notes: notes),
      ];
    }

    final pinned = notes.where((n) => n.isPinned).toList();
    final others = notes.where((n) => !n.isPinned).toList();

    if (pinned.isEmpty) {
      return [
        _NoteGroup(
          icon: Symbols.grid_view,
          label: widget.section == NotesSection.archive ? 'Archived' : 'Notes',
          notes: others,
        ),
      ];
    }

    return [
      _NoteGroup(icon: Symbols.push_pin, label: 'Pinned notes', notes: pinned),
      if (others.isNotEmpty)
        _NoteGroup(icon: Symbols.grid_view, label: 'Others', notes: others),
    ];
  }

  /// Overdue / today / tomorrow / later, in schedule order.
  List<_NoteGroup> _reminderBuckets(List<Note> notes) {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final tomorrowEnd = todayEnd.add(const Duration(days: 1));

    final overdue = <Note>[];
    final today = <Note>[];
    final tomorrow = <Note>[];
    final later = <Note>[];

    for (final note in notes) {
      final when = note.reminderAt;
      if (when == null) continue;
      if (when.isBefore(now)) {
        overdue.add(note);
      } else if (!when.isAfter(todayEnd)) {
        today.add(note);
      } else if (!when.isAfter(tomorrowEnd)) {
        tomorrow.add(note);
      } else {
        later.add(note);
      }
    }

    int byDate(Note a, Note b) => a.reminderAt!.compareTo(b.reminderAt!);
    for (final bucket in [overdue, today, tomorrow, later]) {
      bucket.sort(byDate);
    }

    return [
      if (overdue.isNotEmpty)
        _NoteGroup(icon: Symbols.error, label: 'Overdue', notes: overdue),
      if (today.isNotEmpty)
        _NoteGroup(icon: Symbols.today, label: 'Today', notes: today),
      if (tomorrow.isNotEmpty)
        _NoteGroup(icon: Symbols.wb_sunny, label: 'Tomorrow', notes: tomorrow),
      if (later.isNotEmpty)
        _NoteGroup(
          icon: Symbols.next_week,
          label: 'Next week & later',
          notes: later,
        ),
    ];
  }

  /// Creates a note and opens it, optionally seeded with one block.
  ///
  /// [seed] is a shortcut, not a note type: the note is the same either way, and
  /// every other block stays a `/` away inside the editor.
  Future<void> _create([BlockType? seed]) async {
    final dao = ref.read(notesDaoProvider);
    final note = await dao.createNote(title: '');
    if (seed != null) {
      await dao.insertBlockAt(note.id, position: 0, type: seed);
    }
    if (mounted) context.push('/editor/${note.id}');
  }
}

/// One rendered group on the canvas.
class _NoteGroup {
  final IconData icon;
  final String label;
  final List<Note> notes;

  const _NoteGroup({
    required this.icon,
    required this.label,
    required this.notes,
  });
}

/// Gap between masonry cards, tighter on phones.
double gutterFor(double width) =>
    width < Breakpoints.tablet ? Spacing.md : Spacing.lg;

/// Auto-fill against a minimum card width, capped at five columns.
///
/// Phones use a smaller minimum so the wall stays two columns the way Keep
/// does; a 240px minimum would collapse a 360px screen to one column and lose
/// the masonry entirely.
///
/// Never returns more columns than there are notes: an empty column beside a
/// lone card reads as a layout bug, so a single note takes the full width and
/// any smaller-than-capacity group divides the width equally.
int columnsFor(double width, int noteCount) {
  final gutter = gutterFor(width);
  final minWidth =
      width < Breakpoints.tablet
          ? Sizes.minCardWidthCompact
          : Sizes.minCardWidth;
  final fits = ((width + gutter) / (minWidth + gutter)).floor().clamp(1, 5);
  return noteCount < fits ? math.max(1, noteCount) : fits;
}

/// Single-column list, capped at reading width and centred on wide screens — a
/// stack of 1400px-wide cards is unreadable.
/// Single-column list, capped at reading width and centred on wide screens — a
/// stack of 1400px-wide cards is unreadable.
///
/// A sliver rather than a `Column`, so rows are built as they scroll into view.
/// The old version built every card in the section up front, which on a large
/// wall meant hundreds of cards and their queries constructed before the first
/// frame.
class _NoteListSliver extends StatelessWidget {
  final List<Note> notes;
  final NotesSection section;

  const _NoteListSliver({required this.notes, required this.section});

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: notes.length,
      itemBuilder:
          (context, i) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Sizes.sheet),
              child: Padding(
                padding: const EdgeInsets.only(bottom: Spacing.md),
                child: NoteCard(note: notes[i], section: section),
              ),
            ),
          ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final NotesSection section;

  const _EmptySection({required this.section});

  @override
  Widget build(BuildContext context) {
    final (icon, title, message) = switch (section) {
      NotesSection.notes => (
        Symbols.lightbulb,
        'Nothing captured yet',
        'Notes you add show up here, newest first.',
      ),

      NotesSection.archive => (
        Symbols.inventory_2,
        'Archive is empty',
        'Archived notes are kept out of the way but never deleted.',
      ),
      NotesSection.trash => (
        Symbols.delete,
        'Trash is empty',
        'Deleted notes wait here until you remove them for good.',
      ),
      NotesSection.reminders => (
        Symbols.notifications,
        'No reminders scheduled',
        'Add a reminder to a note and it will appear on this schedule.',
      ),
      NotesSection.label => (
        Symbols.tag,
        'Nothing carries this label yet',
        'Open a note and apply this label to collect it here.',
      ),
    };

    return EmptyState(icon: icon, title: title, message: message);
  }
}
