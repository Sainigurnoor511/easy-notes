import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

Future<int> attachmentFileSize(String path) async => 0;

Widget attachmentThumb(String path) => const Icon(Symbols.broken_image);

Widget blockImagePreview(String path, Widget Function() hint) => hint();
