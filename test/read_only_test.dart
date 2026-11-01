// plumb v0.0.1's core promise: it never writes to the project it inspects.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:plumb/src/cli/cli.dart';
import 'package:test/test.dart';

/// Every file under [root] (relative path → bytes).
Map<String, List<int>> tree(Directory root) => {
  for (final entity in root.listSync(recursive: true))
    if (entity is File)
      p.relative(entity.path, from: root.path): entity.readAsBytesSync(),
};

void copyDirectory(Directory from, Directory to) {
  for (final entity in from.listSync(recursive: true)) {
    final target = p.join(to.path, p.relative(entity.path, from: from.path));
    if (entity is Directory) {
      Directory(target).createSync(recursive: true);
    } else if (entity is File) {
      File(target).parent.createSync(recursive: true);
      entity.copySync(target);
    }
  }
}

void main() {
  for (final fixture in ['broken_app', 'unreadable_app', 'edge_app']) {
    test('doctor leaves $fixture byte-for-byte unchanged', () async {
      final temp = Directory.systemTemp.createTempSync('plumb_read_only_');
      addTearDown(() => temp.deleteSync(recursive: true));
      copyDirectory(Directory(p.join('test', 'fixtures', fixture)), temp);
      final before = tree(temp);

      for (final flags in [
        <String>[],
        ['--json'],
        ['--strict', '--verbose'],
      ]) {
        await runCli([
          'doctor',
          temp.path,
          ...flags,
        ], console: Console(out: StringBuffer(), err: StringBuffer()));
      }

      expect(tree(temp), before);
    });
  }
}
