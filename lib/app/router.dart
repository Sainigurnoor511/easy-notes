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
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/notes',
            builder: (context, state) =>
                const NotesScreen(section: NotesSection.notes),
          ),

          GoRoute(
            path: '/archive',
            builder: (context, state) =>
                const NotesScreen(section: NotesSection.archive),
          ),
          GoRoute(
            path: '/trash',
            builder: (context, state) =>
                const NotesScreen(section: NotesSection.trash),
          ),
          GoRoute(
            path: '/reminders',
            builder: (context, state) =>
                const NotesScreen(section: NotesSection.reminders),
          ),
          GoRoute(
            path: '/labels',
            // `?new=1` lands with the creator focused, so the drawer's `+` is a
            // create action rather than a second link to the same page.
            builder: (context, state) => LabelsScreen(
              focusCreate: state.uri.queryParameters.containsKey('new'),
            ),
          ),
          GoRoute(
            path: '/label/:id',
            builder: (context, state) => NotesScreen(
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
        builder: (context, state) =>
            NoteEditorScreen(noteId: state.pathParameters['noteId']!),
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

    return Scaffold(
      backgroundColor: palette.canvas,
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
    final width = MediaQuery.sizeOf(context).width;
    return width < kWideLayoutBreakpoint
        ? const _CompactTopBar()
        : _WideTopBar(width: width);
  }
}

class _CompactTopBar extends StatelessWidget {
  const _CompactTopBar();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: Sizes.topBar,
      color: palette.canvas,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Row(
        children: [
          Builder(
            builder: (context) => GhostIconButton(
              icon: Symbols.menu,
              tooltip: 'Navigation',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          const SizedBox(width: Spacing.xs),
          const Expanded(
            child: _SearchField(
              floating: true,
              hint: 'Search notes',
              trailing: [
                _ViewModeButton(target: 36),
                _SyncButton(target: 36),
              ],
            ),
          ),
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

    return Container(
      height: Sizes.topBar,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
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
                const SizedBox(width: Spacing.xs),
                const AppLogo(size: 30),
                if (width >= Breakpoints.laptop) ...[
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
            ),
          ),
          SizedBox(width: fieldWidth, child: const _SearchField()),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
          decoration: BoxDecoration(
            color: floating ? palette.surface : palette.surfaceSunken,
            borderRadius: AppRadii.all(AppRadii.full),
            border: Border.all(color: palette.border),
            boxShadow: floating ? AppShadows.e1(palette) : null,
          ),
          child: Row(
            children: [
              Icon(Symbols.search,
                  size: floating ? 20 : 18, color: palette.textTertiary),
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
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          height: 0,
          padding: const EdgeInsets.fromLTRB(
              Spacing.md, Spacing.sm, Spacing.md, Spacing.md),
          child: _MenuHeader(
            title: user?.name.trim().isNotEmpty == true
                ? user!.name
                : 'Local workspace',
            subtitle: user?.email.isNotEmpty == true
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
              icon: Symbols.settings, label: 'Workspace settings'),
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
      BuildContext context, WidgetRef ref, String value) async {
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
          message: 'Your notes stay on this device. They stop syncing until '
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
        image: hasPhoto
            ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasPhoto
          ? null
          : initial != null
              ? Text(
                  initial,
                  style: context.texts.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: palette.onPrimaryWash,
                  ),
                )
              : Icon(Symbols.person,
                  size: 17, color: palette.textSecondary),
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
          label: connected
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

    return StreamBuilder<List<Label>>(
      stream: labelsDao.watchAll(),
      builder: (context, snapshot) {
        final labels = snapshot.data ?? const <Label>[];

        final nav = ListView(
          padding: const EdgeInsets.fromLTRB(
              Spacing.sm, Spacing.md, Spacing.sm, Spacing.lg),
          children: [
            _NavTile(
              icon: Symbols.lightbulb,
              label: 'All notes',
              count: counts.notes,
              selected: location == '/notes',
              expanded: expanded,
              onTap: () => _go(context, '/notes'),
            ),

            _NavTile(
              icon: Symbols.notifications,
              label: 'Reminders',
              count: counts.reminders,
              selected: location == '/reminders',
              expanded: expanded,
              onTap: () => _go(context, '/reminders'),
            ),
            // The labels manager belongs with the other destinations, not in
            // the footer: it stays reachable when the rail is collapsed and the
            // label list below is hidden.
            _NavTile(
              icon: Symbols.sell,
              label: 'Labels',
              selected: location == '/labels',
              expanded: expanded,
              onTap: () => _go(context, '/labels'),
            ),
            _NavTile(
              icon: Symbols.inventory_2,
              label: 'Archive',
              selected: location == '/archive',
              expanded: expanded,
              onTap: () => _go(context, '/archive'),
            ),
            _NavTile(
              icon: Symbols.delete,
              label: 'Trash',
              selected: location == '/trash',
              expanded: expanded,
              onTap: () => _go(context, '/trash'),
            ),
            if (expanded) ...[
              const SizedBox(height: Spacing.lg),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.md, 0, Spacing.sm, Spacing.sm),
                child: Row(
                  children: [
                    const Expanded(child: Eyebrow('Labels')),
                    GhostIconButton(
                      icon: Symbols.add,
                      tooltip: 'New label',
                      iconSize: 16,
                      target: 24,
                      onPressed: () => _go(context, '/labels?new=1'),
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
                  onTap: () => _go(context, '/label/${label.id}'),
                ),
              if (labels.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Spacing.md, 0, Spacing.md, Spacing.sm),
                  child: Text(
                    'No labels yet.',
                    style: context.texts.bodySmall
                        ?.copyWith(color: palette.textTertiary),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Spacing.xl, Spacing.xl, Spacing.lg, Spacing.lg),
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

        return AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.curve,
          width: expanded ? Sizes.sidebar : Sizes.sidebarCollapsed,
          decoration: BoxDecoration(
            color: palette.panel,
            border: Border(right: BorderSide(color: palette.border)),
          ),
          child: ClipRect(child: content),
        );
      },
    );
  }

  void _go(BuildContext context, String path) {
    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
    context.go(path);
  }
}

/// A navigation row: `full`-rounded pill, 40px tall, `label-md`. Selected rows
/// take a `primary-wash` fill, weight 600, and the icon's `FILL` axis at 1 —
/// which is how Material Symbols expresses a filled glyph, so there is no
/// second icon name to keep in sync.
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
    final foreground =
        selected ? palette.onPrimaryWash : palette.textSecondary;
    // Touch layouts get Keep-sized rows: taller, larger glyphs, more inset.
    final roomy = MediaQuery.sizeOf(context).width < kWideLayoutBreakpoint;

    final labelStyle = mono
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

    final tile = Material(
      color: selected ? palette.primaryWash : Colors.transparent,
      borderRadius: AppRadii.all(AppRadii.full),
      child: InkWell(
        borderRadius: AppRadii.all(AppRadii.full),
        onTap: onTap,
        hoverColor: palette.surfaceHover,
        child: Container(
          height: roomy ? 52 : kMinTouchTarget,
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? (roomy ? Spacing.xl : Spacing.md) : Spacing.sm,
          ),
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: roomy ? 23 : (mono ? 16 : 19),
                color: foreground,
                fill: selected ? 1 : 0,
              ),
              if (expanded) ...[
                SizedBox(
                    width: roomy
                        ? Spacing.xl
                        : (mono ? Spacing.md - 2 : Spacing.md)),
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
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xxs),
      child: expanded ? tile : Tooltip(message: label, child: tile),
    );
  }
}
