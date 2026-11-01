// End-to-end: fixture project → `plumb doctor` → output compared with
// test/goldens/. Uses the real bundled recipes, so a recipe change shows up
// here as a reviewable diff.
//
// Update after an intended change: UPDATE_GOLDENS=1 dart test test/doctor_golden_test.dart
import 'dart:io';

import 'package:plumb/src/cli/cli.dart';
import 'package:test/test.dart';

/// Fixture, extra flags, expected exit code.
const cases = [
  ('good_app', ['--strict'], 0),
  ('broken_app', ['--strict'], 1),
  ('edge_app', ['--strict'], 1),
  ('unreadable_app', <String>[], 2),
  ('ios_only_app', ['--strict'], 0),
  ('package_config_only_app', <String>[], 0),
];

final _update = Platform.environment['UPDATE_GOLDENS'] == '1';

Future<(int, String)> doctor(List<String> args) async {
  final out = StringBuffer();
  final code = await runCli([
    'doctor',
    ...args,
  ], console: Console(out: out, err: out));
  return (code, out.toString());
}

void expectGolden(String actual, String goldenName) {
  final file = File('test/goldens/$goldenName');
  if (_update) {
    file
      ..createSync(recursive: true)
      ..writeAsStringSync(actual);
    return;
  }
  expect(
    file.existsSync(),
    isTrue,
    reason: 'Missing golden; run with UPDATE_GOLDENS=1 to create it.',
  );
  expect(actual, file.readAsStringSync().replaceAll('\r\n', '\n'));
}

void main() {
  for (final (fixture, flags, exitCode) in cases) {
    group(fixture, () {
      final path = 'test/fixtures/$fixture';

      test('text output and exit code', () async {
        final (code, output) = await doctor([path, ...flags]);
        expectGolden(output, '$fixture.txt');
        expect(code, exitCode);
      });

      test('JSON output and exit code', () async {
        final (code, output) = await doctor([path, '--json', ...flags]);
        expectGolden(output, '$fixture.json');
        expect(code, exitCode);
      });
    });
  }

  test('broken_app --verbose lists every item', () async {
    final (_, output) = await doctor(['test/fixtures/broken_app', '--verbose']);
    expectGolden(output, 'broken_app.verbose.txt');
  });
}
