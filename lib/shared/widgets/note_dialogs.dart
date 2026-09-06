import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/design_tokens.dart';
import '../../app/spacing.dart';
import '../../core/app_providers.dart';
import '../../core/database/database_providers.dart';
import '../models/note_models.dart';
import 'app_widgets.dart';

/// Shared dialogs for note colour, labels, reminders and destructive confirms.
///
/// All of them sit on `surface` with `lg` corners and 24px padding, and they all
/// keep Cancel as a plain text button on the left.

/// A radial-style popover of the nine calibrated swatches. Each swatch shows the
/// tone it will actually paint in the current scheme, so dark mode previews
/// dark-mode tints.
Future<void> showNoteColorDialog(
  BuildContext context,
  String? current,
  void Function(String? key) onSelected,
) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final palette = context.palette;
      final brightness = Theme.of(context).brightness;
      final selectedKey = current ?? 'default';

      return AlertDialog(
        title: const Text('Note colour'),
        contentPadding: const EdgeInsets.fromLTRB(
            Spacing.xl, Spacing.sm, Spacing.xl, Spacing.sm),
        content: SizedBox(
          width: 296,
          child: Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.md,
            children: [
              for (final tone in kNoteColors)
                _Swatch(
                  tone: tone,
                  fill: tone.surfaceFor(brightness) ?? palette.surface,
                  edge: tone.borderFor(brightness) ?? palette.borderStrong,
                  selected: selectedKey == tone.key,
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(tone.isDefault ? null : tone.key);
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      );
    },
  );
}

class _Swatch extends StatelessWidget {
  final NoteColor tone;
  final Color fill;
  final Color edge;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({
    required this.tone,
    required this.fill,
    required this.edge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: tone.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: tone.label,
        child: InkWell(
          borderRadius: AppRadii.all(AppRadii.full),
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? palette.primary : edge,
                width: selected ? 2 : 1,
              ),
            ),
            child: selected
                ? Icon(Symbols.check,
                    size: 18, color: palette.textPrimary)
                : tone.isDefault
                    ? Icon(Symbols.format_color_reset,
                        size: 16, color: palette.textTertiary)
                    : null,
          ),
        ),
      ),
    );
  }
}

/// Label picker. Selection state lives outside the builder so toggles persist
/// across rebuilds.
Future<void> showLabelPickerDialog(
  BuildContext context,
  WidgetRef ref,
  String noteId,
) async {
  final labelsDao = ref.read(labelsDaoProvider);
  final all = await labelsDao.getAll();
  final current = await labelsDao.forNote(noteId);
  final currentIds = current.map((l) => l.id).toSet();
  if (!context.mounted) return;

  final selected = {...currentIds};

  final result = await showDialog<Set<String>>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Labels'),
      contentPadding: const EdgeInsets.fromLTRB(
          Spacing.sm, Spacing.sm, Spacing.sm, Spacing.sm),
      content: SizedBox(
        width: 320,
        child: all.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Text(
                  'No labels yet. Create them on the Labels screen, then apply '
                  'them here.',
                  style: context.texts.bodyMedium
                      ?.copyWith(color: context.palette.textSecondary),
                ),
              )
            : StatefulBuilder(
                builder: (context, setState) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final label in all)
                      CheckboxListTile(
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: Spacing.sm),
                        shape: AppRadii.shape(AppRadii.base),
                        title: Text('#${label.name}', style: context.mono),
                        value: selected.contains(label.id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            selected.add(label.id);
                          } else {
                            selected.remove(label.id);
                          }
                        }),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, selected),
          child: const Text('Done'),
        ),
      ],
    ),
  );

  if (result == null) return;
  for (final label in all) {
    if (result.contains(label.id) && !currentIds.contains(label.id)) {
      await labelsDao.addToNote(noteId, label.id);
    } else if (!result.contains(label.id) && currentIds.contains(label.id)) {
      await labelsDao.removeFromNote(noteId, label.id);
    }
  }
  unawaited(ref.read(syncControllerProvider.notifier).syncNow());
}

