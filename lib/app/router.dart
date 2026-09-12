import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_providers.dart';
import '../core/database/app_database.dart';
import '../core/database/database_providers.dart';
import '../core/sync/sync_status.dart';
import '../features/labels/labels_screen.dart';
import '../features/notes/note_editor_screen.dart';
import '../features/notes/note_actions.dart';
import '../features/notes/note_selection.dart';
import '../features/notes/notes_screen.dart';
import '../features/notes/notes_section.dart';
import '../features/notes/view_mode.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../shared/models/auth_user.dart';
import '../shared/widgets/app_widgets.dart';
import '../shared/widgets/note_dialogs.dart';
import 'app_logo.dart';
import 'design_tokens.dart';
import 'spacing.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Below this width the navigation drawer collapses into a modal drawer.
const double kWideLayoutBreakpoint = Breakpoints.tablet;

/// The strip every top bar sits on, shared so the three cannot drift apart.
///
/// Level 2 rather than Level 1: the workspace is white end to end, so this
/// shadow is the header's only separation from the page and has to carry the
/// whole job. Nothing inside the bar casts its own — a lifted pill on a lifted
/// bar reads as two competing layers and makes the header look attached to the
/// canvas.
BoxDecoration _barDecoration(AppPalette palette) =>
    BoxDecoration(color: palette.surface, boxShadow: AppShadows.e2(palette));

/// Whether the wide-screen drawer shows icon+label or icon-only.
final sidebarExpandedProvider = StateProvider<bool>((ref) => true);

/// Live counts for the navigation rows. Numbers in the UI are always real.
final _navCountsProvider = StreamProvider<_NavCounts>((ref) {
  final dao = ref.watch(notesDaoProvider);
  return dao.watchActive().map(
    (active) => _NavCounts(
      notes: active.length,
      reminders: active.where((n) => n.reminderAt != null).length,
    ),
  );
});

class _NavCounts {
  final int notes;
  final int reminders;

  const _NavCounts({required this.notes, required this.reminders});

  static const empty = _NavCounts(notes: 0, reminders: 0);
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/notes',
    routes: [
      ShellRoute(
        builder:
            (context, state, child) =>
                AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/notes',
            builder:
                (context, state) =>
                    const NotesScreen(section: NotesSection.notes),
          ),

          GoRoute(
            path: '/archive',
            builder:
                (context, state) =>
                    const NotesScreen(section: NotesSection.archive),
          ),
          GoRoute(
            path: '/trash',
            builder:
                (context, state) =>
                    const NotesScreen(section: NotesSection.trash),
          ),
          GoRoute(
            path: '/reminders',
            builder:
                (context, state) =>
                    const NotesScreen(section: NotesSection.reminders),
          ),
          GoRoute(
            path: '/labels',
            // `?new=1` lands with the creator focused, so the drawer's `+` is a
            // create action rather than a second link to the same page.
            builder:
                (context, state) => LabelsScreen(
                  focusCreate: state.uri.queryParameters.containsKey('new'),
                ),
          ),
          GoRoute(
            path: '/label/:id',
            builder:
                (context, state) => NotesScreen(
                  section: NotesSection.label,
                  labelId: state.pathParameters['id'],
                ),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/editor/:noteId',
        builder:
            (context, state) => NoteEditorScreen(
              noteId: state.pathParameters['noteId']!,
              openReminder: state.uri.queryParameters['reminder'] == '1',
            ),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
    ],
  );
});

/// The multi-pane workspace shell: a 56px top bar above a 240px navigation
/// drawer and the canvas.
class AppShell extends ConsumerWidget {
  final String location;
  final Widget child;

