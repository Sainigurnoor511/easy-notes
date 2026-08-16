import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';

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
    await ref.read(notesDaoProvider).setChecklistItemCompleted(id, completed);
    await ref.read(notesDaoProvider).touch(widget.noteId);
    widget.onChanged?.call();
  }

  Future<void> _remove(String id) async {
    final dao = ref.read(notesDaoProvider);
    final item = await dao.getChecklistItem(id);
    await dao.removeChecklistItem(id);
    if (item != null) {
      _controllers.remove(item.id)?.dispose();
    }
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
    final dao = ref.watch(notesDaoProvider);
    return StreamBuilder<List<ChecklistItem>>(
      stream: dao.watchChecklistItemsFor(
          noteId: widget.noteId, blockId: widget.blockId),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <ChecklistItem>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items) _buildItem(item),
            Padding(
              padding: const EdgeInsets.only(left: 0, top: 4),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.add, size: 20),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _newItem,
                      decoration: const InputDecoration(
                        hintText: 'Add item',
                        border: InputBorder.none,
                        isDense: true,
                      ),
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

  Widget _buildItem(ChecklistItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: item.isCompleted,
          onChanged: (v) => _toggle(item.id, v ?? false),
        ),
        Expanded(
          child: TextField(
            controller: _forItem(item.id, item.content),
            decoration: const InputDecoration(
                border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
            style: TextStyle(
              decoration:
                  item.isCompleted ? TextDecoration.lineThrough : null,
            ),
            onChanged: (v) => _saveText(item.id, v),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          icon: const Icon(Icons.close),
          tooltip: 'Remove item',
          onPressed: () => _remove(item.id),
        ),
      ],
    );
  }
}