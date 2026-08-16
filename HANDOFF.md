# HANDOFF — Easy Notes

Status: 2026-08-16, drift blocker fixed, web/Windows/Android platform split
done, app is local-first (no forced login), Material 3 Keep-style theme
applied. `flutter analyze` 0 issues, 4 DAO tests passing.
Purpose: capture the plan, what is built, the current blocker, and what remains.

## 0. Recent changes (this session, after section 1-8 below were written)

- **Web platform support**: `dart:io` was reachable from `main.dart` via
  `DatabaseManager`, `AttachmentStorage`, `SyncService`, `DriveService` -
  a hard compile error on web. Split each into `_io.dart`/`_web.dart`
  variants behind `if (dart.library.js_interop)` conditional imports. Web
  now runs the DB via `drift_flutter` WASM (needs `web/sqlite3.wasm` +
  `web/drift_worker.js` - compiled from drift's worker source, see
  `web/drift_worker.dart`; regenerate with
  `dart compile js web/drift_worker.dart -o web/drift_worker.js -O4` if
  drift is ever upgraded). Attachments, export/restore, and Drive sync are
  gated behind `kIsWeb` in the UI and throw `UnsupportedError` if reached
  on web by mistake.
- **Local-first, no forced login**: removed the router's `redirect` gate
  that forced `/login` before any screen loaded. App always opens straight
  to `/notes`. Deleted `login_screen.dart` (orphaned). Google Drive connect
  is now a single Settings action: `features/settings/settings_screen.dart`
  merged the old "Account" + "Sync" sections into one "Sync & Backup"
  section - shows "Connect Google Drive" when signed out, account +
  sync controls when signed in. Errors from `signIn()` surface as a
  snackbar via `ref.listen(authControllerProvider, ...)`.
- **Material 3 theme pass**: `app/theme.dart` now sets `AppBarTheme`,
  `NavigationDrawerThemeData`, `FloatingActionButtonThemeData` (rounded
  square FAB, Keep-style), `SearchBarThemeData`, `ChipThemeData`,
  `DialogThemeData`, `ListTileThemeData`, `PopupMenuThemeData` - all
  derived from `ColorScheme.fromSeed` for consistent tonal surfaces in
  light/dark. `NoteCard`'s ripple radius bumped to 16 to match the new
  card corner radius.
- Google Sign-In on web still needs a real OAuth client ID
  (`<meta name="google-signin-client_id">` in `web/index.html`) before
  "Connect Google Drive" will work there - not yet configured, see
  section 5.
- **Keep-style UI pass**: `app/router.dart`'s `AppShell` is now responsive -
  at width >= `kWideLayoutBreakpoint` (768, = `Breakpoints.tablet`) the
  sidebar is a permanent rail
  (`_Sidebar(inDrawer: false)`) with pill-shaped selection, matching Keep's
  desktop layout; below that it's the original `Drawer` opened from a menu
  button. The app bar is custom (`_EasyNotesAppBar`): logo + wordmark
  (wordmark hidden on narrow widths to leave room for search), an inline
  `SearchBar` that pushes `/search` on tap, and refresh/settings/avatar
  actions on the right - replacing the old per-screen title/search bar.
  Added `features/notes/note_composer.dart`: a collapsed "Take a note..."
  pill above the grid that expands into a title+body form
  (color picker + Close), matching Keep's quick-capture bar; only shown on
  the Notes section. The FAB is now hidden on wide layouts (composer covers
  that role there) and still shown on narrow ones. `NoteCard` gained a
  hover-revealed action row (color, reminder, labels, archive, overflow
  menu) plus a pin toggle in the corner - always visible on narrow/touch
  widths (`!wide || _hovering`), hover-only on wide/desktop, using
  `IgnorePointer` so hidden actions aren't tappable. Trash cards show
  Restore/Delete forever text buttons instead.
- **Palette + spacing pass** (via the `ui-ux-pro-max` skill,
  `~/.claude/skills/ui-ux-pro-max`): replaced the generic Google-blue seed
  in `app/theme.dart` with the tool's verified "Notes & Writing App"
  product palette - warm ink primary (`#78716C`), amber accent/FAB
  (`#D97706`), cream surface (`#FFFBEB`) in light mode, with a hand-tuned
  dark counterpart in the same warm family (not just an inverted seed) so
  the identity survives dark mode. All text/surface pairs checked
  programmatically against WCAG contrast - light 4.8-17.2:1, dark
  9.0-15.1:1, both comfortably above the 4.5:1 minimum. Added
  `app/spacing.dart` (`Spacing.xs/sm/md/lg/xl/xxl` = 4/8/16/24/32/48,
  `Breakpoints.mobile/tablet/desktop/wide` = 375/768/1024/1440) and
  normalized every off-scale padding/gap in `router.dart`,
  `notes_screen.dart`, `note_card.dart`, `note_composer.dart`, and
  `settings_screen.dart` to it. The notes grid's column count is now keyed
  to the four standard breakpoints (1/2/3/4/5 columns) instead of ad hoc
  width checks, and `settings_screen.dart` is now centered with a 720px
  max-width instead of stretching edge-to-edge on desktop.

