import 'package:plumb/src/checks/doctor_checks.dart';
import 'package:plumb/src/checks/doctor_report.dart';
import 'package:plumb/src/checks/finding.dart';
import 'package:plumb/src/exit_codes.dart';
import 'package:plumb/src/project/dependencies.dart';
import 'package:plumb/src/project/snapshot.dart';
import 'package:plumb/src/recipes/recipe.dart';
import 'package:plumb/src/recipes/recipe_index.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'helpers.dart';

final _recipe = demoRecipe('''
ios:
  info_plist:
    NSCameraUsageDescription: { required: true, hint: "Explain camera use" }
android:
  permissions:
    android.permission.CAMERA: { required: true, hint: "Declare CAMERA" }
''');

ProjectSnapshot snapshot({
  String version = '1.2.0',
  IosFiles? ios,
  AndroidFiles? android,
  bool includeDemo = true,
}) => ProjectSnapshot(
  name: 'app',
  root: '/tmp/app',
  dependencySource: DependencySource.pubspecLock,
  packages: [
    const ResolvedPackage('zzz_no_recipe', null, DependencyKind.direct),
    if (includeDemo)
      ResolvedPackage('demo', Version.parse(version), DependencyKind.direct),
  ],
  ios: ios,
  android: android,
);

DoctorReport run(ProjectSnapshot s) => runChecks(s, RecipeIndex([_recipe]));

List<(String, Severity)> idsAndSeverities(DoctorReport report) => [
  for (final f in report.findings) (f.id, f.severity),
];

