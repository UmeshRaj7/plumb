import 'package:pub_semver/pub_semver.dart';

import '../exit_codes.dart';
import '../project/dependencies.dart';
import 'finding.dart';

/// Whether a plugin with recipes was checked.
enum PackageStatus {
  /// A recipe matched and was applied.
  checked,

  /// Recipes exist, but not for the installed version.
  versionNotCovered,

  /// The installed version is unknown.
  versionUnknown,
}

/// A dependency that has at least one bundled recipe.
class CheckedPackage {
  /// Creates a package entry.
  const CheckedPackage({
    required this.name,
    required this.version,
    required this.status,
    this.recipe,
  });

  /// Package name.
  final String name;

  /// Installed version, when known.
  final Version? version;

  /// Whether its recipe was applied.
  final PackageStatus status;

  /// The recipe file used, when [status] is [PackageStatus.checked].
  final String? recipe;
}

/// The result of `plumb doctor`: everything the renderers need.
class DoctorReport {
  /// Creates a report.
  const DoctorReport({
    required this.projectName,
    required this.dependencySource,
    required this.packages,
    required this.findings,
    this.recipePackageCount,
  });

  /// The app's package name.
  final String projectName;

  /// Where the dependency list came from.
  final DependencySource dependencySource;

  /// Dependencies with recipes, sorted by name.
  final List<CheckedPackage> packages;

  /// All findings in display order (app-level first, then by package).
  final List<Finding> findings;

  /// How many plugins plumb has recipes for, when known. Dependencies
  /// without a recipe aren't checked.
  final int? recipePackageCount;

  /// Number of findings per severity (every severity present, possibly 0),
  /// not counting ignored ones.
  Map<Severity, int> get summary => {
    for (final severity in Severity.values)
      severity: findings
          .where((f) => f.severity == severity && f.ignoredReason == null)
          .length,
  };

  /// Number of findings the app ignores (`plumb: ignore:` in pubspec.yaml).
  int get ignoredCount => findings.where((f) => f.ignoredReason != null).length;

  /// The process exit code: 2 if any finding is an error (incomplete check),
  /// 1 if [strict] and anything is missing or a warning, otherwise 0.
  /// Ignored findings don't count.
  int exitCode({required bool strict}) {
    final counts = summary;
    if (counts[Severity.error]! > 0) return ExitCodes.incomplete;
    if (strict && counts[Severity.missing]! + counts[Severity.warning]! > 0) {
      return ExitCodes.findings;
    }
    return ExitCodes.ok;
  }
}
