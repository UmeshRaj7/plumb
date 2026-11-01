import 'package:pub_semver/pub_semver.dart';

import '../errors.dart';
import 'recipe.dart';

/// Outcome of looking up a package in a [RecipeIndex].
enum LookupStatus {
  /// A recipe covers the installed version.
  found,

  /// plumb has no recipe for this package (the common case; not reported).
  noRecipe,

  /// Recipes exist, but none covers the installed version.
  versionNotCovered,

  /// Recipes exist, but the installed version couldn't be determined.
  versionUnknown,
}

/// Result of [RecipeIndex.lookup].
class RecipeLookup {
  /// Creates a lookup result.
  const RecipeLookup(this.status, {this.recipe, this.candidates = const []});

  /// What happened.
  final LookupStatus status;

  /// The matching recipe when [status] is [LookupStatus.found].
  final Recipe? recipe;

  /// All recipes for the package (useful to say which versions are covered).
  final List<Recipe> candidates;
}

/// Recipes grouped by package, for version-aware lookup.
class RecipeIndex {
  /// Indexes [recipes]. Throws [PlumbException] if two recipes for the same
  /// package have overlapping version ranges (the match would be ambiguous).
  RecipeIndex(Iterable<Recipe> recipes) {
    for (final recipe in recipes) {
      final existing = _byPackage.putIfAbsent(recipe.package, () => []);
      for (final other in existing) {
        if (other.versions.allowsAny(recipe.versions)) {
          throw PlumbException(
            'Recipes ${other.origin} and ${recipe.origin} both cover '
            '${recipe.package} versions in ${other.versions.intersect(recipe.versions)}.',
          );
        }
      }
      existing.add(recipe);
    }
  }

  final _byPackage = <String, List<Recipe>>{};

  /// Package names that have at least one recipe.
  Iterable<String> get packages => _byPackage.keys;

  /// Finds the recipe for [package] at [version] (null = unknown version).
  RecipeLookup lookup(String package, Version? version) {
    final candidates = _byPackage[package];
    if (candidates == null) return const RecipeLookup(LookupStatus.noRecipe);
    if (version == null) {
      return RecipeLookup(LookupStatus.versionUnknown, candidates: candidates);
    }
    for (final recipe in candidates) {
      if (recipe.versions.allows(version)) {
        return RecipeLookup(
          LookupStatus.found,
          recipe: recipe,
          candidates: candidates,
        );
      }
    }
    return RecipeLookup(LookupStatus.versionNotCovered, candidates: candidates);
  }
}
