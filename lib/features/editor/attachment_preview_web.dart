import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

Future<int> attachmentFileSize(String path) async => 0;

Widget attachmentImage(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(8)),
}) => SizedBox(
  width: width,
  height: height,
  child: const Center(child: Icon(Symbols.broken_image)),
);

Widget attachmentThumb(String path) =>
    const SizedBox(width: 40, height: 40, child: Icon(Symbols.broken_image));

Widget blockImagePreview(String path, Widget Function() hint) => hint();
