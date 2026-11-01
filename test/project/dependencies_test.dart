import 'package:path/path.dart' as p;
import 'package:plumb/src/errors.dart';
import 'package:plumb/src/project/dependencies.dart';
import 'package:plumb/src/project/flutter_project.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

String fixture(String name) => p.absolute('test', 'fixtures', name);

Map<String, (Version?, DependencyKind)> byName(
  List<ResolvedPackage> packages,
) => {
  for (final package in packages) package.name: (package.version, package.kind),
};

void main() {
  group('parsePubspecLock', () {
    test('reads versions and dependency kinds', () {
      final packages = parsePubspecLock('''
packages:
  a: { dependency: "direct main", source: hosted, version: "1.2.3" }
  b: { dependency: "direct dev", source: hosted, version: "2.0.0" }
  c: { dependency: transitive, source: hosted, version: "0.1.0+4" }
  d: { dependency: "direct overridden", source: git, version: "3.0.0-dev.1" }
  e: { dependency: "direct main", source: sdk, version: "0.0.0" }
''');
      expect(byName(packages), {
        'a': (Version(1, 2, 3), DependencyKind.direct),
        'b': (Version(2, 0, 0), DependencyKind.dev),
        'c': (Version.parse('0.1.0+4'), DependencyKind.transitive),
        'd': (Version.parse('3.0.0-dev.1'), DependencyKind.direct),
        'e': (Version(0, 0, 0), DependencyKind.direct),
      });
    });

    test('an unparseable version becomes null', () {
      final packages = parsePubspecLock(
        'packages:\n  a: { dependency: transitive, version: "x" }',
      );
      expect(packages.single.version, isNull);
    });

    test('rejects a file without packages', () {
      expect(() => parsePubspecLock('sdks: {}'), throwsFormatException);
    });
  });

  group('parsePackageConfig', () {
    test('takes versions from hosted cache paths only', () {
      final packages = parsePackageConfig('''
{
  "configVersion": 2,
  "packages": [
    {"name": "a", "rootUri": "file:///cache/hosted/pub.dev/a-1.2.3", "packageUri": "lib/"},
    {"name": "b", "rootUri": "file:///cache/git/b-abcdef", "packageUri": "lib/"},
    {"name": "c", "rootUri": "../c", "packageUri": "lib/"}
  ]
}''', configUri: Uri.parse('file:///app/.dart_tool/package_config.json'));
      expect(byName(packages), {
        'a': (Version(1, 2, 3), DependencyKind.unknown),
        'b': (null, DependencyKind.unknown),
        'c': (null, DependencyKind.unknown),
      });
    });
  });

  group('resolveDependencies', () {
    test('prefers pubspec.lock and drops dev dependencies', () {
      final deps = resolveDependencies(findFlutterProject(fixture('good_app')));
      expect(deps.source, DependencySource.pubspecLock);
      final names = deps.packages.map((d) => d.name);
      expect(names, containsAll(['camera', 'camera_avfoundation', 'flutter']));
      expect(names, isNot(contains('flutter_lints')));
      expect(names, isNot(contains('flutter_test')));
    });

    test('reads the lock file at the workspace root', () {
      final project = findFlutterProject(
        p.join(fixture('workspace'), 'packages', 'app'),
      );
      final deps = resolveDependencies(project);
      expect(byName(deps.packages)['camera'], (
        Version(0, 11, 2),
        DependencyKind.transitive,
      ));
    });

    test('falls back to package_config.json, excluding the app itself', () {
      final deps = resolveDependencies(
        findFlutterProject(fixture('package_config_only_app')),
      );
      expect(deps.source, DependencySource.packageConfig);
      expect(byName(deps.packages), {
        'camera': (Version(0, 11, 2), DependencyKind.unknown),
        'local_plugin': (null, DependencyKind.unknown),
      });
    });

    test('asks to run flutter pub get when neither file exists', () {
      expect(
        () => resolveDependencies(findFlutterProject(fixture('no_lock_app'))),
        throwsA(
          isA<PlumbException>().having(
            (e) => e.message,
            'message',
            contains('flutter pub get'),
          ),
        ),
      );
    });
  });
}
