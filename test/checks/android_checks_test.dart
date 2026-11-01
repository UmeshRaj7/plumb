import 'package:plumb/src/checks/android_checks.dart';
import 'package:plumb/src/checks/finding.dart';
import 'package:plumb/src/project/snapshot.dart';
import 'package:test/test.dart';

import 'helpers.dart';

Finding? check(String body, AndroidFiles android) {
  final recipe = demoRecipe(body);
  return checkAndroidRequirement(recipe.requirements.single, recipe, android);
}

const coarseLocation = '''
android:
  permissions:
    android.permission.ACCESS_COARSE_LOCATION: { required: true, hint: "Add the permission" }
''';

void main() {
  group('permissions', () {
    test('declared → ok', () {
      final f = check(
        coarseLocation,
        androidFiles(
          '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>',
        ),
      )!;
      expect(f.severity, Severity.ok);
      expect(f.file, 'android/app/src/main/AndroidManifest.xml');
      expect(
        f.id,
        'demo/android/permissions/android.permission.ACCESS_COARSE_LOCATION',
      );
    });

    test('absent → missing', () {
      expect(
        check(coarseLocation, androidFiles(''))!.severity,
        Severity.missing,
      );
    });

    test('removed with tools:node="remove" → missing, says so', () {
      final f = check(
        coarseLocation,
        androidFiles(
          '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" tools:node="remove"/>',
        ),
      )!;
      expect(f.severity, Severity.missing);
      expect(f.message, contains('tools:node="remove"'));
    });

    test('when_used and absent → info', () {
      final f = check('''
android:
  permissions:
    android.permission.ACCESS_BACKGROUND_LOCATION: { required: when_used, hint: "Background updates only" }
''', androidFiles(''))!;
      expect(f.severity, Severity.info);
    });

    test('unreadable manifest → null', () {
      const android = AndroidFiles(
        manifest: FileRead.failed(
          'android/app/src/main/AndroidManifest.xml',
          FileProblem.malformed,
          'x',
        ),
      );
      expect(check(coarseLocation, android), isNull);
    });
  });

  group('queries', () {
    const tabs = '''
android:
  queries:
    - { intent: { action: android.support.customtabs.action.CustomTabsService }, required: true, hint: h }
''';
    const https = '''
android:
  queries:
    - { intent: { action: android.intent.action.VIEW, scheme: https }, required: true, hint: h }
''';

    test('matching intent → ok', () {
      final f = check(
        tabs,
        androidFiles(
          '<queries><intent><action android:name="android.support.customtabs.action.CustomTabsService"/></intent></queries>',
        ),
      )!;
      expect(f.severity, Severity.ok);
    });

    test('intent with the action but another scheme → missing', () {
      final f = check(
        https,
        androidFiles(
          '<queries><intent><action android:name="android.intent.action.VIEW"/><data android:scheme="sms"/></intent></queries>',
        ),
      )!;
      expect(f.severity, Severity.missing);
      expect(f.key, 'intent:android.intent.action.VIEW scheme=https');
    });

    test('package query → ok', () {
      final f = check(
        '''
android:
  queries:
    - { package: com.example.other, required: true, hint: h }
''',
        androidFiles(
          '<queries><package android:name="com.example.other"/></queries>',
        ),
      )!;
      expect(f.severity, Severity.ok);
    });
  });

  group('manifest_meta_data', () {
    const apiKey = '''
android:
  manifest_meta_data:
    com.google.android.geo.API_KEY: { required: true, hint: "Add your Maps API key" }
''';
    Finding withValue(String attributes) => check(
      apiKey,
      androidFiles(
        '<application><meta-data android:name="com.google.android.geo.API_KEY" $attributes/></application>',
      ),
    )!;

    test(
      'real value → ok',
      () => expect(
        withValue('android:value="AIzaSyExample"').severity,
        Severity.ok,
      ),
    );

    test('README placeholder → warning', () {
      final f = withValue('android:value="YOUR KEY HERE"');
      expect(f.severity, Severity.warning);
      expect(f.message, contains('placeholder'));
    });

    test('manifest placeholder from Gradle → ok with note', () {
      final f = withValue(r'android:value="${MAPS_API_KEY}"');
      expect(f.severity, Severity.ok);
      expect(f.message, contains('build variable'));
    });

    test(
      'no value → warning',
      () => expect(withValue('').severity, Severity.warning),
    );

    test(
      'absent → missing',
      () => expect(
        check(apiKey, androidFiles('<application/>'))!.severity,
        Severity.missing,
      ),
    );
  });

  group('components', () {
    const receiver = '''
android:
  components:
    com.example.Receiver: { kind: receiver, required: when_used, hint: "Needed for scheduled notifications" }
''';

    test('declared with the right kind → ok', () {
      final f = check(
        receiver,
        androidFiles(
          '<application><receiver android:name="com.example.Receiver"/></application>',
        ),
      )!;
      expect(f.severity, Severity.ok);
    });

    test('declared as another kind → not counted', () {
      final f = check(
        receiver,
        androidFiles(
          '<application><service android:name="com.example.Receiver"/></application>',
        ),
      )!;
      expect(f.severity, Severity.info);
    });

    test('absent and when_used → info', () {
      expect(
        check(receiver, androidFiles('<application/>'))!.severity,
        Severity.info,
      );
    });
  });

  group('activity_class', () {
    const fragment = '''
android:
  activity_class:
    io.flutter.embedding.android.FlutterFragmentActivity: { required: true, hint: "Extend FlutterFragmentActivity" }
''';
    const kt = 'android/app/src/main/kotlin/a/MainActivity.kt';
    Finding withSource(String source) => check(
      fragment,
      androidFiles(
        applicationWithLauncher(),
        mainActivity: FileRead.ok(kt, source),
      ),
    )!;

    test('MainActivity extends FlutterFragmentActivity → ok', () {
      final f = withSource('class MainActivity : FlutterFragmentActivity()');
      expect(f.severity, Severity.ok);
      expect(f.file, kt);
    });

    test('MainActivity extends FlutterActivity → missing', () {
      final f = withSource('class MainActivity : FlutterActivity()');
      expect(f.severity, Severity.missing);
      expect(
        f.message,
        'MainActivity extends FlutterActivity, not FlutterFragmentActivity',
      );
    });

    test('custom base class → info (can\'t verify)', () {
      expect(
        withSource('class MainActivity : MyBaseActivity()').severity,
        Severity.info,
      );
    });

    test('source not found → info', () {
      final f = check(
        fragment,
        androidFiles(
          applicationWithLauncher(),
          mainActivity: const FileRead.failed(
            'android/app/src/main/{kotlin,java}/**/MainActivity.{kt,java}',
            FileProblem.missing,
          ),
        ),
      )!;
      expect(f.severity, Severity.info);
      expect(f.message, contains('couldn\'t find its source'));
    });

    test('manifest names FlutterFragmentActivity directly → ok', () {
      final f = check(
        fragment,
        androidFiles('''
<application>
  <activity android:name="io.flutter.embedding.android.FlutterFragmentActivity">
    <intent-filter>
      <action android:name="android.intent.action.MAIN"/>
      <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
  </activity>
</application>'''),
      )!;
      expect(f.severity, Severity.ok);
    });

    test('no launcher activity → info', () {
      expect(
        check(fragment, androidFiles('<application/>'))!.severity,
        Severity.info,
      );
    });
  });

  test('manual → info', () {
    final f = check('''
android:
  manual:
    - { id: desugaring, required: true, hint: "Enable core library desugaring" }
''', androidFiles(''))!;
    expect(f.severity, Severity.info);
    expect(f.file, isNull);
  });
}
