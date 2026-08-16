import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';

class LabelsScreen extends ConsumerStatefulWidget {
  const LabelsScreen({super.key});

  @override
  ConsumerState<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends ConsumerState<LabelsScreen> {
  final TextEditingController _newLabel = TextEditingController();

  @override
  void dispose() {
    _newLabel.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _newLabel.text.trim();
    if (name.isEmpty) return;
    _newLabel.clear();
    await ref.read(labelsDaoProvider).create(name);
  }

  Future<void> _rename(Label label) async {
    final controller = TextEditingController(text: label.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(labelsDaoProvider).rename(label.id, name.trim());
    }
    controller.dispose();
  }

  Future<void> _delete(Label label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${label.name}"?'),
        content: const Text('Notes keep their content. The label is removed from all notes.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(labelsDaoProvider).delete(label.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(labelsDaoProvider);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newLabel,
                    decoration: const InputDecoration(
                      hintText: 'Create label',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _create(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Create',
                  onPressed: _create,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Label>>(
              stream: dao.watchAll(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snapshot.data!;
                if (list.isEmpty) {
                  return const Center(child: Text('No labels yet'));
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final label = list[i];
                    return ListTile(
                      leading: const Icon(Icons.label_outline),
                      title: Text(label.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Rename',
                            onPressed: () => _rename(label),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete',
                            onPressed: () => _delete(label),
                          ),
                        ],
                      ),
                      onTap: () => context.go('/label/${label.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}