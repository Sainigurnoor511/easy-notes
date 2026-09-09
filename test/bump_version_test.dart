import 'package:flutter_test/flutter_test.dart';

import '../tool/version.dart';

String _pubspec(String version) =>
    'name: easy_notes\nversion: $version\nenvironment:\n  sdk: ^3.7.2\n';

/// Bumps and returns the resulting version string.
String bump(String from, {AppVersion? setTo, bool buildOnly = false}) =>
    bumpPubspec(_pubspec(from), setTo: setTo, buildOnly: buildOnly)
        .to
        .toString();

void main() {
  group('odometer rollover', () {
    test('patch increments normally', () {
      expect(bump('0.0.1+1'), '0.0.2+2');
      expect(bump('1.2.3+40'), '1.2.4+41');
    });

    test('patch rolls into minor at 9', () {
      expect(bump('0.0.9+9'), '0.1.0+10');
      expect(bump('1.3.9+2'), '1.4.0+3');
    });

    test('minor rolls into major at 9', () {
      expect(bump('0.9.9+5'), '1.0.0+6');
      expect(bump('2.9.9+99'), '3.0.0+100');
    });

    test('no component ever exceeds 9', () {
      var v = AppVersion.tryParse('0.0.1+1')!;
      for (var i = 0; i < 500; i++) {
        v = v.bump();
        expect(v.patch, lessThanOrEqualTo(kMaxComponent));
        expect(v.minor, lessThanOrEqualTo(kMaxComponent));
      }
    });

    test('a walk from 0.0.1 reaches 1.0.0 after 99 bumps', () {
      var v = AppVersion.tryParse('0.0.1+1')!;
      final seen = <String>[];
      for (var i = 0; i < 99; i++) {
        v = v.bump();
        seen.add(v.semantic);
      }
      expect(seen.first, '0.0.2');
      expect(seen, contains('0.1.0'));
      expect(seen, contains('0.9.9'));
      expect(seen.last, '1.0.0');
    });

    test('the build number never goes backwards across a rollover', () {
      var v = AppVersion.tryParse('0.0.1+1')!;
      var previous = v.build;
      for (var i = 0; i < 200; i++) {
        v = v.bump();
        expect(v.build, greaterThan(previous));
        previous = v.build;
      }
    });
  });

  group('flags', () {
    test('--build-only leaves the semantic version alone', () {
      expect(bump('0.4.2+7', buildOnly: true), '0.4.2+8');
    });

    test('--set overrides but still advances the build', () {
      expect(bump('0.4.2+7', setTo: AppVersion.tryParse('2.0.0')), '2.0.0+8');
    });
  });

  group('parsing', () {
    test('accepts a bare semantic version', () {
      expect(AppVersion.tryParse('1.2.3'), const AppVersion(1, 2, 3, 0));
    });

    test('rejects junk', () {
      for (final bad in ['', 'x', '1.2', '1.2.3.4', '1.2.3+', 'v1.2.3']) {
        expect(AppVersion.tryParse(bad), isNull, reason: bad);
      }
    });

    test('throws when pubspec has no version line', () {
      expect(() => bumpPubspec('name: x\n'), throwsFormatException);
    });

    test('rewrites only the version line', () {
      final out = bumpPubspec(_pubspec('0.0.1+1')).contents;
      expect(out, contains('name: easy_notes'));
      expect(out, contains('version: 0.0.2+2'));
      expect(out, contains('sdk: ^3.7.2'));
    });
  });
}
