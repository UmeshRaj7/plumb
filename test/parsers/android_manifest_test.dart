import 'package:plumb/src/parsers/android_manifest.dart';
import 'package:test/test.dart';

const _flutterTemplate = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission-sdk-23 android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO" tools:node="remove"/>
    <application android:label="app" android:name="\${applicationName}">
        <activity android:name=".MainActivity" android:exported="true">
            <meta-data android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme"/>
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
        <service android:name="com.example.Gone" tools:node="remove"/>
        <meta-data android:name="flutterEmbedding" android:value="2"/>
        <meta-data android:name="com.google.android.geo.API_KEY" android:value="\${MAPS_KEY}"/>
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="sms"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
        <package android:name="com.example.other"/>
    </queries>
</manifest>
''';

void main() {
  late AndroidManifest manifest;
  setUp(() => manifest = parseAndroidManifest(_flutterTemplate));

  test('reads permissions, including uses-permission-sdk-23', () {
    expect(manifest.permissions, {
      'android.permission.CAMERA',
      'android.permission.ACCESS_FINE_LOCATION',
    });
  });

  test('records tools:node="remove" permissions separately', () {
    expect(manifest.removedPermissions, {'android.permission.RECORD_AUDIO'});
  });

  test('reads application-level meta-data only (not activity meta-data)', () {
    expect(manifest.metaData, {
      'flutterEmbedding': '2',
      'com.google.android.geo.API_KEY': r'${MAPS_KEY}',
    });
  });

  test('reads components with kind and removal flag', () {
    expect(manifest.components.map((c) => (c.kind, c.name, c.removed)), [
      (ComponentKind.activity, '.MainActivity', false),
      (
        ComponentKind.receiver,
        'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
        false,
      ),
      (ComponentKind.service, 'com.example.Gone', true),
    ]);
  });

  test('finds the launcher activity', () {
    expect(manifest.launcherActivity, '.MainActivity');
  });

  test('reads <queries> intents and packages', () {
    expect(manifest.queryIntents, hasLength(2));
    expect(manifest.queryIntents[0].actions, {'android.intent.action.VIEW'});
    expect(manifest.queryIntents[0].schemes, {'sms'});
    expect(manifest.queryIntents[1].mimeTypes, {'text/plain'});
    expect(manifest.queryPackages, {'com.example.other'});
  });

  test('resolves the android namespace by URI, not by prefix', () {
    final m = parseAndroidManifest('''
<manifest xmlns:a="http://schemas.android.com/apk/res/android">
  <uses-permission a:name="android.permission.INTERNET"/>
  <uses-permission android:name="not.android.ns"/>
</manifest>''');
    expect(m.permissions, {'android.permission.INTERNET'});
  });

  test('launcher via activity-alias resolves to the target activity', () {
    final m = parseAndroidManifest('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.example.app">
  <application>
    <activity android:name=".MainActivity"/>
    <activity-alias android:name=".Alias" android:targetActivity=".MainActivity">
      <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
      </intent-filter>
    </activity-alias>
  </application>
</manifest>''');
    expect(m.launcherActivity, '.MainActivity');
    expect(m.packageName, 'com.example.app');
  });

  test('a manifest without application or queries parses to empty sets', () {
    final m = parseAndroidManifest(
      '<manifest xmlns:android="http://schemas.android.com/apk/res/android"/>',
    );
    expect(m.permissions, isEmpty);
    expect(m.components, isEmpty);
    expect(m.launcherActivity, isNull);
    expect(m.queryIntents, isEmpty);
  });

  test('rejects malformed XML', () {
    expect(() => parseAndroidManifest('<manifest>'), throwsFormatException);
  });

  test('rejects a root that is not <manifest>', () {
    expect(() => parseAndroidManifest('<plist/>'), throwsFormatException);
  });
}
