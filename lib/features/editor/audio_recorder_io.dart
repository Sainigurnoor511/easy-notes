import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../app/spacing.dart';

Future<void> deleteTemporaryRecording(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}

Future<String?> showAudioRecorder(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: true,
    builder: (_) => const _AudioRecorderSheet(),
  );
}

class _AudioRecorderSheet extends StatefulWidget {
  const _AudioRecorderSheet();

  @override
  State<_AudioRecorderSheet> createState() => _AudioRecorderSheetState();
}

class _AudioRecorderSheetState extends State<_AudioRecorderSheet> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;
  String? _path;
  Duration _elapsed = Duration.zero;
  bool _recording = false;
  bool _busy = false;

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required.')),
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      _path = p.join(
        dir.path,
        'easy_notes_recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _path!,
      );
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
      if (mounted) setState(() => _recording = true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Recording failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (!_recording || _busy) return;
    setState(() => _busy = true);
    _timer?.cancel();
    try {
      final result = await _recorder.stop();
      if (mounted) Navigator.pop(context, result ?? _path);
    } catch (error) {
      await _deleteSource();
      if (mounted) {
        setState(() {
          _recording = false;
          _busy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not stop recording: $error')),
        );
      }
    }
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    try {
      if (_recording) await _recorder.stop();
    } catch (_) {
      // Cleanup below still makes cancellation safe after a recorder failure.
    }
    await _deleteSource();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteSource() async {
    final path = _path;
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateFormat(
      'mm:ss',
    ).format(DateTime.utc(2000).add(_elapsed));
    return PopScope(
      canPop: !_recording,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.xl,
            Spacing.sm,
            Spacing.xl,
            Spacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _recording ? Symbols.graphic_eq : Symbols.mic,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: Spacing.md),
              Text(
                _recording ? elapsed : 'Record audio',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                _recording
                    ? 'Recording from this device microphone'
                    : 'The recording will be attached to this note.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _busy ? null : _cancel,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: Spacing.md),
                  FilledButton.icon(
                    onPressed: _busy ? null : (_recording ? _finish : _start),
                    icon: Icon(_recording ? Symbols.stop : Symbols.mic),
                    label: Text(
                      _recording ? 'Stop and attach' : 'Start recording',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