---

## 1. The Plan

A personal, offline-first Google Keep-style notes app (Flutter) with a small set
of Notion-style blocks. No backend, no Firebase/Supabase, no AI, no
collaboration, no CRDTs, no complex Notion databases.

Architecture:

```
Flutter App
    |-- Google Sign-In
    |-- SQLite (Drift)           <- primary local store
    |-- Local File Storage       <- attachments on disk, metadata in SQLite
    +-- Google Drive API         <- backup/sync only
```

Phases (spec-required order):
1. Foundation - project, Material3, Riverpod, GoRouter, Drift schema, repos.
   Vertical slice: login -> notes -> create/edit -> SQLite -> restart -> note persists.
2. Keep features - notes, checklists, pin, archive, trash, colors, labels, search, grid/list.
3. Block editor - text/heading/bullet/numbered/checklist/quote/code/divider/table/image.
4. Attachments + reminders - local files, local notifications.
5. Google auth - sign-in/out, persist session, offline fallback mode.
6. Google Drive sync - MyNotes folder, upload/download DB + attachments, LWW,
   manual + automatic sync, export/restore.
7. Polish - themes, empty/loading/error states, a11y, icons, release config.
8. Tests + README.

Key decisions already made (keep these):
- **Sync = file-level last-write-wins.** `database.sqlite` is the sync unit.
  Compare local max `notes.updated_at` vs remote `metadata.json#maxUpdatedAt`
  to decide upload vs download; equal timestamps -> keep local; brand-new
  device (local revision 0) pulls remote. Pure function
  `decideSyncDirection(...)` in `lib/core/sync/sync_service.dart` (unit-testable).
- **Search = LIKE-based** (offline), across title/content, block content,
  checklist text, label names. FTS5 deferred unless needed.
- **Note `content` column is a denormalized plain-text preview.** For document
  notes the editor rebuilds it from blocks so cards + search keep working.
- **Heading level** stored in block content as `"<level>|<text>"` (e.g. `2|Title`).
- **IDs are UUID strings** (all tables) - safe for future row merging.
- **Auth offline fallback:** signed-in profile cached in SharedPreferences;
  if Google is unreachable at startup, app opens in "offline" mode (still usable).
- Attachments stored under `<appDocs>/attachments/<noteId>/<file>`, never as BLOBs.
- Restore always writes a pre-restore backup first.

---

## 2. What Has Been Done

### Scaffold + deps
- `flutter create` with platforms `android,windows,web`, project `easy_notes`.
- pubspec pinned for Dart 3.7.2 / Flutter 3.29.2:
  - runtime: `flutter_riverpod 2.6.1`, `go_router 14.8.0`, `drift 2.28.0`,
    `drift_flutter 0.2.4`, `sqlite3_flutter_libs`, `path_provider`, `path 1.9.1`,
    `shared_preferences`, `google_sign_in 6.2.2`, `googleapis 13.2.0`,
    `googleapis_auth`, `http`, `connectivity_plus 6.1.2`, `file_picker 8.1.7`,
    `image_picker`, `flutter_local_notifications 18.0.1`, `timezone`, `intl`, `uuid`.
  - dev: `drift_dev 2.28.0`, `build_runner 2.4.14`, `flutter_lints 5`.

### Code written (all under `lib/`)
- `main.dart` - async init (DatabaseManager.open + ReminderService.init), ProviderScope override.
- `app/theme.dart` - Material3 light/dark themes.
- `app/app.dart` - MaterialApp.router, auto-sync listeners (login, connectivity return).
- `app/router.dart` - GoRouter: `/login`, shell (`/notes /archive /trash /reminders
  /labels /label/:id /settings`), `/editor/:noteId`, `/search`, auth redirect.
- `core/database/app_database.dart` - 7 Drift tables + migration strategy + FK/WAL pragmas.
- `core/database/database_manager.dart` - owns live DB + backing file path; export/restore
  (close -> copy -> reopen), dbSize.
- `core/database/database_factory.dart` + `_io.dart` + `_web.dart` - platform executors
  (NativeDatabase vs drift_flutter for web).
- `core/database/database_providers.dart` - manager/dao providers.
- `core/database/daos/` - `notes_dao.dart` (notes + blocks + checklist + search +
  maxUpdatedAt), `labels_dao.dart`, `attachments_dao.dart`, `settings_dao.dart`.
