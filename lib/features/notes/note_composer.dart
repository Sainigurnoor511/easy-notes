import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/spacing.dart';
import '../../core/app_providers.dart';
import '../../core/database/database_providers.dart';
import '../../shared/models/note_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/note_dialogs.dart';
import '../../shared/widgets/note_surface.dart';

/// Quick capture, centred on the canvas at 600px.
///
/// Collapsed: a 56px soft-rectangle input at Level 1. Expanded: an `lg`-radius
/// card at Level 3 with a `headline-sm` title field, a `body-md` body, and a
/// bottom action ribbon. Closing it outside saves silently — there is never a
/// "discard?" prompt for a note the user can trash in one tap.
class NoteComposer extends ConsumerStatefulWidget {
  const NoteComposer({super.key});

  @override
  ConsumerState<NoteComposer> createState() => _NoteComposerState();
}

class _NoteComposerState extends ConsumerState<NoteComposer> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _focusNode = FocusNode();
  bool _expanded = false;
  String? _color;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _expand() {
    if (_expanded) return;
    setState(() => _expanded = true);
    _focusNode.requestFocus();
  }

  Future<void> _close() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isNotEmpty || content.isNotEmpty) {
      await ref.read(notesDaoProvider).createNote(
            title: title,
            content: content,
            color: _color,
          );
      ref.read(syncControllerProvider.notifier).syncNow();
    }
    _titleController.clear();
    _contentController.clear();
    if (!mounted) return;
    setState(() {
      _expanded = false;
      _color = null;
    });
  }

  Future<void> _openTyped(NoteType type) async {
    final note =
        await ref.read(notesDaoProvider).createNote(title: '', type: type);
    if (mounted) context.push('/editor/${note.id}');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final surface = NoteSurface.of(context, _color);

    return TapRegion(
      onTapOutside: (_) {
        if (_expanded) _close();
      },
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.curve,
        constraints: const BoxConstraints(maxWidth: Sizes.quickCapture),
        decoration: BoxDecoration(
          color: surface.background,
          borderRadius:
              AppRadii.all(_expanded ? AppRadii.lg : AppRadii.md),
          border: Border.all(
            color: _expanded ? palette.borderStrong : surface.border,
          ),
          boxShadow:
              _expanded ? AppShadows.e3(palette) : AppShadows.e1(palette),
        ),
        child: _expanded ? _expandedForm(surface) : _collapsedRow(surface),
      ),
    );
  }

  Widget _collapsedRow(NoteSurface surface) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: AppRadii.all(AppRadii.md),
        onTap: _expand,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.only(left: Spacing.lg, right: Spacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Take a note or press '/' for commands…",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodyMedium
                        ?.copyWith(color: surface.mutedForeground),
                  ),
                ),
                GhostIconButton(
                  icon: Symbols.checklist,
                  tooltip: 'New checklist',
                  color: surface.mutedForeground,
                  iconSize: 19,
                  onPressed: () => _openTyped(NoteType.checklist),
                ),
                GhostIconButton(
                  icon: Symbols.article,
                  tooltip: 'New document',
                  color: surface.mutedForeground,
                  iconSize: 19,
                  onPressed: () => _openTyped(NoteType.document),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _expandedForm(NoteSurface surface) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.lg, Spacing.sm, Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: Spacing.sm),
            child: TextField(
              controller: _titleController,
              style: context.texts.headlineSmall
                  ?.copyWith(color: surface.foreground),
              decoration: InputDecoration(
                filled: false,
                hintText: 'Title',
                hintStyle: context.texts.headlineSmall?.copyWith(
                  color: surface.mutedForeground,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(height: Spacing.md),
          Padding(
            padding: const EdgeInsets.only(right: Spacing.sm),
            child: TextField(
              controller: _contentController,
              focusNode: _focusNode,
              maxLines: null,
              minLines: 3,
              style:
                  context.texts.bodyMedium?.copyWith(color: surface.foreground),
              decoration: InputDecoration(
                filled: false,
                hintText: 'Take a note…',
                hintStyle: context.texts.bodyMedium
                    ?.copyWith(color: surface.mutedForeground),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              GhostIconButton(
                icon: Symbols.palette,
                tooltip: 'Colour',
                color: surface.mutedForeground,
                iconSize: 19,
                onPressed: () => showNoteColorDialog(
                    context, _color, (key) => setState(() => _color = key)),
              ),
              GhostIconButton(
                icon: Symbols.checklist,
                tooltip: 'Make it a checklist instead',
                color: surface.mutedForeground,
                iconSize: 19,
                onPressed: () => _openTyped(NoteType.checklist),
              ),
              GhostIconButton(
                icon: Symbols.article,
                tooltip: 'Make it a document instead',
                color: surface.mutedForeground,
                iconSize: 19,
                onPressed: () => _openTyped(NoteType.document),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: Spacing.sm),
                child: TextButton(
                  onPressed: _close,
                  style: TextButton.styleFrom(
                    backgroundColor: palette.surfaceSunken,
                    foregroundColor: palette.textPrimary,
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
