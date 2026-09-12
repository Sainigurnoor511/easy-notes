import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../core/database/database_providers.dart';
import '../../features/reminders/reminder_service.dart';

/// Note operations: writes SQLite first, then kicks off async sync.
class NoteActions {
  static Future<void> _save(WidgetRef ref) {
    return ref.read(syncControllerProvider.notifier).syncNow();
  }

  static Future<void> setPinned(WidgetRef ref, String id, bool pinned) async {
    await ref.read(notesDaoProvider).setPinned(id, pinned);
    unawaited(_save(ref));
  }

  static Future<void> setArchived(
    WidgetRef ref,
    String id,
    bool archived,
  ) async {
    await ref.read(notesDaoProvider).setArchived(id, archived);
    unawaited(_save(ref));
  }

  static Future<void> trash(WidgetRef ref, String id) async {
    await ref.read(notesDaoProvider).trash(id);
    await ReminderService.cancelForNote(id);
    unawaited(_save(ref));
  }

  static Future<void> restore(WidgetRef ref, String id) async {
    await ref.read(notesDaoProvider).restore(id);
    unawaited(_save(ref));
  }

  static Future<void> deleteForever(WidgetRef ref, String id) async {
    await ref.read(attachmentStorageProvider).deleteNoteFiles(id);
    await ref.read(notesDaoProvider).permanentlyDelete(id);
    await ReminderService.cancelForNote(id);
    unawaited(_save(ref));
  }

  static Future<void> duplicate(WidgetRef ref, String id) async {
    await ref.read(notesDaoProvider).duplicate(id);
    unawaited(_save(ref));
  }

  static Future<void> setColor(WidgetRef ref, String id, String? key) async {
    await ref.read(notesDaoProvider).setColor(id, key);
    unawaited(_save(ref));
  }

  // ---------------------------------------------------------------------------
  // Bulk actions, for the selection bar.
  //
  // Each writes every note first and syncs once at the end, rather than firing a
  // sync per note.
  // ---------------------------------------------------------------------------

  static Future<void> setPinnedAll(
    WidgetRef ref,
    Iterable<String> ids,
    bool pinned,
  ) async {
    final dao = ref.read(notesDaoProvider);
    for (final id in ids) {
      await dao.setPinned(id, pinned);
    }
    unawaited(_save(ref));
  }

  static Future<void> setArchivedAll(
    WidgetRef ref,
    Iterable<String> ids,
    bool archived,
  ) async {
    final dao = ref.read(notesDaoProvider);
    for (final id in ids) {
      await dao.setArchived(id, archived);
    }
    unawaited(_save(ref));
  }

  static Future<void> setColorAll(
    WidgetRef ref,
    Iterable<String> ids,
    String? key,
  ) async {
    final dao = ref.read(notesDaoProvider);
    for (final id in ids) {
      await dao.setColor(id, key);
    }
    unawaited(_save(ref));
  }

  static Future<void> trashAll(WidgetRef ref, Iterable<String> ids) async {
    final dao = ref.read(notesDaoProvider);
    for (final id in ids) {
      await dao.trash(id);
      await ReminderService.cancelForNote(id);
    }
    unawaited(_save(ref));
  }

  static Future<void> restoreAll(WidgetRef ref, Iterable<String> ids) async {
    final dao = ref.read(notesDaoProvider);
    for (final id in ids) {
      await dao.restore(id);
    }
    unawaited(_save(ref));
  }

  static Future<void> deleteForeverAll(
    WidgetRef ref,
    Iterable<String> ids,
  ) async {
    final dao = ref.read(notesDaoProvider);
    final storage = ref.read(attachmentStorageProvider);
    for (final id in ids) {
      await storage.deleteNoteFiles(id);
      await dao.permanentlyDelete(id);
      await ReminderService.cancelForNote(id);
    }
    unawaited(_save(ref));
  }

  static Future<void> setReminderAll(
    WidgetRef ref,
    Iterable<String> ids,
    DateTime? when,
  ) async {
    final dao = ref.read(notesDaoProvider);
    for (final id in ids) {
      final note = await dao.getById(id);
      await dao.updateNote(id, reminderAt: when, clearReminder: when == null);
      if (when != null) {
        await ReminderService.scheduleForNote(
          noteId: id,
          title: note?.title ?? '',
          when: when,
        );
      } else {
        await ReminderService.cancelForNote(id);
      }
    }
    unawaited(_save(ref));
  }

  static Future<void> setReminder(
    WidgetRef ref,
    String id,
    String title,
    DateTime? when,
  ) async {
    final dao = ref.read(notesDaoProvider);
    // `clearReminder` is what actually nulls the column — passing
    // `reminderAt: null` alone reads as "leave it alone", so removing a reminder
    // used to cancel the alarm but leave the chip on the card.
    await dao.updateNote(id, reminderAt: when, clearReminder: when == null);
    if (when != null) {
      await ReminderService.scheduleForNote(
        noteId: id,
        title: title,
        when: when,
      );
    } else {
      await ReminderService.cancelForNote(id);
    }
    unawaited(_save(ref));
  }
}
