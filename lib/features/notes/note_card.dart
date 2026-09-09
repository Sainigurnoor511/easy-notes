import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/design_tokens.dart';
import '../../app/router.dart';
import '../../app/spacing.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/note_dialogs.dart';
import '../../shared/widgets/note_surface.dart';
import 'note_actions.dart';
import 'notes_section.dart';

/// One card on the canvas.
///
/// Solid pastel surface with its paired border, Level 1 at rest, lifting `-2px`
/// to Level 2 on hover. The pin toggle sits at the top right; the action
/// toolbar reveals along the bottom perimeter on hover and stays visible on
/// touch. A hairline rule separates the body from monospaced footer metadata.
class NoteCard extends ConsumerWidget {
  final Note note;
  final NotesSection section;

  const NoteCard({super.key, required this.note, required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = NoteSurface.of(context, note.color);
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;

    return StreamBuilder<List<Label>>(
      stream: ref.watch(labelsDaoProvider).watchForNote(note.id),
      builder: (context, snapshot) {
        final labels = snapshot.data ?? const <Label>[];

        return HoverLift(
          enabled: wide,
          builder: (context, hovering) {
            final showActions = !wide || hovering;
            return AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              decoration: BoxDecoration(
                color: surface.background,
                borderRadius: AppRadii.all(AppRadii.md),
                border: Border.all(color: surface.border),
                boxShadow: hovering
                    ? AppShadows.e2(context.palette)
                    : AppShadows.e1(context.palette),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: AppRadii.all(AppRadii.md),
                  onTap: () => context.push('/editor/${note.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CardHeader(
                          note: note,
                          surface: surface,
                          showPin: note.isPinned || showActions,
                          onPin: () => NoteActions.setPinned(
                              ref, note.id, !note.isPinned),
                        ),
                        _CardBody(note: note, surface: surface),
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
                        const SizedBox(height: Spacing.md),
                        Divider(height: 1, color: surface.border),
                        _CardFooter(
                          note: note,
                          section: section,
                          surface: surface,
                          showActions: showActions,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CardHeader extends StatelessWidget {
  final Note note;
  final NoteSurface surface;
  final bool showPin;
  final VoidCallback onPin;

  const _CardHeader({
    required this.note,
    required this.surface,
    required this.showPin,
    required this.onPin,
  });

  @override
  Widget build(BuildContext context) {
    final hasTitle = note.title.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: hasTitle
              ? Text(
                  note.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.headlineSmall
                      ?.copyWith(color: surface.foreground),
                )
              : Text(
                  'Untitled note',
                  style: context.texts.headlineSmall?.copyWith(
                    color: surface.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
        const SizedBox(width: Spacing.sm),
        AnimatedOpacity(
          opacity: showPin ? 1 : 0,
          duration: AppMotion.fast,
          child: IgnorePointer(
            ignoring: !showPin,
            child: GhostIconButton(
              icon: Symbols.push_pin,
              fill: note.isPinned ? 1 : 0,
              tooltip: note.isPinned ? 'Unpin' : 'Pin',
              iconSize: 16,
              target: 26,
              color: note.isPinned
                  ? context.palette.primary
                  : surface.mutedForeground,
              onPressed: onPin,
            ),
          ),
        ),
      ],
    );
  }

}

class _CardBody extends ConsumerWidget {
  final Note note;
  final NoteSurface surface;

  const _CardBody({required this.note, required this.surface});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Notes no longer have a type, so the preview follows what the note
    // actually holds: a checklist if it has items, otherwise its text.
    return StreamBuilder<List<ChecklistItem>>(
      stream: ref.watch(notesDaoProvider).watchChecklistItems(note.id),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <ChecklistItem>[];
        if (items.isNotEmpty) {
          return _ChecklistPreview(items: items, surface: surface);
        }
        if (note.content.trim().isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: Spacing.sm),
          child: Text(
            note.content.trim(),
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
            style:
                context.texts.bodyMedium?.copyWith(color: surface.foreground),
          ),
        );
      },
    );
  }
}

/// Progress bar, then up to four items — a long list still reads at a glance
/// without expanding the card.
class _ChecklistPreview extends StatelessWidget {
  final List<ChecklistItem> items;
  final NoteSurface surface;

  const _ChecklistPreview({required this.items, required this.surface});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shown = items.take(4).toList();
    final done = items.where((i) => i.isCompleted).length;

    return Padding(
          padding: const EdgeInsets.only(top: Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Both sides shrink: on a two-column phone wall the card is only
              // ~200px wide, and a rigid value would squeeze the label until it
              // wrapped one letter per line.
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Progress',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.labelMedium
                          ?.copyWith(color: surface.mutedForeground),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    '$done/${items.length}',
                    style: context.mono.copyWith(
                      fontWeight: FontWeight.w500,
                      color: palette.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm - 2),
              ClipRRect(
                borderRadius: AppRadii.all(AppRadii.full),
                child: LinearProgressIndicator(
                  value: items.isEmpty ? 0 : done / items.length,
                  minHeight: 5,
                  backgroundColor: surface.isTinted
                      ? surface.chipBackground
                      : palette.surfaceHover,
                  valueColor: AlwaysStoppedAnimation(palette.primary),
                ),
              ),
              const SizedBox(height: Spacing.md),
              for (final item in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.sm - 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MiniCheckbox(checked: item.isCompleted),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Text(
                          item.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.bodyMedium?.copyWith(
                            color: item.isCompleted
                                ? surface.mutedForeground
                                : surface.foreground,
                            decoration: item.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: surface.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (items.length > shown.length)
                Text(
                  '+${items.length - shown.length} more',
                  style: context.mono.copyWith(color: surface.mutedForeground),
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
      child: checked
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
          Icon(overdue ? Symbols.alarm_on : Symbols.alarm,
              size: 12, color: foreground),
          const SizedBox(width: Spacing.xs + 1),
          Text(
            _format(when),
            style: context.mono.copyWith(color: foreground),
          ),
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

/// The footer: monospaced edit time at rest, action toolbar on hover.
class _CardFooter extends ConsumerWidget {
  final Note note;
  final NotesSection section;
  final NoteSurface surface;
  final bool showActions;

  const _CardFooter({
    required this.note,
    required this.section,
    required this.surface,
    required this.showActions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (section.isTrash) {
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
              style:
                  TextButton.styleFrom(foregroundColor: context.palette.error),
              onPressed: () => _confirmDelete(context, ref),
              child: const Text('Delete forever'),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: Stack(
        children: [
          // Resting state: just the timestamp.
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: showActions ? 0 : 1,
              duration: AppMotion.fast,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _updatedLabel(note.updatedAt),
                  style: context.mono.copyWith(color: surface.mutedForeground),
                ),
              ),
            ),
          ),
          // Hovered state: the toolbar takes the same row, no layout shift.
          Positioned.fill(
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
    );
  }

  String _updatedLabel(DateTime updatedAt) {
    final diff = DateTime.now().difference(updatedAt);
    if (diff.inMinutes < 1) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Updated ${diff.inDays}d ago';
    return 'Updated ${DateFormat.MMMd().format(updatedAt)}';
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
        () => showNoteColorDialog(context, note.color,
            (key) => NoteActions.setColor(ref, note.id, key)),
      ),
      _CardAction(
        Symbols.notifications,
        'Reminder',
        () => showReminderDialog(
          context,
          ref,
          note.id,
          current: note.reminderAt,
          onSet: (when) =>
              NoteActions.setReminder(ref, note.id, note.title, when),
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
    // menu. A two-column phone card is ~130px wide inside its padding, which
    // holds three slots — a fixed row of six would overflow it.
    return LayoutBuilder(
      builder: (context, constraints) {
        final slots =
            ((constraints.maxWidth - _slot) / _slot).floor().clamp(0, actions.length);
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
        itemBuilder: (context) => [
          for (var i = 0; i < extra.length; i++)
            PopupMenuItem(
              value: 'extra$i',
              child: Row(
                children: [
                  Icon(extra[i].icon, size: 18, color: palette.textSecondary),
                  const SizedBox(width: Spacing.md),
                  Text(extra[i].label),
                ],
              ),
            ),
          if (extra.isNotEmpty) const PopupMenuDivider(height: 1),
          const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
          PopupMenuItem(
            value: 'delete',
            child: Text('Move to trash',
                style: TextStyle(color: palette.error)),
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