void main() {
  test('applies a matching recipe to both platforms, in recipe order', () {
    final report = run(
      snapshot(
        ios: iosFiles({'NSCameraUsageDescription': 'Scan receipts'}),
        android: androidFiles(''),
      ),
    );
    expect(idsAndSeverities(report), [
      ('demo/ios/info_plist/NSCameraUsageDescription', Severity.ok),
      ('demo/android/permissions/android.permission.CAMERA', Severity.missing),
    ]);
    expect(report.packages.single.status, PackageStatus.checked);
    expect(report.packages.single.recipe, 'demo.yaml');
  });

  test('packages without recipes are not listed', () {
    final report = run(snapshot(includeDemo: false, ios: iosFiles({})));
    expect(report.packages, isEmpty);
    expect(report.findings, isEmpty);
  });

  test('an uncovered version is reported as info and not checked', () {
    final report = run(snapshot(version: '2.0.0', ios: iosFiles({})));
    expect(idsAndSeverities(report), [('demo/recipe', Severity.info)]);
    expect(report.findings.single.message, contains('>=1.0.0 <2.0.0'));
    expect(report.packages.single.status, PackageStatus.versionNotCovered);
  });

  test(
    'a missing platform directory is one info finding, not one per item',
    () {
      final report = run(
        snapshot(ios: iosFiles({'NSCameraUsageDescription': 'Scan'})),
      );
      expect(idsAndSeverities(report), [
        ('app/android/directory', Severity.info),
        ('demo/ios/info_plist/NSCameraUsageDescription', Severity.ok),
      ]);
      expect(report.findings.first.message, contains('demo'));
    },
  );

  test('an unreadable Info.plist is one error and skips its checks', () {
    final report = run(
      snapshot(
        ios: const IosFiles(
          infoPlist: FileRead.failed(
            'ios/Runner/Info.plist',
            FileProblem.binaryPlist,
          ),
        ),
        android: androidFiles(
          '<uses-permission android:name="android.permission.CAMERA"/>',
        ),
      ),
    );
    expect(idsAndSeverities(report), [
      ('app/ios/file/ios/Runner/Info.plist', Severity.error),
      ('demo/android/permissions/android.permission.CAMERA', Severity.ok),
    ]);
    expect(report.findings.first.fix, contains('plutil -convert xml1'));
  });

  group('app-level purpose strings', () {
    test('placeholders are flagged even without a recipe', () {
      final report = run(
        snapshot(
          includeDemo: false,
          ios: iosFiles({
            'NSMicrophoneUsageDescription': 'TODO',
            'NSContactsUsageDescription': 'Find friends who use the app',
          }),
        ),
      );
      expect(idsAndSeverities(report), [
        ('app/ios/info_plist/NSMicrophoneUsageDescription', Severity.warning),
      ]);
    });

    test('keys checked by a recipe are not reported twice', () {
      final report = run(
        snapshot(ios: iosFiles({'NSCameraUsageDescription': ''})),
      );
      final ids = report.findings.map((f) => f.id).toList();
      expect(ids, contains('demo/ios/info_plist/NSCameraUsageDescription'));
      expect(
        ids,
        isNot(contains('app/ios/info_plist/NSCameraUsageDescription')),
      );
    });
  });

  test('the same observation from two recipes is one finding', () {
    final other = demoRecipe('''
ios:
  info_plist:
    NSCameraUsageDescription: { required: true, hint: "Other hint" }
''');
    final both = runChecks(
      ProjectSnapshot(
        name: 'app',
        root: '/tmp/app',
        dependencySource: DependencySource.pubspecLock,
        packages: [
          ResolvedPackage('demo', Version(1, 0, 0), DependencyKind.direct),
          ResolvedPackage('other', Version(1, 0, 0), DependencyKind.direct),
        ],
        ios: iosFiles({'NSCameraUsageDescription': 'TODO'}),
      ),
      RecipeIndex([
        _recipe,
        Recipe(
          package: 'other',
          versions: other.versions,
          source: other.source,
          origin: 'other.yaml',
          requirements: other.requirements,
        ),
      ]),
    );
    final warnings = both.findings.where((f) => f.severity == Severity.warning);
    expect(warnings, hasLength(1));
    expect(warnings.single.package, 'demo');
    expect(warnings.single.alsoNeededBy, ['other']);
    expect(both.summary[Severity.warning], 1);
  });

  test('flavor files are listed as info', () {
    final report = run(
      snapshot(
        includeDemo: false,
        ios: const IosFiles(
          infoPlist: FileRead.ok('ios/Runner/Info.plist', {}),
          otherInfoPlists: ['ios/Runner/Info-Staging.plist'],
        ),
      ),
    );
    expect(idsAndSeverities(report), [('app/ios/flavors', Severity.info)]);
  });

  group('exit codes', () {
    DoctorReport reportWith(List<Severity> severities) => DoctorReport(
      projectName: 'app',
      dependencySource: DependencySource.pubspecLock,
      packages: const [],
      findings: [
        for (final s in severities)
          Finding(id: s.name, severity: s, message: 'm'),
      ],
    );

    test('info and ok never fail', () {
      expect(
        reportWith([Severity.ok, Severity.info]).exitCode(strict: true),
        ExitCodes.ok,
      );
    });

    test('missing fails only with --strict', () {
      final report = reportWith([Severity.missing]);
      expect(report.exitCode(strict: false), ExitCodes.ok);
      expect(report.exitCode(strict: true), ExitCodes.findings);
    });

    test('warning fails with --strict', () {
      expect(
        reportWith([Severity.warning]).exitCode(strict: true),
        ExitCodes.findings,
      );
    });

    test('error is exit 2 with or without --strict, and wins over 1', () {
      final report = reportWith([Severity.missing, Severity.error]);
      expect(report.exitCode(strict: false), ExitCodes.incomplete);
      expect(report.exitCode(strict: true), ExitCodes.incomplete);
    });

    test('summary counts every severity', () {
      expect(reportWith([Severity.ok, Severity.ok, Severity.info]).summary, {
        Severity.error: 0,
        Severity.missing: 0,
        Severity.warning: 0,
        Severity.ok: 2,
        Severity.info: 1,
      });
    });
  });
}
