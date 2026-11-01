import '../parsers/activity_source.dart';
import '../parsers/android_manifest.dart';
import '../project/snapshot.dart';
import '../recipes/recipe.dart';
import 'finding.dart';
import 'ios_checks.dart' show manualMessage;
import 'placeholder.dart';

const _manifest = 'android/app/src/main/AndroidManifest.xml';

/// Builds a finding for the requirement being checked.
typedef _MakeFinding =
    Finding Function(Severity, String message, {String? file, String? fix});

/// Checks one Android [requirement] of [recipe] against [android].
///
/// Returns null when AndroidManifest.xml is unreadable; that problem is
/// reported once at app level instead of once per requirement.
Finding? checkAndroidRequirement(
  Requirement requirement,
  Recipe recipe,
  AndroidFiles android,
) {
  Finding finding(
    Severity severity,
    String message, {
    String? file = _manifest,
    String? fix,
  }) => Finding.forRequirement(
    recipe,
    requirement,
    severity,
    message: message,
    file: file,
    fix: fix,
  );

  if (requirement.kind == RequirementKind.manual) {
    return finding(Severity.info, manualMessage(requirement), file: null);
  }
  final manifest = android.manifest.value;
  if (manifest == null) return null;

  final required = requirement.necessity == Necessity.required;
  final absent = required ? Severity.missing : Severity.info;
  final key = requirement.key;

  switch (requirement.kind) {
    case RequirementKind.permission:
      if (manifest.permissions.contains(key)) {
        return finding(Severity.ok, '$key is declared');
      }
      if (manifest.removedPermissions.contains(key)) {
        return finding(absent, '$key is removed with tools:node="remove"');
      }
      return finding(absent, '$key is not declared');

    case RequirementKind.query:
      if (_hasQuery(manifest, requirement.query!)) {
        return finding(Severity.ok, '<queries> has $key');
      }
      return finding(absent, '<queries> has no $key');

    case RequirementKind.metaData:
      if (!manifest.metaData.containsKey(key)) {
        return finding(absent, '<meta-data> $key is not declared');
      }
      final value = manifest.metaData[key];
      if (value == null) {
        return finding(
          Severity.warning,
          '<meta-data> $key has no android:value',
        );
      }
      if (isPlaceholder(value)) {
        return finding(
          Severity.warning,
          placeholderMessage('<meta-data> $key', value),
          fix: placeholderFix(requirement.hint),
        );
      }
      if (isBuildVariable(value)) {
        return finding(
          Severity.ok,
          '<meta-data> $key is set via a build variable ($value); its final value isn\'t checked',
        );
      }
      return finding(Severity.ok, '<meta-data> $key is set');

    case RequirementKind.component:
      final kind = requirement.componentKind!.name;
      final matches = manifest.components.where(
        (c) => c.kind == requirement.componentKind && c.name == key,
      );
      if (matches.any((c) => !c.removed)) {
        return finding(Severity.ok, '<$kind> $key is declared');
      }
      if (matches.isNotEmpty) {
        return finding(
          absent,
          '<$kind> $key is removed with tools:node="remove"',
        );
      }
      return finding(absent, '<$kind> $key is not declared');

    case RequirementKind.activityClass:
      return _checkActivityClass(requirement, manifest, android, finding);

    default:
      throw ArgumentError.value(
        requirement.kind,
        'kind',
        'not an Android kind',
      );
  }
}

bool _hasQuery(AndroidManifest manifest, AndroidQuery query) {
  if (query.package != null) {
    return manifest.queryPackages.contains(query.package);
  }
  return manifest.queryIntents.any(
    (intent) =>
        intent.actions.contains(query.action) &&
        (query.scheme == null || intent.schemes.contains(query.scheme)) &&
        (query.mimeType == null || intent.mimeTypes.contains(query.mimeType)),
  );
}

/// The launcher activity must extend the required class (e.g. local_auth's
/// FlutterFragmentActivity). Only a plain `FlutterActivity` is reported as
/// wrong; custom base classes can't be verified, so they're ℹ.
Finding _checkActivityClass(
  Requirement requirement,
  AndroidManifest manifest,
  AndroidFiles android,
  _MakeFinding finding,
) {
  final required = _simpleName(requirement.key);
  final wrong = requirement.necessity == Necessity.required
      ? Severity.missing
      : Severity.info;
  final launcher = manifest.launcherActivity;
  if (launcher == null) {
    return finding(
      Severity.info,
      'No launcher activity in AndroidManifest.xml, so plumb can\'t check that it extends $required',
    );
  }

  // The manifest may name a Flutter embedding class directly.
  final source = android.mainActivitySource;
  if (source == null) {
    final declared = _simpleName(launcher);
    if (declared == required) {
      return finding(Severity.ok, 'Launcher activity is $required');
    }
    if (declared == 'FlutterActivity') {
      return finding(
        wrong,
        'Launcher activity is FlutterActivity, not $required',
      );
    }
    return finding(
      Severity.info,
      'Launcher activity is $launcher; plumb can\'t check that it extends $required',
    );
  }

  final activity = _simpleName(launcher);
  if (source.value == null) {
    final reason = source.problem == FileProblem.ambiguous
        ? 'found several candidates (${source.detail})'
        : 'couldn\'t find its source';
    return finding(
      Severity.info,
      '$activity: plumb $reason, so it can\'t check that it extends $required',
    );
  }
  final superclass = findSuperclass(source.value!, activity);
  final simpleSuper = superclass == null ? null : _simpleName(superclass);
  if (simpleSuper == required) {
    return finding(
      Severity.ok,
      '$activity extends $required',
      file: source.path,
    );
  }
  if (simpleSuper == 'FlutterActivity') {
    return finding(
      wrong,
      '$activity extends FlutterActivity, not $required',
      file: source.path,
    );
  }
  return finding(
    Severity.info,
    '$activity extends ${superclass ?? 'an unknown class'}; plumb can\'t check that it is a $required',
    file: source.path,
  );
}

String _simpleName(String className) => className.split('.').last;
