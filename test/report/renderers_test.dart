import 'dart:convert';

import 'package:plumb/src/checks/doctor_report.dart';
import 'package:plumb/src/checks/finding.dart';
import 'package:plumb/src/project/dependencies.dart';
import 'package:plumb/src/recipes/recipe.dart';
import 'package:plumb/src/report/json_renderer.dart';
import 'package:plumb/src/report/text_renderer.dart';
import 'package:plumb/src/version.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

final report = DoctorReport(
  projectName: 'my_app',
  dependencySource: DependencySource.pubspecLock,
  packages: [
    CheckedPackage(
      name: 'geolocator',
      version: Version(14, 1, 2),
      status: PackageStatus.checked,
      recipe: 'recipes/geolocator.yaml',
    ),
    CheckedPackage(
      name: 'old_plugin',
      version: Version(1, 0, 0),
      status: PackageStatus.versionNotCovered,
    ),
  ],
  findings: const [
    Finding(
      id: 'app/ios/info_plist/NSContactsUsageDescription',
      severity: Severity.warning,
      platform: NativePlatform.ios,
      file: 'ios/Runner/Info.plist',
      key: 'NSContactsUsageDescription',
      message: 'NSContactsUsageDescription looks like a placeholder: "TODO"',
      fix: 'Replace it.',
      source: 'https://developer.apple.com/x',
    ),
    Finding(
      id: 'geolocator/android/permissions/android.permission.ACCESS_COARSE_LOCATION',
      severity: Severity.ok,
      package: 'geolocator',
      platform: NativePlatform.android,
      file: 'android/app/src/main/AndroidManifest.xml',
      key: 'android.permission.ACCESS_COARSE_LOCATION',
      message: 'android.permission.ACCESS_COARSE_LOCATION is declared',
      source: 'https://pub.dev/packages/geolocator',
    ),
    Finding(
      id: 'geolocator/ios/info_plist/NSLocationWhenInUseUsageDescription',
      severity: Severity.missing,
      package: 'geolocator',
      platform: NativePlatform.ios,
      file: 'ios/Runner/Info.plist',
      key: 'NSLocationWhenInUseUsageDescription',
      message: 'NSLocationWhenInUseUsageDescription is missing',
      fix: 'Explain why you need location.',
      source: 'https://pub.dev/packages/geolocator',
    ),
    Finding(
      id: 'geolocator/android/permissions/android.permission.ACCESS_BACKGROUND_LOCATION',
      severity: Severity.info,
      package: 'geolocator',
      platform: NativePlatform.android,
      file: 'android/app/src/main/AndroidManifest.xml',
      key: 'android.permission.ACCESS_BACKGROUND_LOCATION',
      message: 'android.permission.ACCESS_BACKGROUND_LOCATION is not declared',
      fix: 'Only for background updates.',
      source: 'https://pub.dev/packages/geolocator',
    ),
    Finding(
      id: 'old_plugin/recipe',
      severity: Severity.info,
      package: 'old_plugin',
      message:
          'No recipe for old_plugin 1.0.0 (recipes cover >=2.0.0), so it was not checked',
      source: 'https://pub.dev/packages/old_plugin',
    ),
  ],
);

void main() {
  group('renderText', () {
    test('lists findings per package and collapses conditional items', () {
      expect(renderText(report), '''
plumb doctor · my_app
Found 2 plugins with recipes (read from pubspec.lock).

Your app
  ⚠ ios      Info.plist  NSContactsUsageDescription looks like a placeholder: "TODO"
                         fix:  Replace it.
                         docs: https://developer.apple.com/x

geolocator 14.1.2
  ✓ android  AndroidManifest.xml  android.permission.ACCESS_COARSE_LOCATION is declared
  ✗ ios      Info.plist           NSLocationWhenInUseUsageDescription is missing
                                  fix:  Explain why you need location.
                                  docs: https://pub.dev/packages/geolocator
  ℹ 1 conditional item (run with --verbose to list)

old_plugin 1.0.0
  ℹ No recipe for old_plugin 1.0.0 (recipes cover >=2.0.0), so it was not checked
    docs: https://pub.dev/packages/old_plugin

Summary: 1 ok · 1 missing · 1 warning · 2 info
''');
    });

    test('--verbose lists conditional items with their fix', () {
      final text = renderText(report, verbose: true);
      expect(text, contains('ACCESS_BACKGROUND_LOCATION is not declared'));
      expect(text, contains('fix:  Only for background updates.'));
      expect(text, isNot(contains('--verbose')));
    });

    test('color wraps symbols in ANSI codes only when enabled', () {
      expect(renderText(report), isNot(contains('\x1B[')));
      expect(renderText(report, color: true), contains('\x1B[31m✗\x1B[0m'));
    });

    test('says so when no dependency has a recipe', () {
      final empty = DoctorReport(
        projectName: 'my_app',
        dependencySource: DependencySource.packageConfig,
        packages: const [],
        findings: const [],
      );
      expect(
        renderText(empty),
        contains(
          'None of your dependencies has a bundled recipe (read from .dart_tool/package_config.json).',
        ),
      );
    });
  });

  group('renderJson', () {
    final json = jsonDecode(renderJson(report)) as Map<String, Object?>;

    test('has the documented top-level shape', () {
      expect(json.keys, [
        'format',
        'plumb_version',
        'project',
        'packages',
        'findings',
        'summary',
      ]);
      expect(json['format'], 1);
      expect(json['plumb_version'], packageVersion);
      expect(json['project'], {
        'name': 'my_app',
        'dependency_source': 'pubspec.lock',
      });
    });

    test('lists packages with snake_case status', () {
      expect(json['packages'], [
        {
          'name': 'geolocator',
          'version': '14.1.2',
          'status': 'checked',
          'recipe': 'recipes/geolocator.yaml',
        },
        {
          'name': 'old_plugin',
          'version': '1.0.0',
          'status': 'version_not_covered',
          'recipe': null,
        },
      ]);
    });

    test(
      'includes every finding (nothing collapsed) with every key present',
      () {
        final findings = json['findings'] as List<Object?>;
        expect(findings, hasLength(5));
        for (final finding in findings.cast<Map<String, Object?>>()) {
          expect(finding.keys, [
            'id',
            'severity',
            'package',
            'platform',
            'file',
            'key',
            'message',
            'fix',
            'source',
            'also_needed_by',
          ]);
        }
        expect((findings[2] as Map)['severity'], 'missing');
      },
    );

    test('summary counts every severity', () {
      expect(json['summary'], {
        'error': 0,
        'missing': 1,
        'warning': 1,
        'ok': 1,
        'info': 2,
      });
    });

    test('setup errors are JSON too', () {
      expect(jsonDecode(renderJsonError('not a Flutter app')), {
        'format': 1,
        'plumb_version': packageVersion,
        'error': 'not a Flutter app',
      });
    });
  });
}
