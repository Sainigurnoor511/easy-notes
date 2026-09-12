import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

Future<int> attachmentFileSize(String path) => File(path).length();

Widget attachmentImage(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(8)),
}) {
  final file = File(path);
  return FutureBuilder<bool>(
    future: file.exists(),
    builder: (context, snapshot) {
      if (snapshot.data == true) {
        return ClipRRect(
          borderRadius: borderRadius,
          child: Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            errorBuilder:
                (_, __, ___) => const Center(child: Icon(Symbols.broken_image)),
          ),
        );
      }
      return const Center(child: Icon(Symbols.broken_image));
    },
  );
}

Widget blockImagePreview(String path, Widget Function() hint) {
  if (path.isEmpty) return hint();
  return SizedBox(
    height: 180,
    child: attachmentImage(path, width: double.infinity, height: 180),
  );
}

Widget attachmentThumb(String path) =>
    attachmentImage(path, width: 40, height: 40);
