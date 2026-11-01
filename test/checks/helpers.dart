import 'package:plumb/src/parsers/android_manifest.dart';
import 'package:plumb/src/project/snapshot.dart';
import 'package:plumb/src/recipes/recipe.dart';
import 'package:plumb/src/recipes/recipe_parser.dart';

/// A recipe for package `demo` with the given `ios:`/`android:` YAML body.
Recipe demoRecipe(String body) => parseRecipe('''
schema: 1
package: demo
versions: ">=1.0.0 <2.0.0"
source: https://pub.dev/packages/demo
$body''', origin: 'demo.yaml');

/// iOS files with an XML-parsed Info.plist [plist].
IosFiles iosFiles(
  Map<String, Object?> plist, {
  List<FileRead<Map<String, Object?>>> entitlements = const [],
  String? pbxproj,
}) => IosFiles(
  infoPlist: FileRead.ok('ios/Runner/Info.plist', plist),
  entitlements: entitlements,
  pbxproj: pbxproj,
);

/// An entitlements file read.
FileRead<Map<String, Object?>> entitlementsFile(
  String name,
  Map<String, Object?> values,
) => FileRead.ok('ios/Runner/$name', values);

/// Android files from manifest XML [body] (children of `<manifest>`).
AndroidFiles androidFiles(
  String body, {
  FileRead<String>? mainActivity,
}) => AndroidFiles(
  manifest: FileRead.ok(
    'android/app/src/main/AndroidManifest.xml',
    parseAndroidManifest(
      '<manifest xmlns:android="http://schemas.android.com/apk/res/android" '
      'xmlns:tools="http://schemas.android.com/tools">$body</manifest>',
    ),
  ),
  mainActivitySource: mainActivity,
);

/// Application element with a `.MainActivity` launcher, plus [extra] children.
String applicationWithLauncher([String extra = '']) =>
    '''
<application>
  <activity android:name=".MainActivity">
    <intent-filter>
      <action android:name="android.intent.action.MAIN"/>
      <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
  </activity>
  $extra
</application>''';
