import 'package:flutter/material.dart';

Future<void> deleteTemporaryRecording(String path) async {}

Future<String?> showAudioRecorder(BuildContext context) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Audio recording is unavailable on web.')),
  );
  return null;
}
