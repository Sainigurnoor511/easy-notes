import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_providers.dart';
import '../notes/note_card.dart';
import '../notes/notes_section.dart';

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
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(value));
  }

  Future<void> _run(String value) async {
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
    final hasQuery = _query.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search notes, labels, checklists...',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
        actions: [
          if (hasQuery)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _query.clear();
                setState(() {});
                _run('');
              },
            ),
        ],
      ),
      body: !hasQuery
          ? const Center(child: Text('Type to search'))
          : _searching
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty
                  ? const Center(child: Text('No results'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _results.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: NoteCard(
                            note: _results[i],
                            section: NotesSection.notes),
                      ),
                    ),
    );
  }
}