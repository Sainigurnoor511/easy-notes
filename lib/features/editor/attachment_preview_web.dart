import 'package:flutter/material.dart';

Future<int> attachmentFileSize(String path) async => 0;

Widget attachmentThumb(String path) => const Icon(Icons.broken_image_outlined);

Widget blockImagePreview(String path, Widget Function() hint) => hint();