  const AppShell({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final expanded = ref.watch(sidebarExpandedProvider);

    final selecting = ref.watch(selectionActiveProvider);

    return PopScope(
      // Back should drop the selection before it leaves the screen — the same
      // thing the X in the selection bar does.
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(noteSelectionProvider.notifier).clear();
      },
      child: Scaffold(
        backgroundColor: palette.surface,
        drawer: wide ? null : const _NavDrawer(inDrawer: true, expanded: true),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const _TopBar(),
              Expanded(
                child: Row(
                  children: [
                    if (wide) _NavDrawer(inDrawer: false, expanded: expanded),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The top bar, in two arrangements.
///
/// On phones it follows the reference's mobile chrome: the bar itself is
/// canvas-coloured with no rule, and a single floating search pill carries the
/// view and sync affordances, with the drawer button outside it on the left and
/// the account avatar outside on the right.
///
/// From tablet up the bar becomes a `surface` strip with a bottom hairline, and
/// the search field is centred in the viewport — the flanking clusters take
/// equal flex, so the field's centre is the screen's centre regardless of how
/// wide either cluster gets.
class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // While notes are selected the bar becomes a toolbar for them.
    if (ref.watch(selectionActiveProvider)) return const SelectionBar();

    final width = MediaQuery.sizeOf(context).width;
    return width < kWideLayoutBreakpoint
        ? const _CompactTopBar()
        : _WideTopBar(width: width);
  }
}

/// The selection toolbar: dismiss, a count, and actions that apply to every
/// selected note at once.
class SelectionBar extends ConsumerWidget {
  const SelectionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final selected = ref.watch(noteSelectionProvider);
    final controller = ref.read(noteSelectionProvider.notifier);
    final location = GoRouterState.of(context).uri.path;
    final inTrash = location == '/trash';
    final inArchive = location == '/archive';
    final ids = selected.toList();

    return Container(
      height: Sizes.topBar,
      decoration: _barDecoration(palette),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Row(
        children: [
          GhostIconButton(
            icon: Symbols.close,
            tooltip: 'Cancel selection',
            color: palette.textPrimary,
            onPressed: controller.clear,
          ),
          const SizedBox(width: Spacing.sm),
          Text('${selected.length}', style: context.texts.headlineMedium),
          const Spacer(),
          if (inTrash) ...[
            GhostIconButton(
              icon: Symbols.restore_from_trash,
              tooltip: 'Restore',
              color: palette.textPrimary,
              onPressed: () async {
                await NoteActions.restoreAll(ref, ids);
                controller.clear();
              },
            ),
            GhostIconButton(
              icon: Symbols.delete_forever,
              tooltip: 'Delete forever',
              color: palette.error,
              onPressed: () async {
                final ok = await showDangerConfirmDialog(
                  context,
                  title:
                      'Delete ${ids.length} '
                      '${ids.length == 1 ? 'note' : 'notes'} forever?',
                  message:
                      'They and their attachments will be removed '
                      'permanently.',
                  confirmLabel: 'Delete forever',
                );
                if (ok) {
                  await NoteActions.deleteForeverAll(ref, ids);
                  controller.clear();
                }
              },
            ),
          ] else ...[
            GhostIconButton(
              icon: Symbols.push_pin,
              tooltip: 'Pin',
              color: palette.textPrimary,
              onPressed: () async {
                await NoteActions.setPinnedAll(ref, ids, true);
                controller.clear();
              },
            ),
            GhostIconButton(
              icon: Symbols.notifications,
              tooltip: 'Reminder',
              color: palette.textPrimary,
              onPressed:
                  () => showReminderDialog(
                    context,
                    ref,
                    ids.first,
                    onSet: (when) async {
                      await NoteActions.setReminderAll(ref, ids, when);
                      controller.clear();
                    },
                  ),
            ),
            GhostIconButton(
              icon: Symbols.palette,
              tooltip: 'Colour',
              color: palette.textPrimary,
              onPressed:
                  () => showNoteColorDialog(context, null, (key) async {
                    await NoteActions.setColorAll(ref, ids, key);
                    controller.clear();
                  }),
            ),
            GhostIconButton(
              icon: inArchive ? Symbols.unarchive : Symbols.inventory_2,
              tooltip: inArchive ? 'Unarchive' : 'Archive',
              color: palette.textPrimary,
              onPressed: () async {
                await NoteActions.setArchivedAll(ref, ids, !inArchive);
                controller.clear();
              },
            ),
            _SelectionMenu(ids: ids, onDone: controller.clear),
          ],
        ],
      ),
    );
  }
}

class _SelectionMenu extends ConsumerWidget {
  final List<String> ids;
  final VoidCallback onDone;

  const _SelectionMenu({required this.ids, required this.onDone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return SizedBox(
      width: kMinTouchTarget,
      height: kMinTouchTarget,
      child: PopupMenuButton<String>(
        tooltip: 'More',
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        icon: Icon(Symbols.more_vert, color: palette.textPrimary),
        onSelected: (value) async {
          switch (value) {
            case 'unpin':
              await NoteActions.setPinnedAll(ref, ids, false);
            case 'labels':
              // Labels apply per note, so this walks the selection.
              for (final id in ids) {
                if (!context.mounted) return;
                await showLabelPickerDialog(context, ref, id);
              }
            case 'trash':
              await NoteActions.trashAll(ref, ids);
          }
          onDone();
        },
        itemBuilder:
            (context) => [
              const PopupMenuItem(value: 'unpin', child: Text('Unpin')),
              PopupMenuItem(
                value: 'labels',
                child: Text(ids.length == 1 ? 'Labels' : 'Labels, one by one'),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'trash',
                child: Text(
                  'Move to trash',
                  style: TextStyle(color: palette.error),
                ),
              ),
            ],
      ),
    );
  }
}

/// Whether a location renders a wall of note cards, and so has a view mode to
/// switch. `/labels` and `/settings` do not.
bool _showsNotes(String location) =>
    location == '/notes' ||
    location == '/archive' ||
    location == '/trash' ||
    location == '/reminders' ||
    location.startsWith('/label/');

/// The bar's leading identity.
///
/// The notes wall is home, so it gets the mark. Anywhere else the mark would be
/// a third element naming the app while nothing named the page, so the page's
/// name takes the slot. That makes the bar the only place a page is titled — the
/// canvas below carries no banner.
class _BarIdentity extends ConsumerWidget {
  final String location;

  /// Below [Breakpoints.laptop] the wordmark is dropped and the mark stands
  /// alone, so the search field keeps its width.
  final bool showWordmark;

  const _BarIdentity({required this.location, required this.showWordmark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    if (location == '/notes') {
      return Row(
        children: [
          const AppLogo(size: 30),
          if (showWordmark) ...[
            const SizedBox(width: Spacing.sm),
            Flexible(
              child: Text(
                'Easy Notes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.primary,
                ),
              ),
            ),
          ],
        ],
      );
    }

    final style = context.texts.headlineMedium?.copyWith(
      color: palette.textPrimary,
    );

    // A label page is named by its label, and the route carries only an id.
    if (location.startsWith('/label/')) {
      final id = location.substring('/label/'.length);
      return StreamBuilder<List<Label>>(
        stream: ref.watch(labelsDaoProvider).watchAll(),
        builder: (context, snapshot) {
          String? name;
          for (final label in snapshot.data ?? const <Label>[]) {
            if (label.id == id) {
              name = label.name;
              break;
            }
          }
          return Row(
            children: [
              Icon(Symbols.tag, size: 20, color: palette.textSecondary),
              const SizedBox(width: Spacing.xs),
              Flexible(
                child: Text(
                  name ?? 'Label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ],
          );
        },
      );
    }

    final title = switch (location) {
      '/reminders' => 'Reminders',
      '/labels' => 'Labels',
      '/archive' => 'Archive',
      '/trash' => 'Trash',
      '/settings' => 'Settings',
      _ => 'Easy Notes',
    };

    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

class _CompactTopBar extends StatelessWidget {
  const _CompactTopBar();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final location = GoRouterState.of(context).uri.path;
    // The wall gets the pill, because capture and search are what you came for.
    // Every other page gets its name and a plain magnifier, the way Keep's does.
    final onWall = location == '/notes';

    return Container(
      height: Sizes.topBar,
      decoration: _barDecoration(palette),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Row(
        children: [
          Builder(
            builder:
                (context) => GhostIconButton(
                  icon: Symbols.menu,
                  tooltip: 'Navigation',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
          ),
          const SizedBox(width: Spacing.xs),
          if (onWall)
            const Expanded(
              child: _SearchField(
                floating: true,
                hint: 'Search notes',
                trailing: [
                  _ViewModeButton(target: 36),
                  _SyncButton(target: 36),
                ],
              ),
            )
          else ...[
            Expanded(
              child: _BarIdentity(location: location, showWordmark: true),
            ),
            GhostIconButton(
              icon: Symbols.search,
              tooltip: 'Search notes',
              onPressed: () => context.push('/search'),
            ),
            if (_showsNotes(location)) const _ViewModeButton(),
            const _SyncButton(),
          ],
          const SizedBox(width: Spacing.xs),
          const _AccountMenu(),
        ],
      ),
    );
  }
}

class _WideTopBar extends ConsumerWidget {
  final double width;

  const _WideTopBar({required this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    // Narrow enough that the flanking clusters always fit beside it.
    final fieldWidth = math.min(Sizes.search, width * 0.45);

    final location = GoRouterState.of(context).uri.path;

    return Container(
      height: Sizes.topBar,
      decoration: _barDecoration(palette),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                GhostIconButton(
                  icon: Symbols.menu,
                  tooltip: 'Collapse navigation',
                  onPressed: () {
                    final notifier = ref.read(sidebarExpandedProvider.notifier);
                    notifier.state = !notifier.state;
                  },
                ),
                // Clears the collapsed rail, so the identity sits over the
                // canvas rather than straddling the navigation's edge.
                const SizedBox(width: Spacing.lg),
                Flexible(
                  child: _BarIdentity(
                    location: location,
                    showWordmark: width >= Breakpoints.laptop,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: fieldWidth, child: const _SearchField()),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // The view switcher lives here rather than on the canvas: the
                // page no longer has a banner to hang it from.
                if (_showsNotes(location)) const _ViewModeButton(),
                // No status pill: the sync button's own icon and tooltip
                // already report the state, and settings says it in full.
                const _SyncButton(),
                const SizedBox(width: Spacing.xs),
                // Settings is reachable from the navigation drawer and from
                // this menu — never from a third, separate icon.
                const _AccountMenu(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A `full`-rounded sunken field that opens the search screen. It looks like an
/// input because it becomes one; it is a button so focus never lands in a field
/// the user can't type into.
class _SearchField extends StatelessWidget {
  /// `true` on phones: the pill becomes the bar's only chrome, so it sits on
  /// `surface` at Level 1 rather than reading as a sunken input.
  final bool floating;

  final String hint;

  /// Actions rendered inside the pill, at its right edge.
  final List<Widget> trailing;

  const _SearchField({
    this.floating = false,
    this.hint = 'Search notes',
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: 'Search notes',
      child: InkWell(
        borderRadius: AppRadii.all(AppRadii.full),
        onTap: () => context.push('/search'),
        child: Container(
          height: floating ? 48 : kMinTouchTarget,
          padding: EdgeInsets.only(
            left: Spacing.md,
            right: trailing.isEmpty ? Spacing.md : Spacing.xs,
          ),
          // Sunken and flat. The bar it sits in is the thing that lifts off the
          // page; a shadow here too made the pill read as the floating element
          // and left the header looking attached to the canvas behind it.
          decoration: BoxDecoration(
            color: palette.surfaceSunken,
            borderRadius: AppRadii.all(AppRadii.full),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Icon(
                Symbols.search,
                size: floating ? 20 : 18,
                color: palette.textTertiary,
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (floating
                          ? context.texts.bodyMedium
                          : context.texts.bodySmall)
                      ?.copyWith(color: palette.textTertiary),
                ),
              ),
              ...trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Flips masonry / list. The glyph shows the view you'd switch *to*.
class _ViewModeButton extends ConsumerWidget {
  final double target;

  const _ViewModeButton({this.target = kMinTouchTarget});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = ref.watch(viewModeProvider).valueOrNull ?? true;
    return GhostIconButton(
      icon: grid ? Symbols.view_agenda : Symbols.grid_view,
      tooltip: grid ? 'Switch to list view' : 'Switch to masonry view',
      target: target,
      onPressed: () => ref.read(viewModeProvider.notifier).toggle(),
    );
  }
}

/// Sync lives behind one control: a refresh affordance that reports state
/// through its icon rather than adding another element to the bar.
class _SyncButton extends ConsumerWidget {
  final double target;

  const _SyncButton({this.target = kMinTouchTarget});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final sync = ref.watch(syncControllerProvider);

    if (sync.status == SyncStatus.syncing) {
      return Tooltip(
        message: 'Syncing…',
        child: SizedBox(
          width: target,
          height: target,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.textTertiary,
              ),
            ),
          ),
        ),
      );
    }

    final (icon, color, tooltip) = switch (sync.status) {
      SyncStatus.failed => (
        Symbols.cloud_off,
        palette.error,
        'Sync failed — tap to retry',
      ),
      SyncStatus.offline => (
        Symbols.cloud_off,
        palette.textTertiary,
        'Offline — notes stay on this device',
      ),
      SyncStatus.synced => (
        Symbols.refresh,
        palette.textSecondary,
        'Up to date — sync again',
      ),
      _ => (Symbols.refresh, palette.textSecondary, 'Sync now'),
    };

    return GhostIconButton(
      icon: icon,
      tooltip: tooltip,
      color: color,
      target: target,
      onPressed: () => ref.read(syncControllerProvider.notifier).syncNow(),
    );
  }
}

/// The account menu.
///
/// The avatar opens a menu rather than jumping straight to settings: account
/// state, connection actions and the settings link each get their own row, so no
/// two chrome elements lead to the same place.
class _AccountMenu extends ConsumerWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final auth = ref.watch(authControllerProvider).valueOrNull;
    final user = auth?.user;
    final connected = auth?.status == AuthStatus.signedIn;
    final offline = auth?.status == AuthStatus.offline;

    return PopupMenuButton<String>(
      tooltip: user?.email.isNotEmpty == true ? user!.email : 'Account',
      position: PopupMenuPosition.under,
      offset: const Offset(0, Spacing.sm),
      padding: EdgeInsets.zero,
      onSelected: (value) => _handle(context, ref, value),
      itemBuilder:
          (context) => [
            PopupMenuItem(
              enabled: false,
              height: 0,
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.sm,
                Spacing.md,
                Spacing.md,
              ),
              child: _MenuHeader(
                title:
                    user?.name.trim().isNotEmpty == true
                        ? user!.name
                        : 'Local workspace',
                subtitle:
                    user?.email.isNotEmpty == true
                        ? user!.email
                        : 'Notes stay on this device',
                connected: connected,
                offline: offline,
              ),
            ),
            const PopupMenuDivider(height: 1),
            const PopupMenuItem(
              value: 'settings',
              child: _MenuRow(
                icon: Symbols.settings,
                label: 'Workspace settings',
              ),
            ),
            const PopupMenuItem(
              value: 'sync',
              child: _MenuRow(icon: Symbols.sync, label: 'Sync now'),
            ),
            const PopupMenuDivider(height: 1),
            if (connected || offline)
              PopupMenuItem(
                value: 'disconnect',
                child: _MenuRow(
                  icon: Symbols.logout,
                  label: 'Disconnect Drive',
                  color: palette.error,
                ),
              )
            else
              const PopupMenuItem(
                value: 'connect',
                child: _MenuRow(
                  icon: Symbols.login,
                  label: 'Connect Google Drive',
                ),
              ),
          ],
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xs),
        child: _Avatar(user: user, connected: connected),
      ),
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    switch (value) {
      case 'settings':
        context.go('/settings');
      case 'sync':
        await ref.read(syncControllerProvider.notifier).syncNow();
      case 'connect':
        await ref.read(authControllerProvider.notifier).signIn();
      case 'disconnect':
        final ok = await showDangerConfirmDialog(
          context,
          title: 'Disconnect Drive?',
          message:
              'Your notes stay on this device. They stop syncing until '
              'you connect again.',
          confirmLabel: 'Disconnect',
        );
        if (ok) await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}

class _Avatar extends StatelessWidget {
  final AuthUser? user;
  final bool connected;

  const _Avatar({required this.user, required this.connected});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final photoUrl = user?.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final name = user?.name.trim() ?? '';
    final initial = name.isEmpty ? null : name.substring(0, 1).toUpperCase();

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: palette.primaryWash,
        shape: BoxShape.circle,
        border: Border.all(
          color: connected ? palette.primaryFixed : palette.border,
        ),
        image:
            hasPhoto
                ? DecorationImage(
                  image: NetworkImage(photoUrl),
                  fit: BoxFit.cover,
                )
                : null,
      ),
      alignment: Alignment.center,
      child:
          hasPhoto
              ? null
              : initial != null
              ? Text(
                initial,
                style: context.texts.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: palette.onPrimaryWash,
                ),
              )
              : Icon(Symbols.person, size: 17, color: palette.textSecondary),
    );
  }
}

/// Identity block at the top of the account menu.
class _MenuHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool connected;
  final bool offline;

  const _MenuHeader({
    required this.title,
    required this.subtitle,
    required this.connected,
    required this.offline,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.texts.titleSmall,
        ),
        const SizedBox(height: Spacing.xxs),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.mono.copyWith(color: palette.textTertiary),
        ),
        const SizedBox(height: Spacing.sm),
        StatusPill(
          label:
              connected
                  ? 'Drive connected'
                  : offline
                  ? 'Offline · will reconnect'
                  : 'Local only',
          background: palette.surfaceSunken,
          foreground: connected ? palette.success : palette.textSecondary,
          dot: true,
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MenuRow({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = color ?? palette.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? palette.textSecondary),
        const SizedBox(width: Spacing.md),
        Text(label, style: context.texts.bodyMedium?.copyWith(color: tint)),
      ],
    );
  }
}

/// The optical column every navigation glyph sits in.
///
/// A collapsed rail is [Sizes.sidebarCollapsed] wide with an 8px tile margin, so
/// a centred 24px slot puts the glyph 28px from the edge — the same centre as
/// the top bar's drawer toggle, which sits at an 8px gutter inside a 40px
/// target. Expanded rows reach the same 28px with a 16px inset, so toggling the
/// rail slides labels without nudging the icons.
const double _navIconSlot = 28;

/// The 240px navigation drawer, shared by the fixed panel and the modal drawer.
class _NavDrawer extends ConsumerWidget {
  final bool inDrawer;
  final bool expanded;

  const _NavDrawer({required this.inDrawer, required this.expanded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final labelsDao = ref.watch(labelsDaoProvider);
    final location = GoRouterState.of(context).uri.path;
    final counts =
        ref.watch(_navCountsProvider).valueOrNull ?? _NavCounts.empty;
    // Aligns section furniture with the glyph column the rows establish.
    final gutter =
        MediaQuery.sizeOf(context).width < kWideLayoutBreakpoint
            ? Spacing.xxl
            : Spacing.lg;

    return StreamBuilder<List<Label>>(
      stream: labelsDao.watchAll(),
      builder: (context, snapshot) {
        final labels = snapshot.data ?? const <Label>[];

        final nav = ListView(
          // No horizontal inset: selected rows run off the left edge, so the
          // padding lives on the rows themselves.
          padding: const EdgeInsets.only(top: Spacing.md, bottom: Spacing.lg),
          children: [
            _NavTile(
              icon: Symbols.lightbulb,
              label: 'All notes',
              count: counts.notes,
              selected: location == '/notes',
              expanded: expanded,
              onTap: () => _go(context, ref, '/notes'),
            ),

            _NavTile(
              icon: Symbols.notifications,
              label: 'Reminders',
              count: counts.reminders,
              selected: location == '/reminders',
              expanded: expanded,
              onTap: () => _go(context, ref, '/reminders'),
            ),
            // The labels manager belongs with the other destinations, not in
            // the footer: it stays reachable when the rail is collapsed and the
            // label list below is hidden.
            _NavTile(
              icon: Symbols.sell,
              label: 'Labels',
              selected: location == '/labels',
              expanded: expanded,
              onTap: () => _editLabels(context, ref),
            ),
            _NavTile(
              icon: Symbols.inventory_2,
              label: 'Archive',
              selected: location == '/archive',
              expanded: expanded,
              onTap: () => _go(context, ref, '/archive'),
            ),
            _NavTile(
              icon: Symbols.delete,
              label: 'Trash',
              selected: location == '/trash',
              expanded: expanded,
              onTap: () => _go(context, ref, '/trash'),
            ),
            if (expanded) ...[
              const SizedBox(height: Spacing.lg),
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 0, Spacing.sm, Spacing.sm),
                child: Row(
                  children: [
                    const Expanded(child: Eyebrow('Labels')),
                    GhostIconButton(
                      icon: Symbols.add,
                      tooltip: 'New label',
                      iconSize: 16,
                      target: 24,
                      onPressed:
                          () => _editLabels(context, ref, focusCreate: true),
                    ),
                  ],
                ),
              ),
              for (final label in labels)
                _NavTile(
                  icon: Symbols.tag,
                  label: label.name,
                  mono: true,
                  selected: location == '/label/${label.id}',
                  expanded: expanded,
                  onTap: () => _go(context, ref, '/label/${label.id}'),
                ),
              if (labels.isEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, Spacing.sm),
                  child: Text(
                    'No labels yet.',
                    style: context.texts.bodySmall?.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                ),
            ],
          ],
        );

        // Settings lives in the top bar's account menu, so the drawer is purely
        // note destinations — no footer, no cache readout.
        final content = nav;

        if (inDrawer) {
          // Phone drawer: a near-full-width white sheet, the way Keep's is.
          // The cache readout is desktop furniture, so it's dropped here.
          final width = MediaQuery.sizeOf(context).width;
          return Drawer(
            backgroundColor: palette.surface,
            width: math.min(width * 0.85, 360),
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      Spacing.lg,
                      Spacing.lg,
                      Spacing.lg,
                    ),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: palette.border)),
                    ),
                    child: Row(
                      children: [
                        const AppLogo(size: 28),
                        const SizedBox(width: Spacing.md),
                        Text(
                          'Easy Notes',
                          style: context.texts.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: palette.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: nav),
                ],
              ),
            ),
          );
        }

        // White and edgeless. The off-white canvas beside it is the only
        // separation it needs; a grey fill plus a hairline made the navigation
        // read as a separate window rather than part of the page.
        return AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.curve,
          width: expanded ? Sizes.sidebar : Sizes.sidebarCollapsed,
          color: palette.surface,
          child: ClipRect(child: content),
        );
      },
    );
  }

  Future<void> _editLabels(
    BuildContext context,
    WidgetRef ref, {
    bool focusCreate = false,
  }) async {
    final modalContext = _rootNavigatorKey.currentContext ?? context;
    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.pop(context);
      await Future<void>.delayed(Duration.zero);
    }
    ref.read(noteSelectionProvider.notifier).clear();
    if (modalContext.mounted) {
      await showEditLabelsDialog(modalContext, focusCreate: focusCreate);
    }
  }

