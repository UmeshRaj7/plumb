import '../project/dependencies.dart';
import '../project/snapshot.dart';
import '../recipes/recipe.dart';
import '../recipes/recipe_index.dart';
import 'android_checks.dart';
import 'doctor_report.dart';
import 'finding.dart';
import 'ios_checks.dart';
import 'project_checks.dart';

/// Compares [snapshot] with the recipes in [index]. Pure: no I/O.
///
/// Findings come out in a fixed order (app-level, then packages by name,
/// then recipe declaration order) so output is stable for golden tests.
DoctorReport runChecks(ProjectSnapshot snapshot, RecipeIndex index) {
  final packages = <CheckedPackage>[];
  final applied = <Recipe>[];
  final packageFindings = <Finding>[];

  final dependencies = [...snapshot.packages]
    ..sort((a, b) => a.name.compareTo(b.name));
  for (final dependency in dependencies) {
    final lookup = index.lookup(dependency.name, dependency.version);
    switch (lookup.status) {
      case LookupStatus.noRecipe:
        continue;
      case LookupStatus.found:
        final recipe = lookup.recipe!;
        applied.add(recipe);
        packages.add(
          CheckedPackage(
            name: dependency.name,
            version: dependency.version,
            status: PackageStatus.checked,
            recipe: recipe.origin,
          ),
        );
        packageFindings.addAll(_checkRecipe(recipe, snapshot));
      case LookupStatus.versionNotCovered || LookupStatus.versionUnknown:
        packages.add(
          CheckedPackage(
            name: dependency.name,
            version: dependency.version,
            status: lookup.status == LookupStatus.versionUnknown
                ? PackageStatus.versionUnknown
                : PackageStatus.versionNotCovered,
          ),
        );
        packageFindings.add(_notCheckedFinding(dependency, lookup));
    }
  }

  final infoPlist = snapshot.ios?.infoPlist.value;
  final keysCheckedByRecipes = {
    for (final recipe in applied)
      for (final r in recipe.requirements)
        if (r.kind == RequirementKind.infoPlistKey) r.key,
  };
  final appFindings = [
    ...fileProblemFindings(snapshot),
    ...missingPlatformFindings(snapshot, applied),
    if (infoPlist != null)
      ...purposeStringFindings(infoPlist, keysCheckedByRecipes),
    ...flavorFindings(snapshot),
  ];
  final (findings, unmatched) = _applyIgnores([
    ...appFindings,
    ..._mergeDuplicates(packageFindings),
  ], snapshot.ignore);
  return DoctorReport(
    projectName: snapshot.name,
    dependencySource: snapshot.dependencySource,
    packages: packages,
    recipePackageCount: index.packages.length,
    findings: [
      // Unmatched ignore entries go with the other app-level findings.
      ...findings.take(appFindings.length),
      ...unmatched,
      ...findings.skip(appFindings.length),
    ],
  );
}

/// Marks findings listed in [ignore] (id → reason) as ignored. ✓ findings
/// are never ignored. Returns the findings, plus an info finding for each
/// entry that matched nothing, so stale entries get noticed and removed.
(List<Finding>, List<Finding>) _applyIgnores(
  List<Finding> findings,
  Map<String, String> ignore,
) {
  final matched = <String>{};
  final result = <Finding>[];
  for (final finding in findings) {
    final reason = ignore[finding.id];
    if (reason == null || finding.severity == Severity.ok) {
      result.add(finding);
    } else {
      matched.add(finding.id);
      result.add(finding.ignoredBecause(reason));
    }
  }
  final unmatched = [
    for (final id in ignore.keys.toList()..sort())
      if (!matched.contains(id))
        Finding(
          id: 'app/ignore/$id',
          severity: Severity.info,
          file: 'pubspec.yaml',
          message: 'plumb.ignore lists $id, but nothing matched it',
          fix:
              'Remove the entry if that issue is fixed. Ids are shown by '
              '--verbose and --json.',
        ),
  ];
  return (result, unmatched);
}

List<Finding> _checkRecipe(Recipe recipe, ProjectSnapshot snapshot) => [
  for (final requirement in recipe.requirements)
    ?switch (requirement.platform) {
      NativePlatform.ios => switch (snapshot.ios) {
        final ios? => checkIosRequirement(requirement, recipe, ios),
        null => null, // reported once by missingPlatformFindings
      },
      NativePlatform.android => switch (snapshot.android) {
        final android? => checkAndroidRequirement(requirement, recipe, android),
        null => null,
      },
    },
];

Finding _notCheckedFinding(ResolvedPackage dependency, RecipeLookup lookup) {
  final covered = lookup.candidates.map((r) => '${r.versions}').join(', ');
  final message = dependency.version == null
      ? 'Installed version of ${dependency.name} is unknown, so it was not '
            'checked (recipes cover $covered)'
      : 'No recipe for ${dependency.name} ${dependency.version} '
            '(recipes cover $covered), so it was not checked';
  return Finding(
    id: '${dependency.name}/recipe',
    severity: Severity.info,
    package: dependency.name,
    message: message,
    fix: dependency.version == null
        ? 'Run `flutter pub get` so pubspec.lock records versions.'
        : null,
    source: lookup.candidates.first.source,
  );
}

/// Several recipes can require the same thing (camera, image_picker and
/// permission_handler all check NSCameraUsageDescription). When they observe
/// the same result, keep the first finding and list the other packages, so
/// one problem is shown and counted once. Conditional/manual items (info)
/// stay per package because their hints differ.
List<Finding> _mergeDuplicates(List<Finding> findings) {
  final merged = <Finding>[];
  final indexByObservation = <String, int>{};
  for (final finding in findings) {
    if (finding.severity == Severity.info || finding.key == null) {
      merged.add(finding);
      continue;
    }
    final observation = [
      finding.severity,
      finding.platform,
      finding.file,
      finding.key,
      finding.message,
    ].join('|');
    final index = indexByObservation[observation];
    if (index == null) {
      indexByObservation[observation] = merged.length;
      merged.add(finding);
    } else {
      merged[index] = merged[index].withAlsoNeededBy(finding.package!);
    }
  }
  return merged;
}
