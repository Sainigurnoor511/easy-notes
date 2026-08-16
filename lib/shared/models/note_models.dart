import 'dart:convert';

import 'package:flutter/material.dart';

enum NoteType { text, checklist, document }

enum BlockType {
  text,
  heading,
  bullet,
  numberedList,
  checklist,
  quote,
  code,
  divider,
  image,
  table;

  static BlockType fromDb(String v) => BlockType.values
      .firstWhere((e) => e.name == v, orElse: () => BlockType.text);

  String get dbName => name;
}

/// Content for a table block, stored as JSON in `blocks.content`.
class TableBlockData {
  List<String> columns;
  List<List<String>> rows;

  TableBlockData({List<String>? columns, List<List<String>>? rows})
      : columns = columns ?? <String>['Column 1', 'Column 2'],
        rows = rows ?? <List<String>>[<String>['', ''], <String>['', '']];

  factory TableBlockData.fromJson(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final columns = (map['columns'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
      final rows = (map['rows'] as List<dynamic>? ?? const [])
          .map((r) => (r as List<dynamic>).map((e) => e.toString()).toList())
          .toList();
      return TableBlockData(columns: columns, rows: rows);
    } catch (_) {
      return TableBlockData();
    }
  }

  String toJson() => jsonEncode({'columns': columns, 'rows': rows});

  void addRow() => rows.add(List.filled(columns.length, ''));

  void addColumn() {
    columns.add('Column ${columns.length + 1}');
    for (final r in rows) {
      r.add('');
    }
  }

  void removeRow(int index) {
    if (rows.length > 1) rows.removeAt(index);
  }

  void removeColumn(int index) {
    if (columns.length > 1) {
      columns.removeAt(index);
      for (final r in rows) {
        r.removeAt(index);
      }
    }
  }
}

/// Note color palette, Keep-style. Key is stored in SQLite.
class NoteColor {
  final String key;
  final String label;
  final Color? background;
  final Color? foreground;

  const NoteColor(this.key, this.label, {this.background, this.foreground});
}

const List<NoteColor> kNoteColors = [
  NoteColor('default', 'Default'),
  NoteColor('red', 'Red',
      background: Color(0xFFF28B82), foreground: Color(0xFF3C0A07)),
  NoteColor('orange', 'Orange',
      background: Color(0xFFFBBC04), foreground: Color(0xFF231A00)),
  NoteColor('yellow', 'Yellow',
      background: Color(0xFFFFF475), foreground: Color(0xFF242105)),
  NoteColor('green', 'Green',
      background: Color(0xFFCCFF90), foreground: Color(0xFF1B3312)),
  NoteColor('teal', 'Teal',
      background: Color(0xFFA7FFEB), foreground: Color(0xFF0B2B26)),
  NoteColor('blue', 'Blue',
      background: Color(0xFFAECBFA), foreground: Color(0xFF0E233D)),
  NoteColor('purple', 'Purple',
      background: Color(0xFFD7AEFB), foreground: Color(0xFF2A1042)),
  NoteColor('pink', 'Pink',
      background: Color(0xFFFDCFE8), foreground: Color(0xFF3A0A22)),
];

NoteColor? noteColorByKey(String? key) {
  if (key == null) return null;
  for (final c in kNoteColors) {
    if (c.key == key) return c;
  }
  return null;
}