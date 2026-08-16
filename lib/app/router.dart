import 'package:flutter/material.dart';
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
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import 'spacing.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Below this width the sidebar collapses into a drawer, matching Keep's
/// own breakpoint between mobile and desktop/tablet layouts.
const double kWideLayoutBreakpoint = Breakpoints.tablet;

/// Whether the wide-screen sidebar is showing icon+label or icon-only.
/// Toggled by the app bar's menu button, mirroring Keep's own behavior.
final sidebarExpandedProvider = StateProvider<bool>((ref) => true);

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
            builder: (context, state) => const LabelsScreen(),
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

/// Shell used by every top-level section. On wide screens the sidebar is a
/// permanent rail (togglable between icon+label and icon-only); below
/// [kWideLayoutBreakpoint] it becomes a drawer, matching Keep's own
/// responsive behavior.
class AppShell extends ConsumerWidget {
  final String location;
  final Widget child;

  const AppShell({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final expanded = ref.watch(sidebarExpandedProvider);

    return Scaffold(
      appBar: const _EasyNotesAppBar(),
      drawer: wide ? null : const _Sidebar(inDrawer: true, expanded: true),
      body: Row(
        children: [
          if (wide) _Sidebar(inDrawer: false, expanded: expanded),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _EasyNotesAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _EasyNotesAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncControllerProvider);
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;

    return AppBar(
      titleSpacing: 4,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
              onPressed: () {
                if (wide) {
                  ref.read(sidebarExpandedProvider.notifier).state =
                      !ref.read(sidebarExpandedProvider);
                } else {
                  Scaffold.of(context).openDrawer();
                }
              },
            ),
          ),
          const SizedBox(width: Spacing.sm),
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.tertiaryContainer,
            child: Icon(Icons.lightbulb,
                color: theme.colorScheme.onTertiaryContainer, size: 18),
          ),
          const SizedBox(width: Spacing.sm),
          Text('Keep Notes', style: theme.textTheme.titleLarge),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SearchBar(
                hintText: 'Search',
                leading: const Icon(Icons.search),
                onTap: () => context.push('/search'),
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (sync.status == SyncStatus.syncing)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Spacing.sm),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(syncControllerProvider.notifier).syncNow(),
          ),
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/settings'),
        ),
        const SizedBox(width: Spacing.xs),
        const _AvatarButton(),
        const SizedBox(width: Spacing.sm),
      ],
    );
  }
}

class _AvatarButton extends ConsumerWidget {
  const _AvatarButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).valueOrNull;
    final photoUrl = auth?.user?.photoUrl;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push('/settings'),
      child: CircleAvatar(
        radius: 16,
        backgroundImage: photoUrl != null && photoUrl.isNotEmpty
            ? NetworkImage(photoUrl)
            : null,
        child: photoUrl == null || photoUrl.isEmpty
            ? const Icon(Icons.person_outline, size: 18)
            : null,
      ),
    );
  }
}

/// Navigation destinations shared by the rail and the drawer.
class _Sidebar extends ConsumerWidget {
  final bool inDrawer;
  final bool expanded;

  const _Sidebar({required this.inDrawer, required this.expanded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelsDao = ref.watch(labelsDaoProvider);
    final location = GoRouterState.of(context).uri.path;

    return StreamBuilder<List<Label>>(
      stream: labelsDao.watchAll(),
      builder: (context, snapshot) {
        final labels = snapshot.data ?? const <Label>[];
        final content = ListView(
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          children: [
            _NavTile(
              icon: Icons.lightbulb_outline,
              selectedIcon: Icons.lightbulb,
              label: 'Notes',
              selected: location == '/notes',
              expanded: expanded,
              onTap: () => _go(context, '/notes'),
            ),
            _NavTile(
              icon: Icons.notifications_outlined,
              selectedIcon: Icons.notifications,
              label: 'Reminders',
              selected: location == '/reminders',
              expanded: expanded,
              onTap: () => _go(context, '/reminders'),
            ),
            _NavTile(
              icon: Icons.label_outline,
              selectedIcon: Icons.label,
              label: 'Labels',
              selected: location == '/labels',
              expanded: expanded,
              onTap: () => _go(context, '/labels'),
            ),
            _NavTile(
              icon: Icons.archive_outlined,
              selectedIcon: Icons.archive,
              label: 'Archive',
              selected: location == '/archive',
              expanded: expanded,
              onTap: () => _go(context, '/archive'),
            ),
            _NavTile(
              icon: Icons.delete_outline,
              selectedIcon: Icons.delete,
              label: 'Bin',
              selected: location == '/trash',
              expanded: expanded,
              onTap: () => _go(context, '/trash'),
            ),
            if (expanded && labels.isNotEmpty) ...[
              const Divider(height: Spacing.lg),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, Spacing.xs, Spacing.md, Spacing.sm),
                child: Text('Labels',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(letterSpacing: 0.5)),
              ),
              for (final label in labels)
                _NavTile(
                  icon: Icons.label_outline,
                  selectedIcon: Icons.label,
                  label: label.name,
                  selected: location == '/label/${label.id}',
                  expanded: expanded,
                  onTap: () => _go(context, '/label/${label.id}'),
                ),
            ],
            const Divider(height: Spacing.lg),
            _NavTile(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
              label: 'Settings',
              selected: location == '/settings',
              expanded: expanded,
              onTap: () => _go(context, '/settings'),
            ),
          ],
        );

        if (inDrawer) {
          return Drawer(child: SafeArea(child: content));
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: expanded ? 280 : 80,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: content,
          ),
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

class _NavTile extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconWidget = Icon(selected ? selectedIcon : icon,
        size: 20,
        color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant);

    if (!expanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm, vertical: Spacing.xs),
        child: Tooltip(
          message: label,
          child: Material(
            color: selected ? scheme.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.sm),
                child: iconWidget,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm, vertical: Spacing.xs / 2),
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
        child: InkWell(
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md, vertical: Spacing.sm),
            child: Row(
              children: [
                iconWidget,
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? scheme.onSecondaryContainer
                          : scheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