- `core/storage/attachment_storage.dart` - file save/delete/list/totalSize.
- `core/sync/drive_service.dart` - authed http client, folder ensure, upload/download,
  metadata read/write, narrow `drive.file` scope.
- `core/sync/sync_service.dart` - sync engine + `decideSyncDirection` (pure).
- `core/sync/sync_status.dart` - SyncState/SyncStatus.
- `core/app_providers.dart` - AuthController (AsyncNotifier), ThemeController,
  SyncController, connectivity stream.
- `shared/models/` - `note_models.dart` (NoteType, BlockType, TableBlockData, colors),
  `auth_user.dart`.
- `shared/widgets/note_dialogs.dart` - color/label/reminder dialogs.
- Features:
  - `auth/login_screen.dart`
  - `notes/` - `notes_section.dart`, `notes_screen.dart` (grid/list, FAB, sections),
    `note_card.dart`, `note_actions.dart`, `note_editor_screen.dart`
  - `editor/` - `block_editor.dart`, `block_widgets.dart` (all block tiles incl. table),
    `checklist_editor.dart`, `attachments_section.dart`
  - `search/search_screen.dart`, `labels/labels_screen.dart`,
    `settings/settings_screen.dart` (account/theme/sync/storage/about),
    `reminders/reminder_service.dart` (local notifications).

### Generated
- `lib/core/database/app_database.g.dart` - **6 of 7 tables generated** (see blocker).

---

## 3. BLOCKER — RESOLVED

`drift_dev 2.28.0` could not analyze the `ChecklistItems` table because its
column getter was named `text`, colliding with the `text()` column-builder
method in the same scope. Fixed by renaming the column to `content`
(`lib/core/database/app_database.dart`). All downstream references in
`notes_dao.dart`, `checklist_editor.dart`, `note_card.dart`,
`note_editor_screen.dart` updated to use `.content` / `content:` instead of
`.text` / `text:`. `build_runner` now generates all 7 tables cleanly.

---

## 4. `flutter analyze` fixes — DONE (0 errors)

Fixed, in addition to the ChecklistItems rename:

