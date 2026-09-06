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
import 'note_card.dart';
import 'note_composer.dart';
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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= kWideLayoutBreakpoint;
    final grid = ref.watch(viewModeProvider).valueOrNull ?? true;
    final gutter = width >= Breakpoints.laptop
        ? Spacing.xxl
        : width >= Breakpoints.tablet
            ? Spacing.xl
            : Spacing.md;
    // Quick capture is a pointer affordance; on touch the FAB covers creation,
    // and showing both would be two buttons for one job.
    final showComposer = _isNotesWall && wide;
    final showHeader = !(_isNotesWall && !wide);

    // Hoisted above the Scaffold so the FAB can react to an empty wall.
    return StreamBuilder<List<Note>>(
      stream: _notesStream(),
      builder: (context, snapshot) {
        final notes = snapshot.data;
        final isEmpty = notes != null && notes.isEmpty;

        return Scaffold(
          backgroundColor: palette.canvas,
          floatingActionButton: _fab(isEmpty: isEmpty, wide: wide),
          body: CustomScrollView(
            slivers: [
              // On a phone the notes wall goes straight into the cards: the
              // search pill above already says where you are, and the FAB is the
              // single creation affordance. Other sections keep their banner so
              // the drawer isn't the only way to tell them apart.
              if (showHeader)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        gutter, Spacing.xl, gutter, Spacing.md),
                    child: _PageHeader(
                      section: widget.section,
                      labelId: widget.labelId,
                      count: notes?.length,
                      grid: grid,
                      // On phones the toggle lives in the top bar's search
                      // pill, so the header must not offer a second one.
                      showViewSwitcher: wide,
                    ),
                  ),
                ),
              if (showComposer)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        gutter, Spacing.sm, gutter, Spacing.xl),
                    child: const Center(child: NoteComposer()),
                  ),
                ),
              if (!showHeader && !showComposer)
                const SliverToBoxAdapter(child: SizedBox(height: Spacing.md)),
              if (snapshot.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: InlineError(
                    message: 'Those notes could not be loaded.',
                    onRetry: () => setState(() {}),
                  ),
                )
              else if (notes == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: CenteredLoader(),
                )
              else if (notes.isEmpty)
                // No inline action: the extended FAB is the empty wall's single
                // creation affordance.
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptySection(section: widget.section),
                )
              else ...[
                for (final group in _groupsFor(notes)) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          gutter, Spacing.sm, gutter, Spacing.md),
                      child: SectionHeader(
                        icon: group.icon,
                        label: group.label,
                        count: group.notes.length,
                        trailing: group.trailing == null
                            ? null
                            : Text(
                                group.trailing!,
                                style: context.texts.labelSmall
                                    ?.copyWith(color: palette.textTertiary),
                              ),
                      ),
                    ),
                  ),
                  if (grid)
                    SliverPadding(
                      padding:
                          EdgeInsets.fromLTRB(gutter, 0, gutter, Spacing.xl),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final available = constraints.crossAxisExtent;
                          final gap = gutterFor(available);
                          return SliverMasonryGrid.count(
                            crossAxisCount:
                                columnsFor(available, group.notes.length),
                            mainAxisSpacing: gap,
                            crossAxisSpacing: gap,
                            childCount: group.notes.length,
                            itemBuilder: (context, i) => NoteCard(
                              note: group.notes[i],
                              section: widget.section,
                            ),
                          );
                        },
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            EdgeInsets.fromLTRB(gutter, 0, gutter, Spacing.xl),
                        child: _NoteList(
                            notes: group.notes, section: widget.section),
                      ),
                    ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: Spacing.xxxl)),
              ],
            ],
          ),
        );
      },
    );
  }

  /// The labelled `+ New note` pill appears **only** on an empty wall — that is
  /// the one moment the canvas has nothing to say, so the next action gets a
  /// name. Once notes exist it collapses to a bare `+` on touch, where no other
  /// creation affordance is on screen, and disappears entirely on pointer
  /// layouts, where quick capture sits at the top of the canvas.
  Widget? _fab({required bool isEmpty, required bool wide}) {
    if (!_isNotesWall) return null;
    if (isEmpty) {
      return FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        icon: const Icon(Symbols.add, size: 22),
        label: const Text('New note'),
      );
    }
    if (wide) return null;
    return FloatingActionButton(
      onPressed: _showCreateSheet,
      tooltip: 'New note',
      child: const Icon(Symbols.add, size: 26),
    );
  }

  /// Groups notes for the active section. Every group renders with its own
  /// [SectionHeader], so the canvas reads as a schedule or a pin board rather
  /// than one undifferentiated wall.
  List<_NoteGroup> _groupsFor(List<Note> notes) {
    if (widget.section == NotesSection.reminders) {
      return _reminderBuckets(notes);
    }

    if (widget.section == NotesSection.trash) {
      return [
        _NoteGroup(
          icon: Symbols.delete,
          label: 'In the bin',
          notes: notes,
          trailing: 'Restore or delete forever',
        ),
      ];
    }

    // Everything here is pinned by definition, so a Pinned/Others split would
    // produce one group with a redundant header.
    if (widget.section == NotesSection.pinned) {
      return [
        _NoteGroup(
          icon: Symbols.push_pin,
          label: 'Pinned notes',
          notes: notes,
          trailing: 'Sorted by last modified',
        ),
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
          trailing: 'Sorted by last modified',
        ),
      ];
    }

    return [
      _NoteGroup(
        icon: Symbols.push_pin,
        label: 'Pinned notes',
        notes: pinned,
      ),
      if (others.isNotEmpty)
        _NoteGroup(
          icon: Symbols.grid_view,
          label: 'Others',
          notes: others,
          trailing: 'Sorted by last modified',
        ),
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
        _NoteGroup(
          icon: Symbols.error,
          label: 'Overdue',
          notes: overdue,
        ),
      if (today.isNotEmpty)
        _NoteGroup(icon: Symbols.today, label: 'Today', notes: today),
      if (tomorrow.isNotEmpty)
        _NoteGroup(
          icon: Symbols.wb_sunny,
          label: 'Tomorrow',
          notes: tomorrow,
        ),
      if (later.isNotEmpty)
        _NoteGroup(
          icon: Symbols.next_week,
          label: 'Next week & later',
          notes: later,
        ),
    ];
  }

  Stream<List<Note>> _notesStream() {
    final dao = ref.watch(notesDaoProvider);
    switch (widget.section) {
      case NotesSection.notes:
        return dao.watchActive();
      case NotesSection.pinned:
        return dao
            .watchActive()
            .map((notes) => notes.where((n) => n.isPinned).toList());
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

  void _showCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(Spacing.sm, 0, Spacing.sm, Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.md, 0, Spacing.md, Spacing.md),
                child: Text('New', style: context.texts.headlineMedium),
              ),
              _CreateOption(
                icon: Symbols.notes,
                title: 'Note',
                subtitle: 'Plain text, the fastest way in',
                onTap: () {
                  Navigator.pop(context);
                  _create(NoteType.text);
                },
              ),
              _CreateOption(
                icon: Symbols.checklist,
                title: 'Checklist',
                subtitle: 'Tickable items with progress',
                onTap: () {
                  Navigator.pop(context);
                  _create(NoteType.checklist);
                },
              ),
              _CreateOption(
                icon: Symbols.article,
                title: 'Document',
                subtitle: 'Headings, quotes, code, tables',
                onTap: () {
                  Navigator.pop(context);
                  _create(NoteType.document);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create(NoteType type) async {
    final note =
        await ref.read(notesDaoProvider).createNote(title: '', type: type);
    if (mounted) context.push('/editor/${note.id}');
  }
}

/// One rendered group on the canvas.
class _NoteGroup {
  final IconData icon;
  final String label;
  final List<Note> notes;
  final String? trailing;

  const _NoteGroup({
    required this.icon,
    required this.label,
    required this.notes,
    this.trailing,
  });
}

/// Page banner: section name in `headline-lg`, a monospaced count, and the view
/// switcher.
class _PageHeader extends ConsumerWidget {
  final NotesSection section;
  final String? labelId;
  final int? count;
  final bool grid;
  final bool showViewSwitcher;

  const _PageHeader({
    required this.section,
    required this.labelId,
    required this.count,
    required this.grid,
    required this.showViewSwitcher,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title(context, ref),
              const SizedBox(height: Spacing.xs),
              Row(
                children: [
                  Text(
                    _countLabel(count),
                    style: context.mono.copyWith(color: palette.textTertiary),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text('•',
                      style: context.mono.copyWith(color: palette.textTertiary)),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    _subtitleFor(section),
                    style: context.texts.bodySmall
                        ?.copyWith(color: palette.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showViewSwitcher) ...[
          const SizedBox(width: Spacing.lg),
          _ViewSwitcher(
            grid: grid,
            onChanged: (v) => ref.read(viewModeProvider.notifier).set(v),
          ),
        ],
      ],
    );
  }

  Widget _title(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final style = context.texts.headlineLarge;

    if (section != NotesSection.label || labelId == null) {
      final text = switch (section) {
        NotesSection.notes => 'All notes',
        NotesSection.pinned => 'Pinned',
        NotesSection.archive => 'Archive',
        NotesSection.trash => 'Trash',
        NotesSection.reminders => 'Reminders',
        NotesSection.label => 'Label',
      };
      return Text(text, style: style);
    }

    // Show the label's own name, with the tag glyph, rather than "Label".
    return StreamBuilder<List<Label>>(
      stream: ref.watch(labelsDaoProvider).watchAll(),
      builder: (context, snapshot) {
        String? name;
        for (final l in snapshot.data ?? const <Label>[]) {
          if (l.id == labelId) {
            name = l.name;
            break;
          }
        }
        return Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: palette.primaryWash,
                borderRadius: AppRadii.all(AppRadii.base),
              ),
              child: Icon(Symbols.tag, size: 17, color: palette.onPrimaryWash),
            ),
            const SizedBox(width: Spacing.md),
            Flexible(
              child: Text(name ?? 'Label',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
            ),
          ],
        );
      },
    );
  }

  String _countLabel(int? n) {
    if (n == null) return '—';
    if (n == 0) return 'empty';
    return n == 1 ? '1 note' : '$n notes';
  }

  String _subtitleFor(NotesSection section) => switch (section) {
        NotesSection.notes => 'Capture now, organise later',
        NotesSection.pinned => 'Kept at the top of the canvas',
        NotesSection.archive => 'Kept out of the way, never deleted',
        NotesSection.trash => 'Restore or delete forever',
        NotesSection.reminders => 'Scheduled across your workspace',
        NotesSection.label => 'Every note carrying this label',
      };
}

/// Segmented switcher: a sunken track with 4px padding; the active segment is a
/// surface chip with a Level 1 shadow.
class _ViewSwitcher extends StatelessWidget {
  final bool grid;
  final ValueChanged<bool> onChanged;

  const _ViewSwitcher({required this.grid, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final compact = MediaQuery.sizeOf(context).width < Breakpoints.tablet;

    return Container(
      padding: const EdgeInsets.all(Spacing.xs),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: AppRadii.all(AppRadii.base),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          _segment(context, Symbols.grid_view, 'Masonry', grid, true,
              compact),
          _segment(context, Symbols.view_agenda, 'List', !grid, false,
              compact),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, IconData icon, String label,
      bool selected, bool value, bool compact) {
    final palette = context.palette;
    return Tooltip(
      message: '$label view',
      child: InkWell(
        borderRadius: AppRadii.all(AppRadii.handle + 2),
        onTap: selected ? null : () => onChanged(value),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? Spacing.md - 2 : Spacing.md,
            vertical: Spacing.sm - 1,
          ),
          decoration: BoxDecoration(
            color: selected ? palette.surface : Colors.transparent,
            borderRadius: AppRadii.all(AppRadii.handle + 2),
            boxShadow: selected ? AppShadows.e1(palette) : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? palette.textPrimary : palette.textSecondary,
              ),
              if (!compact) ...[
                const SizedBox(width: Spacing.sm - 2),
                Text(
                  label,
                  style: context.texts.labelMedium?.copyWith(
                    color:
                        selected ? palette.textPrimary : palette.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
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
  final minWidth = width < Breakpoints.tablet
      ? Sizes.minCardWidthCompact
      : Sizes.minCardWidth;
  final fits = ((width + gutter) / (minWidth + gutter)).floor().clamp(1, 5);
  return noteCount < fits ? math.max(1, noteCount) : fits;
}

/// Single-column list, capped at reading width and centred on wide screens — a
/// stack of 1400px-wide cards is unreadable.
class _NoteList extends StatelessWidget {
  final List<Note> notes;
  final NotesSection section;

  const _NoteList({required this.notes, required this.section});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Sizes.sheet),
        child: Column(
          children: [
            for (final note in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.md),
                child: NoteCard(note: note, section: section),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CreateOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: IconTile(icon: icon, size: 40),
      title: Text(title, style: context.texts.titleSmall),
      subtitle: Text(subtitle, style: context.texts.bodySmall),
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
      NotesSection.pinned => (
          Symbols.push_pin,
          'Nothing pinned',
          'Pin a note from its card or editor to keep it at the top.',
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
