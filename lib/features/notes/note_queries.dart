/// Cached database watches for the notes UI.
///
/// Every one of these used to be built inline inside a widget's `build` and
/// handed straight to a `StreamBuilder`. That returns a *new* stream object each
/// time the widget rebuilds, and `StreamBuilder` cancels and resubscribes
/// whenever the stream identity changes — so simply hovering a card tore down and
/// re-ran its queries, and a wall of N cards kept 2N subscriptions churning
/// against SQLite for no reason.
///
/// Behind a provider the stream is created once per key and shared by every
/// watcher, so a rebuild reads the last value instead of re-querying. `family`
/// keys the cache; `autoDispose` releases a query once its card scrolls out of
/// the lazy grid or the section is left.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import 'notes_section.dart';

/// Labels attached to one note.
final noteLabelsProvider = StreamProvider.autoDispose
    .family<List<Label>, String>(
      (ref, noteId) => ref.watch(labelsDaoProvider).watchForNote(noteId),
    );

/// Checklist items belonging to one note, across all its blocks.
final noteChecklistProvider = StreamProvider.autoDispose
    .family<List<ChecklistItem>, String>(
      (ref, noteId) => ref.watch(notesDaoProvider).watchChecklistItems(noteId),
    );

/// Identifies one wall of notes. A record, so Riverpod's family cache compares
/// it structurally and `(notes, null)` asked for twice is one subscription.
typedef NotesQuery = ({NotesSection section, String? labelId});

/// The notes for one section.
final sectionNotesProvider = StreamProvider.autoDispose
    .family<List<Note>, NotesQuery>((ref, query) {
      final dao = ref.watch(notesDaoProvider);
      return switch (query.section) {
        NotesSection.notes => dao.watchActive(),
        NotesSection.archive => dao.watchArchived(),
        NotesSection.trash => dao.watchTrashed(),
        NotesSection.reminders => dao.watchReminders(),
        NotesSection.label => dao.watchByLabel(query.labelId!),
      };
    });
