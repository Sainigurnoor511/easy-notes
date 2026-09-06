import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

Future<int> attachmentFileSize(String path) => File(path).length();

Widget blockImagePreview(String path, Widget Function() hint) {
  if (path.isEmpty) return hint();
  return FutureBuilder<bool>(
    future: File(path).exists(),
    builder: (context, snap) {
      if (snap.data == true) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(File(path),
              fit: BoxFit.cover, height: 180, errorBuilder: (_, __, ___) => hint()),
        );
      }
      return hint();
    },
  );
}

Widget attachmentThumb(String path) {
  final file = File(path);
  return FutureBuilder<bool>(
    future: file.exists(),
    builder: (context, snap) {
      if (snap.data == true) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.file(
            file,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Symbols.broken_image),
          ),
        );
      }
      return const Icon(Symbols.broken_image);
    },
  );
}
