import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/design_tokens.dart';
import '../../app/router.dart';
import '../../app/spacing.dart';
import '../../core/database/app_database.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/note_dialogs.dart';
import '../../shared/widgets/note_surface.dart';
import 'note_actions.dart';
import 'note_queries.dart';
import 'note_selection.dart';
import 'notes_section.dart';

/// One card on the canvas.
///
/// Solid pastel surface with its paired border, Level 1 at rest, lifting `-2px`
/// to Level 2 on hover. The card is content first: nothing but the note itself
/// shows at rest. The pin sits absolute at the top right, the selection check
/// overhangs the top left, and the action toolbar reveals along the bottom
/// perimeter on hover.
class NoteCard extends ConsumerWidget {
  final Note note;
  final NotesSection section;

  const NoteCard({super.key, required this.note, required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = NoteSurface.of(context, note.color);
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;

    final labels =
        ref.watch(noteLabelsProvider(note.id)).valueOrNull ?? const <Label>[];

    final selecting = ref.watch(selectionActiveProvider);
    final selected = ref.watch(noteSelectionProvider).contains(note.id);
    final selection = ref.read(noteSelectionProvider.notifier);
    final palette = context.palette;

    // Isolated so the hover lift and the selection ring repaint the card alone
    // instead of the masonry column behind it.
    return RepaintBoundary(
      child: HoverLift(
        enabled: wide,
        builder: (context, hovering) {
          // The toolbar is a pointer affordance. On touch a long press opens
          // the selection bar, which carries the same actions for one note or
          // twenty, so putting six buttons on every card would only cost
          // reading room.
          final showActions = wide && hovering && !selecting;
          // The pin outlives a selection: it is the one control that stays
          // live while the rest of the card becomes a checkbox.
          final showPin = note.isPinned || !wide || hovering;
          final showCheck = selecting || (wide && hovering);

          return AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            decoration: BoxDecoration(
              color: surface.background,
              borderRadius: AppRadii.all(AppRadii.md),
              border: Border.all(color: surface.border),
              boxShadow:
                  hovering
                      ? AppShadows.e2(context.palette)
                      : AppShadows.e1(context.palette),
            ),
            // The selection ring goes in front so it costs no layout. A
            // thicker `border` would inset the child by another pixel and
            // jitter the whole masonry wall on every toggle.
            foregroundDecoration:
                selected
                    ? BoxDecoration(
                      borderRadius: AppRadii.all(AppRadii.md),
                      border: Border.all(color: palette.textPrimary, width: 2),
                    )
                    : null,
            child: Material(
              type: MaterialType.transparency,
              // The check paints past the card's top-left corner.
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  InkWell(
                    borderRadius: AppRadii.all(AppRadii.md),
                    // Long-press starts a selection; once one is running a
                    // plain tap toggles instead of opening the note.
                    onLongPress: () => selection.select(note.id),
                    onTap:
                        () =>
                            selecting
                                ? selection.toggle(note.id)
                                : context.push('/editor/${note.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (note.title.trim().isNotEmpty)
                            Padding(
                              // Clears the absolute pin above.
                              padding: const EdgeInsets.only(
                                right: Spacing.lg,
                                bottom: Spacing.sm,
                              ),
                              child: Text(
                                note.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.headlineSmall?.copyWith(
                                  color: surface.foreground,
                                ),
                              ),
                            ),
                          _CardBody(
                            note: note,
                            surface: surface,
                            hasTitle: note.title.trim().isNotEmpty,
                          ),
                          if (note.reminderAt != null || labels.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: Spacing.md),
                              child: Wrap(
                                spacing: Spacing.sm - 2,
                                runSpacing: Spacing.sm - 2,
                                children: [
                                  if (note.reminderAt != null)
                                    ReminderChip(when: note.reminderAt!),
                                  for (final label in labels)
                                    TagChip(
                                      label: '#${label.name}',
                                      background: surface.chipBackground,
                                      foreground: surface.mutedForeground,
                                    ),
                                ],
                              ),
                            ),
                          if (section.isTrash)
                            // Faded rather than removed: a selection must not
                            // change the card's height, and a live "Restore"
                            // button would be a hole in a card that is
                            // otherwise entirely a checkbox.
                            AnimatedOpacity(
                              opacity: selecting ? 0 : 1,
                              duration: AppMotion.fast,
                              child: IgnorePointer(
                                ignoring: selecting,
                                child: _TrashActions(
                                  note: note,
                                  surface: surface,
                                ),
                              ),
                            )
                          // Reserved whether or not it is showing, so the
                          // masonry wall never reflows under the cursor.
                          else if (wide)
                            Padding(
                              padding: const EdgeInsets.only(top: Spacing.sm),
                              child: AnimatedOpacity(
                                opacity: showActions ? 1 : 0,
                                duration: AppMotion.fast,
                                child: IgnorePointer(
                                  ignoring: !showActions,
                                  child: _ActionToolbar(
                                    note: note,
                                    section: section,
                                    surface: surface,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: Spacing.xs,
                    right: Spacing.xs,
                    child: AnimatedOpacity(
                      opacity: showPin ? 1 : 0,
                      duration: AppMotion.fast,
                      child: IgnorePointer(
                        ignoring: !showPin,
                        child: GhostIconButton(
                          icon: Symbols.push_pin,
                          fill: note.isPinned ? 1 : 0,
                          tooltip: note.isPinned ? 'Unpin' : 'Pin',
                          iconSize: 16,
                          target: 30,
                          color:
                              note.isPinned
                                  ? palette.primary
                                  : surface.mutedForeground,
                          onPressed:
                              () => NoteActions.setPinned(
                                ref,
                                note.id,
                                !note.isPinned,
                              ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    child: AnimatedOpacity(
                      opacity: showCheck ? 1 : 0,
                      duration: AppMotion.fast,
                      child: IgnorePointer(
                        ignoring: !showCheck,
                        child: _SelectionCheck(
                          selected: selected,
                          onTap: () => selection.toggle(note.id),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The selection check: a filled disc with a white tick, overhanging the card's
/// top-left corner.
///
/// The tappable box stays inside the card while the disc paints outside it.
/// Flutter rejects a hit before it reaches a child painted past its parent's
/// bounds, so an overhanging target would look pressable and never respond —
/// hence `transformHitTests: false`.
class _SelectionCheck extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _SelectionCheck({required this.selected, required this.onTap});

  static const double _target = 30;
  static const double _disc = 24;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Tooltip(
      message: selected ? 'Deselect' : 'Select',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: _target,
          height: _target,
          child: Transform.translate(
            offset: const Offset(-9, -9),
            transformHitTests: false,
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: _disc,
                height: _disc,
                decoration: BoxDecoration(
                  color: selected ? palette.textPrimary : palette.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        selected ? palette.textPrimary : palette.borderStrong,
                  ),
                  boxShadow: AppShadows.e1(palette),
                ),
                child: Icon(
                  Symbols.check,
                  size: 15,
                  fill: 1,
                  color: selected ? palette.surface : palette.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardBody extends ConsumerWidget {
  final Note note;
  final NoteSurface surface;

  /// When there is no title the body is the first thing in the card, so it has
  /// to clear the absolute pin itself.
  final bool hasTitle;

  const _CardBody({
    required this.note,
    required this.surface,
    required this.hasTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Notes no longer have a type, so the preview follows what the note
    // actually holds: a checklist if it has items, otherwise its text.
    final items =
        ref.watch(noteChecklistProvider(note.id)).valueOrNull ??
        const <ChecklistItem>[];

    if (items.isNotEmpty) {
      return _ChecklistPreview(items: items, surface: surface);
    }

    final content = note.content.trim();
    if (content.isEmpty) {
      // Something has to render, or a blank note would be an unreadable sliver
      // on the wall with nothing to tap.
      if (hasTitle) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(right: Spacing.lg),
        child: Text(
          'Empty note',
          style: context.texts.bodyMedium?.copyWith(
            color: surface.mutedForeground,
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(right: hasTitle ? 0 : Spacing.lg),
      child: Text(
        content,
        maxLines: 12,
        overflow: TextOverflow.ellipsis,
        style: context.texts.bodyMedium?.copyWith(color: surface.foreground),
      ),
    );
  }
}

/// Outstanding items, then the completed ones folded behind a count.
///
/// No progress bar: the ticked boxes already say how far along the list is, and
/// a bar on a 150px phone card costs a line of content to repeat it.
class _ChecklistPreview extends StatelessWidget {
  final List<ChecklistItem> items;
  final NoteSurface surface;

  const _ChecklistPreview({required this.items, required this.surface});

  /// A card is a preview, not the list. The editor holds the rest.
  static const int _maxPending = 6;
  static const int _maxDone = 3;

  @override
  Widget build(BuildContext context) {
    final pending = items.where((i) => !i.isCompleted).toList();
    final done = items.where((i) => i.isCompleted).toList();
    final shownPending = pending.take(_maxPending).toList();
    final hiddenPending = pending.length - shownPending.length;
    final shownDone = done.take(_maxDone).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in shownPending) _row(context, item),
        if (hiddenPending > 0)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.xxs),
            child: Text(
              '+$hiddenPending more',
              style: context.mono.copyWith(color: surface.mutedForeground),
            ),
          ),
        if (done.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            child: Divider(height: 1, color: surface.border),
          ),
          Row(
            children: [
              Icon(
                Symbols.expand_more,
                size: 16,
                color: surface.mutedForeground,
              ),
              const SizedBox(width: Spacing.xs),
              Flexible(
                child: Text(
                  done.length == 1
                      ? '1 completed item'
                      : '${done.length} completed items',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelMedium?.copyWith(
                    color: surface.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          for (final item in shownDone) _row(context, item),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, ChecklistItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm - 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MiniCheckbox(checked: item.isCompleted),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              item.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodyMedium?.copyWith(
                color:
                    item.isCompleted
                        ? surface.mutedForeground
                        : surface.foreground,
                decoration:
                    item.isCompleted ? TextDecoration.lineThrough : null,
                decorationColor: surface.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 16px rounded square. Checked applies the indigo fill with a white check.
class _MiniCheckbox extends StatelessWidget {
  final bool checked;

  const _MiniCheckbox({required this.checked});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.only(top: 3),
      decoration: BoxDecoration(
        color: checked ? palette.primary : Colors.transparent,
        borderRadius: AppRadii.all(AppRadii.handle),
        border: Border.all(
          color: checked ? palette.primary : palette.borderStrong,
          width: 1.5,
        ),
      ),
      child:
          checked
              ? Icon(Symbols.check, size: 11, color: palette.onPrimary)
              : null,
    );
  }
}

/// An active reminder, colored by urgency: error wash when overdue, indigo
/// otherwise.
class ReminderChip extends StatelessWidget {
  final DateTime when;

  const ReminderChip({super.key, required this.when});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final overdue = when.isBefore(DateTime.now());
    final background = overdue ? palette.errorWash : palette.primaryWash;
    final foreground = overdue ? palette.onErrorWash : palette.onPrimaryWash;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.all(AppRadii.full),
        border: Border.all(color: foreground.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            overdue ? Symbols.alarm_on : Symbols.alarm,
            size: 12,
            color: foreground,
          ),
          const SizedBox(width: Spacing.xs + 1),
          Text(_format(when), style: context.mono.copyWith(color: foreground)),
        ],
      ),
    );
  }

  String _format(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(when.year, when.month, when.day);
    final delta = day.difference(today).inDays;
    final time = DateFormat.jm().format(when);
    if (delta == 0) return 'Today, $time';
    if (delta == 1) return 'Tomorrow, $time';
    if (delta == -1) return 'Yesterday, $time';
    return '${DateFormat.MMMd().format(when)}, $time';
  }
}

/// Trash is the one section whose actions cannot hide behind a hover: a trashed
/// note has exactly two futures and both need naming.
class _TrashActions extends ConsumerWidget {
  final Note note;
  final NoteSurface surface;

  const _TrashActions({required this.note, required this.surface});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm),
      child: Row(
        children: [
          TextButton(
            onPressed: () => NoteActions.restore(ref, note.id),
            child: const Text('Restore'),
          ),
          const Spacer(),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.palette.error),
            onPressed: () => _confirmDelete(context, ref),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDangerConfirmDialog(
      context,
      title: 'Delete forever?',
      message: 'This note and its attachments will be removed permanently.',
      confirmLabel: 'Delete forever',
    );
    if (ok) await NoteActions.deleteForever(ref, note.id);
  }
}

class _ActionToolbar extends ConsumerWidget {
  final Note note;
  final NotesSection section;
  final NoteSurface surface;

  const _ActionToolbar({
    required this.note,
    required this.section,
    required this.surface,
  });

  /// One 32px slot per button.
  static const double _slot = 32;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = surface.mutedForeground;

    final actions = <_CardAction>[
      _CardAction(
        Symbols.palette,
        'Change colour',
        () => showNoteColorDialog(
          context,
          note.color,
          (key) => NoteActions.setColor(ref, note.id, key),
        ),
      ),
      _CardAction(
        Symbols.notifications,
        'Reminder',
        () => showReminderDialog(
          context,
          ref,
          note.id,
          current: note.reminderAt,
          onSet:
              (when) => NoteActions.setReminder(ref, note.id, note.title, when),
        ),
      ),
      _CardAction(
        Symbols.sell,
        'Labels',
        () => showLabelPickerDialog(context, ref, note.id),
      ),
      _CardAction(
        section.isArchive ? Symbols.unarchive : Symbols.inventory_2,
        section.isArchive ? 'Unarchive' : 'Archive',
        () => NoteActions.setArchived(ref, note.id, !section.isArchive),
      ),
    ];

    // Only as many buttons as actually fit; the rest fall into the overflow
    // menu. A narrow card holds three slots, and a fixed row of five would
    // overflow it.
    return LayoutBuilder(
      builder: (context, constraints) {
        final slots = ((constraints.maxWidth - _slot) / _slot).floor().clamp(
          0,
          actions.length,
        );
        final visible = actions.take(slots).toList();
        final hidden = actions.skip(slots).toList();

        return Row(
          children: [
            for (final action in visible)
              GhostIconButton(
                icon: action.icon,
                tooltip: action.label,
                color: color,
                iconSize: 17,
                target: _slot,
                onPressed: action.onPressed,
              ),
            const Spacer(),
            _MoreMenu(note: note, color: color, extra: hidden),
          ],
        );
      },
    );
  }
}

/// A card action that can render either as a toolbar button or a menu row.
class _CardAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _CardAction(this.icon, this.label, this.onPressed);
}

class _MoreMenu extends ConsumerWidget {
  final Note note;
  final Color color;

  /// Actions that didn't fit in the toolbar, shown above the standard rows.
  final List<_CardAction> extra;

  const _MoreMenu({
    required this.note,
    required this.color,
    this.extra = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<String>(
        tooltip: 'More',
        padding: EdgeInsets.zero,
        iconSize: 17,
        position: PopupMenuPosition.under,
        icon: Icon(Symbols.more_horiz, color: color),
        onSelected: (value) => _handle(ref, value),
        itemBuilder:
            (context) => [
              for (var i = 0; i < extra.length; i++)
                PopupMenuItem(
                  value: 'extra$i',
                  child: Row(
                    children: [
                      Icon(
                        extra[i].icon,
                        size: 18,
                        color: palette.textSecondary,
                      ),
                      const SizedBox(width: Spacing.md),
                      Text(extra[i].label),
                    ],
                  ),
                ),
              if (extra.isNotEmpty) const PopupMenuDivider(height: 1),
              const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Move to trash',
                  style: TextStyle(color: palette.error),
                ),
              ),
            ],
      ),
    );
  }

  Future<void> _handle(WidgetRef ref, String value) async {
    if (value.startsWith('extra')) {
      final index = int.tryParse(value.substring(5));
      if (index != null && index < extra.length) extra[index].onPressed();
      return;
    }
    switch (value) {
      case 'duplicate':
        await NoteActions.duplicate(ref, note.id);
      case 'delete':
        await NoteActions.trash(ref, note.id);
    }
  }
}
