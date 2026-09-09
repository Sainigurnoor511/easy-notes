/// Version arithmetic for the build bumper. Pure logic, no I/O, so it can be
/// unit-tested directly.
///
/// The scheme is a three-digit odometer: every component maxes out at 9 and
/// rolls into the next one.
///
///   0.0.1 -> 0.0.2 -> ... -> 0.0.9 -> 0.1.0 -> ... -> 0.9.9 -> 1.0.0
library;

/// Highest value any single component reaches before rolling over.
const int kMaxComponent = 9;

class AppVersion {
  final int major;
  final int minor;
  final int patch;

  /// The `+N` suffix. Monotonic: stores and `adb install` compare this, so it
  /// must never go backwards even when the semantic version rolls over.
  final int build;

  const AppVersion(this.major, this.minor, this.patch, this.build);

  static final RegExp _pattern =
      RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$');

  /// Returns null when [raw] isn't of the form `x.y.z` or `x.y.z+n`.
  static AppVersion? tryParse(String raw) {
    final match = _pattern.firstMatch(raw.trim());
    if (match == null) return null;
    return AppVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4) ?? '0'),
    );
  }

  AppVersion withBuild(int newBuild) =>
      AppVersion(major, minor, patch, newBuild);

  /// Advances the patch component, rolling into minor then major at 9.
  AppVersion bump() {
    var nextMajor = major;
    var nextMinor = minor;
    var nextPatch = patch + 1;

    if (nextPatch > kMaxComponent) {
      nextPatch = 0;
      nextMinor += 1;
    }
    if (nextMinor > kMaxComponent) {
      nextMinor = 0;
      nextMajor += 1;
    }
    return AppVersion(nextMajor, nextMinor, nextPatch, build + 1);
  }

  String get semantic => '$major.$minor.$patch';

  @override
  String toString() => '$semantic+$build';

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch &&
      other.build == build;

  @override
  int get hashCode => Object.hash(major, minor, patch, build);
}

/// Rewrites the `version:` line inside [pubspec], returning the new contents.
///
/// Throws [FormatException] when there's no parseable version line.
({String contents, AppVersion from, AppVersion to}) bumpPubspec(
  String pubspec, {
  AppVersion? setTo,
  bool buildOnly = false,
}) {
  final lines = pubspec.split('\n');
  final index = lines.indexWhere((l) => l.startsWith('version:'));
  if (index == -1) {
    throw const FormatException('no `version:` line in pubspec.yaml');
  }

  final raw = lines[index].substring('version:'.length).trim();
  final from = AppVersion.tryParse(raw);
  if (from == null) {
    throw FormatException('could not parse version "$raw"');
  }

  final to = setTo != null
      ? setTo.withBuild(from.build + 1)
      : buildOnly
          ? from.withBuild(from.build + 1)
          : from.bump();

  lines[index] = 'version: $to';
  return (contents: lines.join('\n'), from: from, to: to);
}
