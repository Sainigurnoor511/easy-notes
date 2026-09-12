import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_tokens.dart';
import '../../app/spacing.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../../shared/widgets/app_widgets.dart';

/// Checklist rows with a progress header.
///
/// Checkboxes are 18px rounded squares (`handle` radius). Checked applies the
/// indigo fill with a white check, and the label gets line-through in
/// `text-tertiary`.
class ChecklistEditor extends ConsumerStatefulWidget {
  final String noteId;
  final String? blockId;
  final VoidCallback? onChanged;

  const ChecklistEditor({
    super.key,
    required this.noteId,
    this.blockId,
    this.onChanged,
  });

  @override
  ConsumerState<ChecklistEditor> createState() => _ChecklistEditorState();
}

class _ChecklistEditorState extends ConsumerState<ChecklistEditor> {
  final Map<String, TextEditingController> _controllers = {};
  final TextEditingController _newItem = TextEditingController();

  TextEditingController _forItem(String id, String text) =>
      _controllers.putIfAbsent(id, () => TextEditingController(text: text));

  Future<void> _addItem() async {
    final text = _newItem.text.trim();
    if (text.isEmpty) return;
    _newItem.clear();
    final dao = ref.read(notesDaoProvider);
    await dao.addChecklistItem(widget.noteId, text, blockId: widget.blockId);
    await dao.touch(widget.noteId);
    widget.onChanged?.call();
  }

  Future<void> _toggle(String id, bool completed) async {
    final dao = ref.read(notesDaoProvider);
    await dao.setChecklistItemCompleted(id, completed);
    await dao.touch(widget.noteId);
    widget.onChanged?.call();
  }

  Future<void> _remove(String id) async {
    final dao = ref.read(notesDaoProvider);
    final item = await dao.getChecklistItem(id);
    await dao.removeChecklistItem(id);
    if (item != null) _controllers.remove(item.id)?.dispose();
    await dao.touch(widget.noteId);
    widget.onChanged?.call();
  }

  Future<void> _saveText(String id, String text) async {
    final dao = ref.read(notesDaoProvider);
    await dao.setChecklistItemText(id, text);
    await dao.touch(widget.noteId);
    widget.onChanged?.call();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _newItem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dao = ref.watch(notesDaoProvider);

    return StreamBuilder<List<ChecklistItem>>(
      stream: dao.watchChecklistItemsFor(
        noteId: widget.noteId,
        blockId: widget.blockId,
      ),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <ChecklistItem>[];
        final done = items.where((i) => i.isCompleted).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (items.isNotEmpty) ...[
              LabelledProgress(
                label: 'Progress',
                value: '$done of ${items.length} completed',
                fraction: done / items.length,
              ),
              const SizedBox(height: Spacing.lg),
            ],
            for (final item in items) _row(context, item),
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 18 + Spacing.md,
                    child: Icon(
                      Symbols.add,
                      size: 18,
                      color: palette.textTertiary,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _newItem,
                      style: context.texts.bodyMedium,
                      decoration: InputDecoration(
                        filled: false,
                        hintText: 'Add an item',
                        hintStyle: context.texts.bodyMedium?.copyWith(
                          color: palette.textTertiary,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _addItem(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext context, ChecklistItem item) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: Spacing.md),
            child: _Checkbox(
              checked: item.isCompleted,
              onChanged: (v) => _toggle(item.id, v),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _forItem(item.id, item.content),
              style: context.texts.bodyMedium?.copyWith(
                color:
                    item.isCompleted
                        ? palette.textTertiary
                        : palette.textPrimary,
                decoration:
                    item.isCompleted ? TextDecoration.lineThrough : null,
                decorationColor: palette.textTertiary,
              ),
              maxLines: null,
              decoration: const InputDecoration(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => _saveText(item.id, v),
            ),
          ),
          GhostIconButton(
            icon: Symbols.close,
            tooltip: 'Remove item',
            iconSize: 16,
            target: 28,
            color: palette.textTertiary,
            onPressed: () => _remove(item.id),
          ),
        ],
      ),
    );
  }
}

/// An 18px rounded-square checkbox with the indigo checked state.
class _Checkbox extends StatelessWidget {
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _Checkbox({required this.checked, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      checked: checked,
      child: InkWell(
        borderRadius: AppRadii.all(AppRadii.handle),
        onTap: () => onChanged(!checked),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: checked ? palette.primary : Colors.transparent,
            borderRadius: AppRadii.all(AppRadii.handle),
            border: Border.all(
              color: checked ? palette.primary : palette.borderStrong,
              width: 1.5,
            ),
          ),
          child:
              checked
                  ? Icon(Symbols.check, size: 13, color: palette.onPrimary)
                  : null,
        ),
      ),
    );
  }
}
