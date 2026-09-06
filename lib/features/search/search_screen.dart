import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_tokens.dart';
import '../../app/spacing.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../../shared/widgets/app_widgets.dart';
import '../notes/note_card.dart';
import '../notes/notes_section.dart';

/// Search: a `full`-rounded field in the app bar, then results as masonry cards
/// so a hit reads the same way it does on the canvas.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  List<Note> _results = const [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(value));
  }

  Future<void> _run(String value) async {
    if (value.trim().isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final results = await ref.read(notesDaoProvider).search(value);
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasQuery = _query.text.trim().isNotEmpty;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    final gutter = wide ? Spacing.xxl : Spacing.gutter;

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: palette.border)),
        title: Padding(
          padding: const EdgeInsets.only(right: Spacing.lg),
          child: Container(
            height: kMinTouchTarget,
            padding: const EdgeInsets.only(left: Spacing.md, right: Spacing.xs),
            decoration: BoxDecoration(
              color: palette.surfaceSunken,
              borderRadius: AppRadii.all(AppRadii.full),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Icon(Symbols.search, size: 18, color: palette.textTertiary),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: TextField(
                    controller: _query,
                    autofocus: true,
                    style: context.texts.bodyMedium,
                    decoration: InputDecoration(
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Search notes, labels, checklists…',
                      hintStyle: context.texts.bodyMedium
                          ?.copyWith(color: palette.textTertiary),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onChanged: _onChanged,
                  ),
                ),
                if (hasQuery)
                  GhostIconButton(
                    icon: Symbols.close,
                    tooltip: 'Clear',
                    iconSize: 18,
                    target: 32,
                    onPressed: () {
                      _query.clear();
                      _run('');
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      body: !hasQuery
          ? const EmptyState(
              icon: Symbols.search,
              title: 'Search your workspace',
              message: 'Titles, note bodies and checklist items are all '
                  'matched as you type.',
            )
          : _searching
              ? const CenteredLoader()
              : _results.isEmpty
                  ? EmptyState(
                      icon: Symbols.search_off,
                      title: 'No matches',
                      message:
                          'Nothing matched "${_query.text.trim()}". Try a '
                          'shorter or different term.',
                    )
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                gutter, Spacing.xl, gutter, Spacing.md),
                            child: SectionHeader(
                              icon: Symbols.search,
                              label: 'Results',
                              count: _results.length,
                              trailing: Text(
                                'Sorted by last modified',
                                style: context.texts.labelSmall
                                    ?.copyWith(color: palette.textTertiary),
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                              gutter, 0, gutter, Spacing.xxxl),
                          sliver: SliverList.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: Spacing.md),
                            itemBuilder: (context, i) => Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                    maxWidth: Sizes.sheet),
                                child: NoteCard(
                                  note: _results[i],
                                  section: NotesSection.notes,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
