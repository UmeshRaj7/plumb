import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:plumb/src/errors.dart';
import 'package:plumb/src/project/flutter_project.dart';
import 'package:test/test.dart';

String fixture(String name) => p.absolute('test', 'fixtures', name);

Matcher throwsPlumb(String messagePart) => throwsA(
  isA<PlumbException>().having(
    (e) => e.message,
    'message',
    contains(messagePart),
  ),
);

void main() {
  group('findFlutterProject', () {
    test('finds an app from its root', () {
      final project = findFlutterProject(fixture('good_app'));
      expect(project.name, 'good_app');
      expect(project.root, fixture('good_app'));
      expect(project.resolutionRoot, project.root);
    });

    test('walks up from a subdirectory', () {
      final project = findFlutterProject(
        p.join(fixture('good_app'), 'ios', 'Runner'),
      );
      expect(project.root, fixture('good_app'));
    });

    test('uses the workspace root for resolution', () {
      final project = findFlutterProject(
        p.join(fixture('workspace'), 'packages', 'app'),
      );
      expect(project.name, 'workspace_app');
      expect(project.resolutionRoot, fixture('workspace'));
    });

    test('rejects a plugin package and points to example/', () {
      expect(
        () => findFlutterProject(fixture('plugin_package')),
        throwsPlumb('example/'),
      );
    });

    test('rejects a plain Dart package', () {
      expect(
        () => findFlutterProject(fixture('dart_package')),
        throwsPlumb('not a Flutter app'),
      );
    });

    test('rejects a missing directory', () {
      expect(
        () => findFlutterProject(fixture('does_not_exist')),
        throwsPlumb('Directory not found'),
      );
    });

    test('rejects a directory with no pubspec.yaml above it', () {
      final temp = Directory.systemTemp.createTempSync('plumb_test_');
      addTearDown(() => temp.deleteSync(recursive: true));
      expect(
        () => findFlutterProject(temp.path),
        throwsPlumb('No pubspec.yaml'),
      );
    });
  });

  group('parsePubspec', () {
    test('rejects YAML without a name', () {
      expect(() => parsePubspec('version: 1.0.0'), throwsFormatException);
    });

    test('rejects invalid YAML', () {
      expect(() => parsePubspec('name: [unclosed'), throwsFormatException);
    });

    test('a flutter dependency that is not the SDK does not count', () {
      final info = parsePubspec('name: x\ndependencies:\n  flutter: ^1.0.0');
      expect(info.dependsOnFlutter, isFalse);
    });
  });

  group('plumb.ignore in pubspec.yaml', () {
    test('reads finding ids and trimmed reasons', () {
      final info = parsePubspec('''
name: x
plumb:
  ignore:
    local_auth/ios/info_plist/NSFaceIDUsageDescription: " Set in Info-Release.plist "
''');
      expect(info.ignore, {
        'local_auth/ios/info_plist/NSFaceIDUsageDescription':
            'Set in Info-Release.plist',
      });
    });

    test('is empty without a plumb section', () {
      expect(parsePubspec('name: x').ignore, isEmpty);
    });

    for (final (name, yaml, message) in [
      (
        'a reason is missing',
        'plumb:\n  ignore:\n    some/id:',
        'needs a reason',
      ),
      (
        'a reason is blank',
        'plumb:\n  ignore:\n    some/id: "  "',
        'needs a reason',
      ),
      (
        'ignore is a list',
        'plumb:\n  ignore:\n    - some/id',
        'must map finding ids',
      ),
      (
        'plumb has an unknown key',
        'plumb:\n  ignored: {}',
        'Unknown key `plumb.ignored`',
      ),
      ('plumb is not a map', 'plumb: yes', 'must be a map'),
    ]) {
      test('rejects it when $name', () {
        expect(
          () => parsePubspec('name: x\n$yaml'),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains(message),
            ),
          ),
        );
      });
    }
  });
}
