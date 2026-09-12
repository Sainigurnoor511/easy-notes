import 'package:easy_notes/features/notes/note_selection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  NoteSelection sel() => container.read(noteSelectionProvider.notifier);
  Set<String> state() => container.read(noteSelectionProvider);
  bool active() => container.read(selectionActiveProvider);

  test('starts empty and inactive', () {
    expect(state(), isEmpty);
    expect(active(), isFalse);
  });

  test('selecting one note activates selection mode', () {
    sel().select('a');
    expect(state(), {'a'});
    expect(active(), isTrue);
  });

  test('select is idempotent', () {
    sel()
      ..select('a')
      ..select('a')
      ..select('a');
    expect(state(), {'a'});
  });

  test('toggle adds then removes', () {
    sel().toggle('a');
    expect(state(), {'a'});
    sel().toggle('a');
    expect(state(), isEmpty);
  });

  test('deselecting the last note leaves selection mode', () {
    sel()
      ..select('a')
      ..select('b');
    expect(active(), isTrue);
    sel()
      ..toggle('a')
      ..toggle('b');
    expect(active(), isFalse,
        reason: 'mode is derived from the set, so it cannot get stuck on');
  });

  test('clear empties everything', () {
    sel()
      ..select('a')
      ..select('b')
      ..select('c');
    sel().clear();
    expect(state(), isEmpty);
    expect(active(), isFalse);
  });

  test('clear on an empty selection is a no-op and keeps identity', () {
    final before = state();
    sel().clear();
    expect(state(), same(before), reason: 'no needless rebuild');
  });

  test('selectAll replaces the current selection', () {
    sel().select('old');
    sel().selectAll(['x', 'y', 'z']);
    expect(state(), {'x', 'y', 'z'});
  });

  test('contains reports membership', () {
    sel().select('a');
    expect(sel().contains('a'), isTrue);
    expect(sel().contains('b'), isFalse);
  });

  test('state is replaced, not mutated in place', () {
    sel().select('a');
    final first = state();
    sel().select('b');
    expect(state(), isNot(same(first)),
        reason: 'Riverpod needs a new instance to notify listeners');
    expect(first, {'a'}, reason: 'the old set must not be mutated');
  });

  test('a listener is notified on each real change', () {
    final seen = <int>[];
    container.listen<Set<String>>(
      noteSelectionProvider,
      (_, next) => seen.add(next.length),
      fireImmediately: false,
    );
    sel()
      ..select('a')
      ..select('b')
      ..toggle('b')
      ..clear();
    expect(seen, [1, 2, 1, 0]);
  });
}
