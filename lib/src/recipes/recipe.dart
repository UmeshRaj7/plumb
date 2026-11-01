import 'package:pub_semver/pub_semver.dart';

import '../parsers/android_manifest.dart';
import '../parsers/plist.dart';

/// The native platforms plumb checks.
enum NativePlatform {
  /// `ios/`
  ios,

  /// `android/`
  android,
}

/// What a [Requirement] refers to. [section] is the recipe YAML key.
enum RequirementKind {
  /// A top-level key in `ios/Runner/Info.plist`.
  infoPlistKey(NativePlatform.ios, 'info_plist'),

  /// A key in `ios/Runner/*.entitlements`.
  entitlement(NativePlatform.ios, 'entitlements'),

  /// A value in Info.plist's `UIBackgroundModes` array.
  backgroundMode(NativePlatform.ios, 'background_modes'),

  /// A `<uses-permission>` in AndroidManifest.xml.
  permission(NativePlatform.android, 'permissions'),

  /// A `<queries>` entry in AndroidManifest.xml.
  query(NativePlatform.android, 'queries'),

  /// An `<application><meta-data>` in AndroidManifest.xml.
  metaData(NativePlatform.android, 'manifest_meta_data'),

  /// An `<activity>`/`<receiver>`/`<service>`/`<provider>` in `<application>`.
  component(NativePlatform.android, 'components'),

  /// The superclass the launcher activity must extend.
  activityClass(NativePlatform.android, 'activity_class'),

  /// A step plumb can't verify (Gradle, Podfile, AppDelegate…), per platform.
  manual(null, 'manual');

  const RequirementKind(this.platform, this.section);

  /// The platform this kind belongs to (null: either, see [Requirement.platform]).
  final NativePlatform? platform;

  /// The recipe YAML section name, also used in finding ids.
  final String section;
}

/// How necessary a requirement is. YAML: `required: true` / `required: when_used`.
enum Necessity {
  /// The app needs it whenever it uses the plugin.
  required,

  /// Needed only for some features of the plugin (the hint says which).
  whenUsed,
}

/// A `<queries>` entry a plugin needs: either an intent or a package.
class AndroidQuery {
  /// An `<intent>` query with an [action] and optional data constraints.
  const AndroidQuery.intent({
    required String this.action,
    this.scheme,
    this.mimeType,
  }) : package = null;

  /// A `<package android:name>` query.
  const AndroidQuery.package(String this.package)
    : action = null,
      scheme = null,
      mimeType = null;

  /// Package name, for package queries.
  final String? package;

  /// `<action android:name>`, for intent queries.
  final String? action;

  /// Required `<data android:scheme>`, if any.
  final String? scheme;

  /// Required `<data android:mimeType>`, if any.
  final String? mimeType;

  /// A short stable description, used as the requirement key.
  String describe() {
    if (package != null) return 'package:$package';
    return [
      'intent:$action',
      if (scheme != null) 'scheme=$scheme',
      if (mimeType != null) 'mimeType=$mimeType',
    ].join(' ');
  }
}

/// One thing a plugin needs in the native project.
class Requirement {
  /// Creates a requirement. Prefer building these with `parseRecipe`.
  const Requirement({
    required this.platform,
    required this.kind,
    required this.key,
    required this.necessity,
    required this.hint,
    this.source,
    this.expectType,
    this.query,
    this.componentKind,
  });

  /// Which native project the requirement is about.
  final NativePlatform platform;

  /// What the requirement refers to.
  final RequirementKind kind;

  /// Plist key, permission name, component name, query description or manual id.
  final String key;

  /// Always needed, or only for some features.
  final Necessity necessity;

  /// What to add and why, shown as the fix.
  final String hint;

  /// Docs URL for this item when it differs from [Recipe.source].
  final String? source;

  /// Expected plist value type (Info.plist / entitlements only).
  final PlistType? expectType;

  /// The query to look for ([RequirementKind.query] only).
  final AndroidQuery? query;

  /// The component element type ([RequirementKind.component] only).
  final ComponentKind? componentKind;
}

/// The native setup one plugin documents, for a range of its versions.
class Recipe {
  /// Creates a recipe. Prefer building these with `parseRecipe`.
  const Recipe({
    required this.package,
    required this.versions,
    required this.source,
    required this.origin,
    required this.requirements,
    this.schema = 1,
  });

  /// Recipe format version.
  final int schema;

  /// The pub package this recipe is for.
  final String package;

  /// The package versions whose docs this recipe reflects.
  final VersionConstraint versions;

  /// URL of the plugin's setup docs.
  final String source;

  /// Where the recipe came from (file name), for messages.
  final String origin;

  /// Requirements in declaration order.
  final List<Requirement> requirements;
}
