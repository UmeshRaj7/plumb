import '../parsers/plist.dart';
import '../project/snapshot.dart';
import '../recipes/recipe.dart';
import 'finding.dart';
import 'placeholder.dart';

const _infoPlist = 'ios/Runner/Info.plist';
const _pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';

/// Builds a finding for the requirement being checked.
typedef _MakeFinding =
    Finding Function(Severity, String message, {String? file, String? fix});

/// Checks one iOS [requirement] of [recipe] against [ios].
///
/// Returns null when a file the check needs is unreadable; that problem is
/// reported once at app level instead of once per requirement.
Finding? checkIosRequirement(
  Requirement requirement,
  Recipe recipe,
  IosFiles ios,
) {
  Finding finding(
    Severity severity,
    String message, {
    String? file,
    String? fix,
  }) => Finding.forRequirement(
    recipe,
    requirement,
    severity,
    message: message,
    file: file,
    fix: fix,
  );

  switch (requirement.kind) {
    case RequirementKind.infoPlistKey:
      final plist = ios.infoPlist.value;
      if (plist == null) return null;
      return _checkInfoPlistKey(requirement, plist, ios.pbxproj, finding);
    case RequirementKind.backgroundMode:
      final plist = ios.infoPlist.value;
      if (plist == null) return null;
      final modes = plist['UIBackgroundModes'];
      if (modes is List && modes.contains(requirement.key)) {
        return finding(
          Severity.ok,
          'UIBackgroundModes includes ${requirement.key}',
          file: _infoPlist,
        );
      }
      return finding(
        _absent(requirement),
        'UIBackgroundModes does not include ${requirement.key}',
        file: _infoPlist,
      );
    case RequirementKind.entitlement:
      if (ios.entitlements.any((e) => e.value == null)) return null;
      return _checkEntitlement(requirement, ios.entitlements, finding);
    case RequirementKind.manual:
      return finding(Severity.info, manualMessage(requirement));
    default:
      throw ArgumentError.value(requirement.kind, 'kind', 'not an iOS kind');
  }
}

/// The message for a step plumb can't verify.
String manualMessage(Requirement requirement) =>
    requirement.necessity == Necessity.required
    ? 'Manual step plumb can\'t check (required)'
    : 'Manual step plumb can\'t check (only if you use this feature)';

/// Severity for an absent item: required → missing, conditional → info.
Severity _absent(Requirement requirement) =>
    requirement.necessity == Necessity.required
    ? Severity.missing
    : Severity.info;

Finding _checkInfoPlistKey(
  Requirement requirement,
  Map<String, Object?> plist,
  String? pbxproj,
  _MakeFinding finding,
) {
  final key = requirement.key;
  if (!plist.containsKey(key)) {
    // Xcode can inject keys from INFOPLIST_KEY_* build settings. plumb can't
    // evaluate build settings, so it reports "can't verify" rather than ✗.
    final buildSetting = RegExp('\\bINFOPLIST_KEY_${RegExp.escape(key)}\\s*=');
    if (pbxproj != null && buildSetting.hasMatch(pbxproj)) {
      return finding(
        Severity.info,
        '$key is not in Info.plist but is set as build setting '
        'INFOPLIST_KEY_$key; plumb can\'t verify build settings',
        file: _pbxproj,
        fix:
            'Nothing to do if Xcode generates Info.plist keys for this target '
            '(GENERATE_INFOPLIST_FILE = YES); otherwise add $key to Info.plist.',
      );
    }
    return finding(
      _absent(requirement),
      requirement.necessity == Necessity.required
          ? '$key is missing'
          : '$key is not set',
      file: _infoPlist,
    );
  }
  return _checkValue(requirement, plist[key], finding, file: _infoPlist);
}

Finding _checkEntitlement(
  Requirement requirement,
  List<FileRead<Map<String, Object?>>> files,
  _MakeFinding finding,
) {
  final key = requirement.key;
  if (files.isEmpty) {
    return finding(
      _absent(requirement),
      'No .entitlements file in ios/Runner, so $key is not set',
      file: 'ios/Runner/',
    );
  }
  final withKey = [
    for (final file in files)
      if (file.value!.containsKey(key)) file,
  ];
  final label = files.length == 1
      ? files.single.path
      : 'ios/Runner/*.entitlements';
  if (withKey.isEmpty) {
    return finding(
      _absent(requirement),
      '$key is not in ${files.map((f) => _name(f.path)).join(', ')}',
      file: label,
    );
  }
  if (withKey.length < files.length) {
    final without = files
        .where((f) => !withKey.contains(f))
        .map((f) => _name(f.path));
    return finding(
      Severity.warning,
      '$key is in ${withKey.map((f) => _name(f.path)).join(', ')} '
      'but not in ${without.join(', ')}',
      file: label,
    );
  }
  return _checkValue(
    requirement,
    withKey.first.value![key],
    finding,
    file: label,
  );
}

/// Checks a present plist value: type, then placeholder text.
Finding _checkValue(
  Requirement requirement,
  Object? value,
  _MakeFinding finding, {
  required String file,
}) {
  final key = requirement.key;
  final expected = expectedType(requirement);
  final actual = PlistType.of(value);
  if (expected != null && actual != expected) {
    return finding(
      Severity.warning,
      '$key should be of type ${expected.name}, found ${actual.name}',
      file: file,
    );
  }
  if (value is String) {
    if (isPlaceholder(value)) {
      return finding(
        Severity.warning,
        placeholderMessage(key, value),
        file: file,
        fix: placeholderFix(requirement.hint),
      );
    }
    if (isBuildVariable(value)) {
      return finding(
        Severity.ok,
        '$key is set via a build variable ($value); its final value isn\'t checked',
        file: file,
      );
    }
  }
  return finding(Severity.ok, '$key is set', file: file);
}

/// The plist type a value must have: the recipe's `expect_type`, or string
/// for purpose strings (`*UsageDescription`), which Apple requires to be text.
PlistType? expectedType(Requirement requirement) =>
    requirement.expectType ??
    (requirement.key.endsWith('UsageDescription') ? PlistType.string : null);

String _name(String path) => path.split('/').last;
