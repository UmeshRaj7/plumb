import 'package:plumb/src/checks/finding.dart';
import 'package:plumb/src/checks/ios_checks.dart';
import 'package:plumb/src/project/snapshot.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Checks the first requirement of a recipe with [body] against [ios].
Finding? check(String body, IosFiles ios) {
  final recipe = demoRecipe(body);
  return checkIosRequirement(recipe.requirements.single, recipe, ios);
}

const cameraRequired = '''
ios:
  info_plist:
    NSCameraUsageDescription: { required: true, hint: "Explain camera use" }
''';
const cameraWhenUsed = '''
ios:
  info_plist:
    NSCameraUsageDescription: { required: when_used, hint: "Only for video" }
''';

void main() {
  group('info_plist', () {
    test('present and meaningful → ok, no fix', () {
      final f = check(
        cameraRequired,
        iosFiles({'NSCameraUsageDescription': 'Scan receipts'}),
      )!;
      expect(f.severity, Severity.ok);
      expect(f.fix, isNull);
      expect(f.id, 'demo/ios/info_plist/NSCameraUsageDescription');
      expect(f.file, 'ios/Runner/Info.plist');
      expect(f.source, 'https://pub.dev/packages/demo');
    });

    test('required and absent → missing with the hint as fix', () {
      final f = check(cameraRequired, iosFiles({}))!;
      expect(f.severity, Severity.missing);
      expect(f.message, 'NSCameraUsageDescription is missing');
      expect(f.fix, 'Explain camera use');
    });

    test('when_used and absent → info', () {
      expect(check(cameraWhenUsed, iosFiles({}))!.severity, Severity.info);
    });

    test('placeholder → warning, even when only conditionally needed', () {
      final f = check(
        cameraWhenUsed,
        iosFiles({'NSCameraUsageDescription': 'TODO'}),
      )!;
      expect(f.severity, Severity.warning);
      expect(f.message, contains('placeholder'));
    });

    test('build variable → ok with a note', () {
      final f = check(
        cameraRequired,
        iosFiles({'NSCameraUsageDescription': r'$(CAMERA_TEXT)'}),
      )!;
      expect(f.severity, Severity.ok);
      expect(f.message, contains('build variable'));
    });

    test(
      'purpose string with a non-string value → warning (implicit string type)',
      () {
        final f = check(
          cameraRequired,
          iosFiles({'NSCameraUsageDescription': true}),
        )!;
        expect(f.severity, Severity.warning);
        expect(f.message, contains('should be of type string'));
      },
    );

    test('expect_type mismatch → warning', () {
      final f = check('''
ios:
  info_plist:
    LSApplicationQueriesSchemes: { required: true, hint: h, expect_type: array }
''', iosFiles({'LSApplicationQueriesSchemes': 'sms'}))!;
      expect(f.severity, Severity.warning);
      expect(f.message, contains('should be of type array, found string'));
    });

    test(
      'absent but set as INFOPLIST_KEY_ build setting → info, never missing',
      () {
        final f = check(
          cameraRequired,
          iosFiles(
            {},
            pbxproj: 'INFOPLIST_KEY_NSCameraUsageDescription = "Scan";',
          ),
        )!;
        expect(f.severity, Severity.info);
        expect(f.file, 'ios/Runner.xcodeproj/project.pbxproj');
        expect(f.fix, contains('GENERATE_INFOPLIST_FILE'));
      },
    );

    test('unreadable Info.plist → null (reported once at app level)', () {
      final ios = IosFiles(
        infoPlist: const FileRead.failed(
          'ios/Runner/Info.plist',
          FileProblem.binaryPlist,
        ),
      );
      expect(check(cameraRequired, ios), isNull);
    });
  });

  group('background_modes', () {
    const body = '''
ios:
  background_modes:
    remote-notification: { required: true, hint: "Enable Remote notifications" }
''';

    test('listed → ok', () {
      final f = check(
        body,
        iosFiles({
          'UIBackgroundModes': ['fetch', 'remote-notification'],
        }),
      )!;
      expect(f.severity, Severity.ok);
    });

    test('not listed → missing', () {
      final f = check(
        body,
        iosFiles({
          'UIBackgroundModes': ['fetch'],
        }),
      )!;
      expect(f.severity, Severity.missing);
      expect(
        f.message,
        'UIBackgroundModes does not include remote-notification',
      );
    });

    test('no UIBackgroundModes at all → missing', () {
      expect(check(body, iosFiles({}))!.severity, Severity.missing);
    });
  });

  group('entitlements', () {
    const body = '''
ios:
  entitlements:
    aps-environment: { required: true, hint: "Enable Push Notifications" }
''';

    test('in the only file → ok', () {
      final f = check(
        body,
        iosFiles(
          {},
          entitlements: [
            entitlementsFile('Runner.entitlements', {
              'aps-environment': 'development',
            }),
          ],
        ),
      )!;
      expect(f.severity, Severity.ok);
      expect(f.file, 'ios/Runner/Runner.entitlements');
    });

    test('no entitlements file → missing', () {
      final f = check(body, iosFiles({}))!;
      expect(f.severity, Severity.missing);
      expect(f.message, contains('No .entitlements file'));
    });

    test('in some files only → warning naming the others', () {
      final f = check(
        body,
        iosFiles(
          {},
          entitlements: [
            entitlementsFile('RunnerDebug.entitlements', {
              'aps-environment': 'development',
            }),
            entitlementsFile('RunnerRelease.entitlements', {}),
          ],
        ),
      )!;
      expect(f.severity, Severity.warning);
      expect(f.message, contains('not in RunnerRelease.entitlements'));
    });

    test('in no file → missing', () {
      final f = check(
        body,
        iosFiles(
          {},
          entitlements: [entitlementsFile('Runner.entitlements', {})],
        ),
      )!;
      expect(f.severity, Severity.missing);
    });

    test('an unreadable entitlements file → null', () {
      final ios = iosFiles(
        {},
        entitlements: [
          const FileRead.failed(
            'ios/Runner/Runner.entitlements',
            FileProblem.malformed,
            'bad',
          ),
        ],
      );
      expect(check(body, ios), isNull);
    });
  });

  test('manual → info with the hint as fix', () {
    final f = check('''
ios:
  manual:
    - { id: appdelegate-key, required: true, hint: "Call GMSServices.provideAPIKey in AppDelegate" }
''', iosFiles({}))!;
    expect(f.severity, Severity.info);
    expect(f.message, contains('(required)'));
    expect(f.fix, contains('GMSServices'));
    expect(f.file, isNull);
  });

  test('a per-item source overrides the recipe source', () {
    final f = check('''
ios:
  info_plist:
    K: { required: true, hint: h, source: "https://developer.apple.com/k" }
''', iosFiles({}))!;
    expect(f.source, 'https://developer.apple.com/k');
  });
}
