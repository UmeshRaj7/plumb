import '../parsers/android_manifest.dart';
import 'dependencies.dart';

/// Why a native file couldn't be used.
enum FileProblem {
  /// The file doesn't exist.
  missing,

  /// A binary plist (plumb reads XML plists only).
  binaryPlist,

  /// The file exists but couldn't be parsed.
  malformed,

  /// More than one candidate file was found (e.g. two MainActivity.kt).
  ambiguous,

  /// The Xcode project builds with a different plist (`INFOPLIST_FILE`), so
  /// this file isn't what ships. Not an error: plumb just can't check it.
  notUsed,
}

/// The result of reading and parsing one native file.
class FileRead<T> {
  /// A successfully parsed file.
  const FileRead.ok(this.path, T this.value) : problem = null, detail = null;

  /// A file that couldn't be used, with an optional explanation.
  const FileRead.failed(this.path, FileProblem this.problem, [this.detail])
    : value = null;

  /// Project-relative path with `/` separators.
  final String path;

  /// The parsed contents, when [problem] is null.
  final T? value;

  /// Why the file couldn't be used.
  final FileProblem? problem;

  /// Human-readable detail (parser message, candidate list…).
  final String? detail;
}

/// The iOS files plumb reads.
class IosFiles {
  /// Creates the iOS snapshot.
  const IosFiles({
    required this.infoPlist,
    this.entitlements = const [],
    this.pbxproj,
    this.otherInfoPlists = const [],
  });

  /// `ios/Runner/Info.plist`, or [FileProblem.notUsed] when the Xcode
  /// project builds with another plist.
  final FileRead<Map<String, Object?>> infoPlist;

  /// Every `ios/Runner/*.entitlements`, sorted by path.
  final List<FileRead<Map<String, Object?>>> entitlements;

  /// Raw `ios/Runner.xcodeproj/project.pbxproj`, for `INFOPLIST_KEY_*` lookups.
  final String? pbxproj;

  /// Other `ios/Runner/Info*.plist` files (flavors), which aren't checked.
  final List<String> otherInfoPlists;
}

/// The Android files plumb reads.
class AndroidFiles {
  /// Creates the Android snapshot.
  const AndroidFiles({
    required this.manifest,
    this.mainActivitySource,
    this.otherManifests = const [],
  });

  /// `android/app/src/main/AndroidManifest.xml`.
  final FileRead<AndroidManifest> manifest;

  /// Source of the launcher activity, when it is an app class (null when the
  /// manifest names a Flutter embedding class directly or has no launcher).
  final FileRead<String>? mainActivitySource;

  /// Flavor manifests (`android/app/src/<flavor>/AndroidManifest.xml`),
  /// which aren't checked. Flutter's standard debug/profile ones are omitted.
  final List<String> otherManifests;
}

/// Everything the checks need, read once from disk.
class ProjectSnapshot {
  /// Creates a snapshot.
  const ProjectSnapshot({
    required this.name,
    required this.root,
    required this.dependencySource,
    required this.packages,
    this.ios,
    this.android,
  });

  /// The app's package name.
  final String name;

  /// Absolute project root (never printed, so output stays portable).
  final String root;

  /// Which file the dependency list came from.
  final DependencySource dependencySource;

  /// The app's dependencies (dev dependencies excluded when known).
  final List<ResolvedPackage> packages;

  /// iOS files, or null when there is no `ios/` directory.
  final IosFiles? ios;

  /// Android files, or null when there is no `android/` directory.
  final AndroidFiles? android;
}
