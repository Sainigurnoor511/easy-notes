import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';

/// Masonry (`true`) or list (`false`).
///
/// Shared rather than local to the notes screen: on phones the toggle lives in
/// the top bar's search pill, on desktop it sits in the page header, and both
/// must drive the same persisted preference.
class ViewModeController extends AsyncNotifier<bool> {
  static const _key = 'view_mode';

  @override
  Future<bool> build() async {
    final value = await ref.watch(settingsDaoProvider).get(_key);
    return value != 'list';
  }

  Future<void> set(bool grid) async {
    state = AsyncData(grid);
    await ref.read(settingsDaoProvider).set(_key, grid ? 'grid' : 'list');
  }

  Future<void> toggle() => set(!(state.valueOrNull ?? true));
}

final viewModeProvider =
    AsyncNotifierProvider<ViewModeController, bool>(ViewModeController.new);
