// Bumps the version in pubspec.yaml. See tool/version.dart for the arithmetic.
//
//   dart run tool/bump_version.dart              # bump patch (the normal case)
//   dart run tool/bump_version.dart --dry-run
//   dart run tool/bump_version.dart --build-only # only the +N build number
//   dart run tool/bump_version.dart --set 1.2.3
import 'dart:io';

import 'version.dart';

void main(List<String> args) {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) {
    stderr.writeln(
        'bump_version: pubspec.yaml not found — run this from the project root.');
    exit(2);
  }

  AppVersion? setTo;
  final setIndex = args.indexOf('--set');
  if (setIndex != -1) {
    if (setIndex + 1 >= args.length) {
      stderr.writeln('bump_version: --set needs a version, e.g. --set 1.2.3');
      exit(2);
    }
    setTo = AppVersion.tryParse(args[setIndex + 1]);
    if (setTo == null) {
      stderr.writeln('bump_version: --set expects x.y.z, '
          'got "${args[setIndex + 1]}"');
      exit(2);
    }
  }

  try {
    final result = bumpPubspec(
      file.readAsStringSync(),
      setTo: setTo,
      buildOnly: args.contains('--build-only'),
    );

    if (args.contains('--dry-run')) {
      stdout.writeln('${result.from} -> ${result.to}  (dry run)');
      return;
    }

    file.writeAsStringSync(result.contents);
    stdout.writeln('${result.from} -> ${result.to}');
  } on FormatException catch (e) {
    stderr.writeln('bump_version: ${e.message}');
    exit(2);
  }
}
