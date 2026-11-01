import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:plumb/src/project/dependencies.dart';
import 'package:plumb/src/project/flutter_project.dart';
import 'package:plumb/src/project/snapshot.dart';
import 'package:plumb/src/project/snapshot_loader.dart';
import 'package:test/test.dart';

ProjectSnapshot load(String fixture) =>
    loadSnapshot(findFlutterProject(p.absolute('test', 'fixtures', fixture)));

void main() {
  group('good_app', () {
    final snapshot = load('good_app');

    test('reads project facts and dependencies', () {
      expect(snapshot.name, 'good_app');
      expect(snapshot.dependencySource, DependencySource.pubspecLock);
      expect(snapshot.packages.map((d) => d.name), contains('camera'));
    });

    test('reads iOS files', () {
      final ios = snapshot.ios!;
      expect(ios.infoPlist.path, 'ios/Runner/Info.plist');
      expect(ios.infoPlist.value!['CFBundleName'], 'ref_app');
      expect(ios.entitlements.single.path, 'ios/Runner/Runner.entitlements');
      expect(ios.entitlements.single.value, {'aps-environment': 'development'});
      expect(ios.pbxproj, contains('INFOPLIST_FILE'));
      expect(ios.otherInfoPlists, isEmpty);
    });

    test('reads Android files and finds the Kotlin MainActivity', () {
      final android = snapshot.android!;
      expect(android.manifest.value!.launcherActivity, '.MainActivity');
      expect(
        android.mainActivitySource!.path,
        'android/app/src/main/kotlin/dev/example/good_app/MainActivity.kt',
      );
      expect(
        android.mainActivitySource!.value,
        contains('FlutterFragmentActivity'),
      );
    });

    test('does not report Flutter\'s standard debug manifest as a flavor', () {
      expect(snapshot.android!.otherManifests, isEmpty);
    });
  });

  group('edge_app', () {
    final snapshot = load('edge_app');

    test('lists every entitlements file, sorted', () {
      expect(snapshot.ios!.entitlements.map((e) => e.path), [
        'ios/Runner/RunnerDebug.entitlements',
        'ios/Runner/RunnerRelease.entitlements',
      ]);
    });

    test('lists flavor Info plists and manifests without reading them', () {
      expect(snapshot.ios!.otherInfoPlists, ['ios/Runner/Info-Staging.plist']);
      expect(snapshot.android!.otherManifests, [
        'android/app/src/staging/AndroidManifest.xml',
      ]);
    });

    test('finds a Java MainActivity', () {
      expect(
        snapshot.android!.mainActivitySource!.path,
        endsWith('java/dev/example/edge_app/MainActivity.java'),
      );
    });
  });

  test('unreadable_app records problems instead of throwing', () {
    final snapshot = load('unreadable_app');
    expect(snapshot.ios!.infoPlist.problem, FileProblem.binaryPlist);
    expect(snapshot.android!.manifest.problem, FileProblem.malformed);
    expect(snapshot.android!.manifest.detail, isNotEmpty);
    expect(snapshot.android!.mainActivitySource, isNull);
  });

  test('ios_only_app has no Android snapshot', () {
    final snapshot = load('ios_only_app');
    expect(snapshot.ios, isNotNull);
    expect(snapshot.android, isNull);
  });

  group('MainActivity lookup', () {
    late Directory temp;
    setUp(() {
      temp = Directory.systemTemp.createTempSync('plumb_snapshot_');
      final fixture = p.absolute('test', 'fixtures', 'good_app');
      for (final file in ['pubspec.yaml', 'pubspec.lock']) {
        File(p.join(fixture, file)).copySync(p.join(temp.path, file));
      }
      final manifestDir = Directory(
        p.join(temp.path, 'android', 'app', 'src', 'main'),
      )..createSync(recursive: true);
      File(
        p.join(fixture, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
      ).copySync(p.join(manifestDir.path, 'AndroidManifest.xml'));
    });
    tearDown(() => temp.deleteSync(recursive: true));

    void writeActivity(String relative) {
      File(
          p.joinAll([
            temp.path,
            'android',
            'app',
            'src',
            'main',
            ...relative.split('/'),
          ]),
        )
        ..createSync(recursive: true)
        ..writeAsStringSync('class MainActivity : FlutterActivity()');
    }

    AndroidFiles android() =>
        loadSnapshot(findFlutterProject(temp.path)).android!;

    test('missing source is recorded', () {
      expect(android().mainActivitySource!.problem, FileProblem.missing);
    });

    test('two candidates are ambiguous', () {
      writeActivity('kotlin/a/MainActivity.kt');
      writeActivity('java/b/MainActivity.java');
      final source = android().mainActivitySource!;
      expect(source.problem, FileProblem.ambiguous);
      expect(
        source.detail,
        allOf(contains('a/MainActivity.kt'), contains('b/MainActivity.java')),
      );
    });
  });
}
