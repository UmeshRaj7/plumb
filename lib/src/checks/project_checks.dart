import '../project/snapshot.dart';
import '../recipes/recipe.dart';
import 'finding.dart';
import 'placeholder.dart';

/// One `error` finding per native file plumb couldn't read.
List<Finding> fileProblemFindings(ProjectSnapshot snapshot) => [
  if (snapshot.ios case final ios?) ...[
    ?_fileProblem(NativePlatform.ios, ios.infoPlist),
    for (final file in ios.entitlements)
      ?_fileProblem(NativePlatform.ios, file),
  ],
  if (snapshot.android case final android?)
    ?_fileProblem(NativePlatform.android, android.manifest),
];

/// An `info` finding per platform directory that is absent although
/// [recipes] have requirements for it.
List<Finding> missingPlatformFindings(
  ProjectSnapshot snapshot,
  List<Recipe> recipes,
) => [
  for (final platform in NativePlatform.values)
    if (_platformMissing(snapshot, platform))
      if (_packagesNeeding(recipes, platform) case final packages
          when packages.isNotEmpty)
        Finding(
          id: 'app/${platform.name}/directory',
          severity: Severity.info,
          platform: platform,
          file: '${platform.name}/',
          message:
              '${platform.name}/ not found; ${platform.name} requirements of '
              '${packages.join(', ')} were not checked',
        ),
];

/// Placeholder purpose strings that no applied recipe already checks.
///
/// Every `*UsageDescription` the app ships is shown to users and reviewed by
/// Apple, whichever plugin needs it, so it is checked even without a recipe.
List<Finding> purposeStringFindings(
  Map<String, Object?> infoPlist,
  Set<String> keysCheckedByRecipes,
) => [
  for (final MapEntry(:key, :value) in infoPlist.entries)
    if (key.endsWith('UsageDescription') &&
        !keysCheckedByRecipes.contains(key) &&
        value is String &&
        isPlaceholder(value))
      Finding(
        id: 'app/ios/info_plist/$key',
        severity: Severity.warning,
        platform: NativePlatform.ios,
        file: 'ios/Runner/Info.plist',
        key: key,
        message: '$key looks like a placeholder: "${value.trim()}"',
        fix:
            'Replace it with a sentence telling users why the app needs this '
            'access. App Review rejects vague or placeholder purpose strings.',
        source:
            'https://developer.apple.com/documentation/uikit/requesting-access-to-protected-resources',
      ),
];

/// `info` findings for flavor files plumb lists but doesn't check.
List<Finding> flavorFindings(ProjectSnapshot snapshot) => [
  if (snapshot.ios?.otherInfoPlists case final plists? when plists.isNotEmpty)
    Finding(
      id: 'app/ios/flavors',
      severity: Severity.info,
      platform: NativePlatform.ios,
      message:
          'Not checked: ${plists.join(', ')} (plumb checks ios/Runner/Info.plist only)',
    ),
  if (snapshot.android?.otherManifests case final manifests?
      when manifests.isNotEmpty)
    Finding(
      id: 'app/android/flavors',
      severity: Severity.info,
      platform: NativePlatform.android,
      message:
          'Not checked: ${manifests.join(', ')} (plumb checks the main AndroidManifest.xml only)',
    ),
];

Finding? _fileProblem(NativePlatform platform, FileRead<Object?> file) {
  final problem = file.problem;
  if (problem == null) return null;
  final (message, fix) = switch (problem) {
    FileProblem.missing => ('${file.path} not found', null),
    FileProblem.binaryPlist => (
      '${file.path} is a binary plist; plumb reads XML plists only',
      'Convert it to XML, e.g. `plutil -convert xml1 ${file.path}` on macOS.',
    ),
    FileProblem.malformed => (
      '${file.path} could not be parsed: ${file.detail}',
      'Fix the XML so Xcode/Gradle and plumb can read it.',
    ),
    FileProblem.ambiguous => (
      '${file.path} is ambiguous: ${file.detail}',
      null,
    ),
  };
  return Finding(
    id: 'app/${platform.name}/file/${file.path}',
    severity: Severity.error,
    platform: platform,
    file: file.path,
    message: message,
    fix: fix,
  );
}

bool _platformMissing(ProjectSnapshot snapshot, NativePlatform platform) =>
    switch (platform) {
      NativePlatform.ios => snapshot.ios == null,
      NativePlatform.android => snapshot.android == null,
    };

List<String> _packagesNeeding(
  List<Recipe> recipes,
  NativePlatform platform,
) => [
  for (final recipe in recipes)
    if (recipe.requirements.any((r) => r.platform == platform)) recipe.package,
];
