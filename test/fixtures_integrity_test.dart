import 'dart:io';

import 'package:test/test.dart';

/// Fixture lock files are handwritten (no sha256 lines) so tests and goldens
/// stay stable. If an IDE or `pub get` runs inside test/fixtures it rewrites
/// them; this test makes that obvious instead of producing confusing diffs.
void main() {
  final locks = Directory('test/fixtures')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('pubspec.lock'));

  for (final lock in locks) {
    test('${lock.path} is the handwritten fixture', () {
      expect(
        lock.readAsStringSync(),
        isNot(contains('sha256')),
        reason:
            'A tool ran `pub get` inside test/fixtures. Restore with '
            '`git checkout -- test/fixtures` and delete any .dart_tool/ there.',
      );
    });
  }
}