  void _go(BuildContext context, WidgetRef ref, String path) {
    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
    // A selection belongs to the wall it was made on.
    ref.read(noteSelectionProvider.notifier).clear();
    context.go(path);
  }
}

/// A navigation row, `label-md`. Selected rows take a `primary-wash` fill and
/// the icon's `FILL` axis at 1 — which is how Material Symbols expresses a
/// filled glyph, so there is no second icon name to keep in sync.
///
/// Expanded, the pill runs off the left edge and caps on the right, so the fill
/// reads as a band across the navigation rather than a floating button.
/// Collapsed, there is no label to run toward, so it becomes a disc.
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;
  final int? count;

  /// Label names render in JetBrains Mono, like every other identifier.
  final bool mono;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
    this.count,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = selected ? palette.onPrimaryWash : palette.textSecondary;
    // Touch layouts get Keep-sized rows: taller, more inset, wider pitch.
    final roomy = MediaQuery.sizeOf(context).width < kWideLayoutBreakpoint;

    final labelStyle =
        mono
            ? context.mono.copyWith(
              fontSize: roomy ? 14 : 12,
              color: foreground,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            )
            : (roomy ? context.texts.bodyLarge : context.texts.labelLarge)
                ?.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w500,
                );

    final radius =
        expanded
            ? const BorderRadius.horizontal(
              right: Radius.circular(AppRadii.full),
            )
            : AppRadii.all(AppRadii.full);

    final tile = Container(
      margin:
          expanded
              ? const EdgeInsets.only(right: Spacing.md)
              : const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Material(
        color: selected ? palette.primaryWash : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          hoverColor: palette.surfaceHover,
          child: Container(
            height: roomy ? 54 : 44,
            padding: EdgeInsets.only(
              left: expanded ? (roomy ? Spacing.xxl : Spacing.lg) : 0,
              right: expanded ? Spacing.md : 0,
            ),
            child: Row(
              mainAxisAlignment:
                  expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                // A fixed slot, so a 16px tag glyph and a 24px destination
                // glyph share one optical column — and so that column lands at
                // the same x whether the rail is open or collapsed.
                SizedBox(
                  width: _navIconSlot,
                  child: Center(
                    child: Icon(
                      icon,
                      size: mono ? 22 : _navIconSlot,
                      color: foreground,
                      fill: selected ? 1 : 0,
                    ),
                  ),
                ),
                if (expanded) ...[
                  SizedBox(width: roomy ? Spacing.xxl : Spacing.md),
                  Expanded(
                    child: Text(
                      mono ? '#$label' : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                  ),
                  if (count != null && count! > 0)
                    Text(
                      '$count',
                      style: context.mono.copyWith(
                        fontSize: 11,
                        color: selected ? foreground : palette.textTertiary,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      // Keep runs a 48px row on a 60px pitch in the touch drawer.
      padding: EdgeInsets.only(bottom: roomy ? Spacing.lg : Spacing.xs),
      child: expanded ? tile : Tooltip(message: label, child: tile),
    );
  }
}
