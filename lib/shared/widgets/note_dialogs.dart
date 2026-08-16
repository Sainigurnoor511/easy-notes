import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_providers.dart';
import '../../core/database/database_providers.dart';
import '../models/note_models.dart';

/// Shared dialogs for note color, labels and reminders.

Future<void> showNoteColorDialog(
  BuildContext context,
  String? current,
  void Function(String? key) onSelected,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Note color'),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in kNoteColors)
            Tooltip(
              message: c.label,
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  onSelected(c.key == 'default' ? null : c.key);
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.background ?? Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    border: current == c.key
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3)
                        : null,
                  ),
                  child: current == c.key
                      ? const Icon(Icons.check, size: 18)
                      : null,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

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

  final result = await showDialog<Set<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final selected = {...currentIds};
        return AlertDialog(
          title: const Text('Labels'),
          content: SizedBox(
            width: 320,
            child: all.isEmpty
                ? const Text('No labels yet. Create them in Labels.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final label in all)
                        CheckboxListTile(
                          dense: true,
                          title: Text(label.name),
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
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, selected),
                child: const Text('Done')),
          ],
        );
      },
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

/// Reminder dialog. [current] is the existing reminder (nullable).
Future<void> showReminderDialog(
  BuildContext context,
  WidgetRef ref,
  String noteId, {
  DateTime? current,
  required Future<void> Function(DateTime?) onSet,
}) async {
  final now = DateTime.now();
  final today8 = DateTime(now.year, now.month, now.day, 20);
  final tomorrow9 = DateTime(now.year, now.month, now.day).add(const Duration(days: 1, hours: 9));

  final action = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Reminder'),
      children: [
        if (current != null)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'remove'),
            child: const Text('Remove reminder'),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'today'),
          child: Text('Today ${DateFormat.jm().format(today8)}'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'tomorrow'),
          child: Text('Tomorrow ${DateFormat.jm().format(tomorrow9)}'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'custom'),
          child: const Text('Custom date/time'),
        ),
      ],
    ),
  );

  DateTime? selected;
  switch (action) {
    case 'remove':
      selected = null;
    case 'today':
      selected = today8;
    case 'tomorrow':
      selected = tomorrow9;
    case 'custom':
      if (!context.mounted) return;
      final date = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365 * 5)),
      );
      if (date == null) return;
      if (!context.mounted) return;
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time == null) return;
      selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    default:
      return;
  }

  await onSet(selected);
  unawaited(ref.read(syncControllerProvider.notifier).syncNow());
}