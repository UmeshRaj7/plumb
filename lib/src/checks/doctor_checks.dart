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
  return DoctorReport(
    projectName: snapshot.name,
    dependencySource: snapshot.dependencySource,
    packages: packages,
    findings: [
      ...fileProblemFindings(snapshot),
      ...missingPlatformFindings(snapshot, applied),
      if (infoPlist != null)
        ...purposeStringFindings(infoPlist, keysCheckedByRecipes),
      ...flavorFindings(snapshot),
      ...packageFindings,
    ],
  );
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
