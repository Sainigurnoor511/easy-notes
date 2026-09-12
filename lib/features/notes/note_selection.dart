import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The set of note ids currently selected on the wall.
///
/// Selection mode is simply "the set isn't empty" — there is no separate flag to
/// fall out of sync with it. Long-pressing a card starts a selection; tapping
/// while one is active toggles instead of opening the note.
class NoteSelection extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  bool get isActive => state.isNotEmpty;

  bool contains(String id) => state.contains(id);

  void toggle(String id) {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    state = next;
  }

  /// Starts a selection (or adds to one) without removing on a repeat call.
  void select(String id) {
    if (state.contains(id)) return;
    state = {...state, id};
  }

  void selectAll(Iterable<String> ids) => state = {...ids};

  void clear() {
    if (state.isEmpty) return;
    state = const {};
  }
}

final noteSelectionProvider = NotifierProvider<NoteSelection, Set<String>>(
  NoteSelection.new,
);

/// True while the selection app bar should replace the normal one.
final selectionActiveProvider = Provider<bool>(
  (ref) => ref.watch(noteSelectionProvider).isNotEmpty,
);