/// Reminder picker. [current] is the existing reminder (nullable).
Future<void> showReminderDialog(
  BuildContext context,
  WidgetRef ref,
  String noteId, {
  DateTime? current,
  required Future<void> Function(DateTime?) onSet,
}) async {
  final now = DateTime.now();
  final laterToday = DateTime(now.year, now.month, now.day, 20);
  final tomorrow = DateTime(now.year, now.month, now.day)
      .add(const Duration(days: 1, hours: 9));
  final nextWeek = DateTime(now.year, now.month, now.day)
      .add(const Duration(days: 7, hours: 9));

  final action = await showDialog<String>(
    context: context,
    builder: (context) {
      final palette = context.palette;
      return AlertDialog(
        title: const Text('Remind me'),
        contentPadding: const EdgeInsets.fromLTRB(
            Spacing.sm, Spacing.sm, Spacing.sm, Spacing.sm),
        content: SizedBox(
          width: 336,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (current != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Spacing.md, 0, Spacing.md, Spacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Currently set',
                          style: context.texts.labelMedium
                              ?.copyWith(color: palette.textSecondary),
                        ),
                      ),
                      StatusPill(
                        label: DateFormat('EEE d MMM, h:mm a').format(current),
                        background: palette.primaryWash,
                        foreground: palette.onPrimaryWash,
                        icon: Symbols.alarm_on,
                      ),
                    ],
                  ),
                ),
              if (laterToday.isAfter(now))
                _ReminderOption(
                  icon: Symbols.wb_twilight,
                  title: 'Later today',
                  subtitle: DateFormat.jm().format(laterToday),
                  onTap: () => Navigator.pop(context, 'today'),
                ),
              _ReminderOption(
                icon: Symbols.wb_sunny,
                title: 'Tomorrow morning',
                subtitle: DateFormat.jm().format(tomorrow),
                onTap: () => Navigator.pop(context, 'tomorrow'),
              ),
              _ReminderOption(
                icon: Symbols.next_week,
                title: 'Next week',
                subtitle: DateFormat('EEE d MMM, h:mm a').format(nextWeek),
                onTap: () => Navigator.pop(context, 'week'),
              ),
              _ReminderOption(
                icon: Symbols.calendar_month,
                title: 'Pick date and time',
                subtitle: 'Choose exactly when',
                onTap: () => Navigator.pop(context, 'custom'),
              ),
              if (current != null)
                _ReminderOption(
                  icon: Symbols.alarm_off,
                  title: 'Remove reminder',
                  subtitle: 'Keep the note, drop the alarm',
                  color: palette.error,
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );

  DateTime? selected;
  switch (action) {
    case 'remove':
      selected = null;
    case 'today':
      selected = laterToday;
    case 'tomorrow':
      selected = tomorrow;
    case 'week':
      selected = nextWeek;
    case 'custom':
      if (!context.mounted) return;
      final date = await showDatePicker(
        context: context,
        initialDate: current ?? now,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365 * 5)),
      );
      if (date == null) return;
      if (!context.mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current ?? now),
      );
      if (time == null) return;
      selected =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    default:
      return;
  }

  await onSet(selected);
  unawaited(ref.read(syncControllerProvider.notifier).syncNow());
}

class _ReminderOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;
  final VoidCallback? onTap;

  const _ReminderOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      leading: Icon(icon, size: 19, color: color ?? palette.textSecondary),
      title: Text(
        title,
        style: context.texts.titleSmall
            ?.copyWith(color: color ?? palette.textPrimary),
      ),
      subtitle: Text(subtitle, style: context.texts.bodySmall),
    );
  }
}

/// The one place the error color fills a button: the confirming press inside a
/// dialog. Cancel stays a plain text button on the left.
Future<bool> showDangerConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      final palette = context.palette;
      return AlertDialog(
        icon: Icon(Symbols.error, color: palette.error, size: 26),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: palette.error,
              foregroundColor: palette.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return ok ?? false;
}

/// Rename / create prompt used by the labels screen.
Future<String?> showTextPromptDialog(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
  String confirmLabel = 'Save',
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: label),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  controller.dispose();
  final trimmed = result?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