- Riverpod misuse: `ref.watch(daoProvider.watchX())` doesn't work because
  `Provider<Dao>` has no such method — every read/watch call site now does
  `ref.watch(daoProvider)` then feeds the returned `Stream` into a
  `StreamBuilder` (`attachments_section.dart`, `block_editor.dart`,
  `checklist_editor.dart`, `labels_screen.dart`, `note_card.dart`,
  `note_editor_screen.dart`, `router.dart`'s `_AppDrawer`).
- `notes_dao.dart`: added `watchById()` (single-row stream) since the editor
  screen needed to watch one note reactively; `NotesCompanion.insert()` and
  friends need every `withDefault` column wrapped in `Value(...)` even inside
  `.insert()` — fixed across `notes_dao.dart`, `labels_dao.dart`,
  `attachments_dao.dart`, `settings_dao.dart`.
- Joined-select `orderBy` on drift 2.28 takes `List<OrderingTerm>` directly,
  not `List<OrderingTerm Function(TypedResult)>` — fixed in
  `notes_dao.watchByLabel` and `labels_dao.watchForNote`/`forNote`.
- `drive_service.dart`: googleapis 13.2.0 uses `$fields` not `fields`;
  `files.get()` returns `Object`, cast to `drive.File` or `drive.Media`
  depending on `downloadOptions`; `Media.stream` has no `.toBytes()`, collect
  via `stream.fold`; mime type goes on the `Media` constructor's
  `contentType`, not an `uploadMediaMimeType` param; temp file path now uses
  `path_provider.getTemporaryDirectory()` + `path.join` instead of the
  invalid `File(...).resolve(...)`.
- `sync_service.dart`: `SyncOfflineException`/`SyncFailure` given `const`
  constructors; removed unused `dart:convert` import.
- `block_editor.dart`: `Icons.heading` doesn't exist, swapped for
  `Icons.text_fields`.
- `block_widgets.dart`: `_pickHint()` now takes `BuildContext`;
  `PopupMenuButton` doesn't accept `visualDensity`, dropped it in two spots;
  removed an unused `theme` local.
- `note_editor_screen.dart`: rebuilt `build()` around nested `StreamBuilder`s
  (note, then labels) since `getById`/`watchForNote` aren't `AsyncValue`
  providers; `_scheduleSave` callback type changed to
  `Future<void> Function()`.
- `reminder_service.dart`: flutter_local_notifications 18.0.1 has no
  `WindowsInitializationSettings` — dropped Windows notification support
  (Android-only for now); `zonedSchedule` needs
  `uiLocalNotificationDateInterpretation: .absoluteTime`.
- `main.dart`: `databaseManagerProvider.overrideWithValue(manager)` →
  `.overrideWith((ref) => manager)` (it's a `StateProvider`).
- `note_actions.dart`: removed unused `attachment_storage` import.
- `app.dart` / `app_providers.dart`: missing `connectivity_plus` /
  `flutter/material.dart` imports for `ConnectivityResult` / `ThemeMode`.
- `router.dart`: missing imports for `NotesSection`, `labelsDaoProvider`,
  `SyncStatus`.
- `test/widget_test.dart`: replaced the default counter template with 4
  `NotesDao` tests against an in-memory `AppDatabase` (create/get, pin,
  trash/restore, checklist item).

Also fixed: `use_key_in_widget_constructors` on `BlockRow` (added `super.key`);
`use_build_context_synchronously` across `note_editor_screen.dart`,
`settings_screen.dart`, `note_dialogs.dart` — `State` classes now guard with
their own `mounted` instead of `context.mounted`, and free functions in
`note_dialogs.dart` got explicit `if (!context.mounted) return;` before each
post-await `BuildContext` use.

Command: `flutter analyze` — 0 issues. `flutter test` — 4/4 passing.

---

## 5. Work Still To Do (by phase)

### Phase 5 - Google Auth (code exists, needs platform config)
- Android: add `google-services.json` + SHA-1 in Google Cloud console; create OAuth client.
- Web: OAuth client ID + redirect config.
- The rest (login screen, auth controller, offline fallback) is written but
  **not runtime-tested** without real credentials.

### Phase 6 - Google Drive sync
- Code written (`drive_service.dart`, `sync_service.dart`, `SyncController`,
  settings UI with Sync Now / Export / Restore). Needs real credentials to test.
- Verify upload/download, metadata read/write, revision bumping, restore path,
  and the DB-replace notification (SyncController bumps `databaseManagerProvider`
  so DAOs rebuild against the new connection).

### Phase 7 - Polish
- Empty/loading/error states mostly written; verify a11y (semantics, contrast,
  touch targets), responsive layout, app icon, splash, release build configs
  (Android manifest bits for google_sign_in, notifications permissions).

### Tests
- DB: create/update/delete/restore/pin/archive note, add/remove label,
  create checklist, create table (block content JSON).
- Search: title, content, checklist, labels.
- Sync: `decideSyncDirection` for local-newer / remote-newer / equal / brand-new
  device; offline throws SyncOfflineException.
- Widget smoke: notes list renders, grid/list toggle, editor block insert,
  settings theme change.
- Note: `NotesDao` tests need an in-memory DB (`AppDatabase(NativeDatabase.memory())`).
  DatabaseManager is file-based (IO) - DAO tests should construct `AppDatabase`
  directly, not through DatabaseManager.

### README
- Sections required by spec: Features, Screenshots, Architecture, Tech Stack,
  Local Development, Google OAuth Setup, Google Drive API Setup, Database,
  Sync Architecture, Building Android, Building Windows, Building Web,
  Troubleshooting, License. Must explain fresh-clone run steps.

---

## 6. Key Files Cheat-Sheet

| Purpose | File |
| --- | --- |
| Schema + tables + migrations | `lib/core/database/app_database.dart` |
| Generated drift code (incomplete) | `lib/core/database/app_database.g.dart` |
| DB lifecycle/export/restore | `lib/core/database/database_manager.dart` |
| DB + dao providers | `lib/core/database/database_providers.dart` |
| Notes/blocks/checklist/search queries | `lib/core/database/daos/notes_dao.dart` |
| Auth/theme/sync/connectivity providers | `lib/core/app_providers.dart` |
| Drive API wrapper | `lib/core/sync/drive_service.dart` |
| Sync engine + LWW decision | `lib/core/sync/sync_service.dart` |
| Routing + drawer shell | `lib/app/router.dart` |
| Main notes UI | `lib/features/notes/notes_screen.dart` |
| Note editor (text/checklist/document) | `lib/features/notes/note_editor_screen.dart` |
| Block tiles + table | `lib/features/editor/block_widgets.dart` |
| Block orchestration | `lib/features/editor/block_editor.dart` |
| Checklist widget | `lib/features/editor/checklist_editor.dart` |
| Attachments UI | `lib/features/editor/attachments_section.dart` |
| Local notifications | `lib/features/reminders/reminder_service.dart` |

## 7. Commands

- Codegen: `dart run build_runner build --delete-conflicting-outputs`
- Analyze: `flutter analyze`
- Test: `flutter test`
- Run Windows: `flutter run -d windows`

## 8. Notes for the Next Session

- Start by fixing the `ChecklistItems` drift blocker (section 3), then run
  `build_runner`, then apply the `flutter analyze` fixes (section 4).
- After that, write tests (section 5) and the README.
- Google auth + Drive need real OAuth credentials; document setup in README.
- The app targets Android + Windows primarily; web path exists via
  `database_factory_web.dart` (drift_flutter WASM) but is untested.