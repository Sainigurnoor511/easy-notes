import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_providers.dart';
import '../../core/database/database_providers.dart';
import '../../shared/models/note_models.dart';
import '../../shared/widgets/note_dialogs.dart';
import '../../app/spacing.dart';

/// Keep-style quick-capture bar: a collapsed "Take a note..." pill that
/// expands into a title + body form with a color/reminder/close toolbar.
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
    setState(() {
      _expanded = false;
      _color = null;
    });
  }

  Future<void> _openChecklist() async {
    final note =
        await ref.read(notesDaoProvider).createNote(title: '', type: NoteType.checklist);
    if (mounted) context.push('/editor/${note.id}');
  }

  Future<void> _openDocument() async {
    final note =
        await ref.read(notesDaoProvider).createNote(title: '', type: NoteType.document);
    if (mounted) context.push('/editor/${note.id}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = noteColorByKey(_color);
    final background = color?.background ?? theme.colorScheme.surfaceContainerHigh;
    final foreground = color?.foreground ?? theme.colorScheme.onSurface;

    return TapRegion(
      onTapOutside: (_) {
        if (_expanded) _close();
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(_expanded ? 16 : 28),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: _expanded
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: _expanded ? _expandedForm(foreground) : _collapsedRow(foreground),
      ),
    );
  }

  Widget _collapsedRow(Color foreground) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: _expand,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md, vertical: Spacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text('Take a note...',
                  style: TextStyle(color: foreground.withValues(alpha: 0.6))),
            ),
            IconButton(
              tooltip: 'New checklist',
              icon: Icon(Icons.checklist, color: foreground),
              onPressed: _openChecklist,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'New document',
              icon: Icon(Icons.article_outlined, color: foreground),
              onPressed: _openDocument,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _expandedForm(Color foreground) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.md, Spacing.sm, Spacing.sm, Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            style: TextStyle(
                color: foreground, fontWeight: FontWeight.w600, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Title',
              hintStyle: TextStyle(color: foreground.withValues(alpha: 0.6)),
              border: InputBorder.none,
              isDense: true,
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: Spacing.xs),
          TextField(
            controller: _contentController,
            focusNode: _focusNode,
            maxLines: null,
            minLines: 1,
            style: TextStyle(color: foreground),
            decoration: InputDecoration(
              hintText: 'Take a note...',
              hintStyle: TextStyle(color: foreground.withValues(alpha: 0.6)),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              IconButton(
                tooltip: 'Color',
                icon: Icon(Icons.palette_outlined, color: foreground),
                onPressed: () => showNoteColorDialog(
                    context, _color, (key) => setState(() => _color = key)),
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              TextButton(onPressed: _close, child: const Text('Close')),
            ],
          ),
        ],
      ),
    );
  }
}
