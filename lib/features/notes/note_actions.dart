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

  static Future<void> setArchived(WidgetRef ref, String id, bool archived) async {
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
    await ref.read(notesDaoProvider).updateNote(id, color: key);
    unawaited(_save(ref));
  }

  static Future<void> setReminder(
      WidgetRef ref, String id, String title, DateTime? when) async {
    final dao = ref.read(notesDaoProvider);
    await dao.updateNote(id, reminderAt: when);
    if (when != null) {
      await ReminderService.scheduleForNote(
          noteId: id, title: title, when: when);
    } else {
      await ReminderService.cancelForNote(id);
    }
    unawaited(_save(ref));
  }
}