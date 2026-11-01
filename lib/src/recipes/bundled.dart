import 'bundled_recipes.g.dart';
import 'recipe.dart';
import 'recipe_parser.dart';

/// The recipes shipped with plumb, parsed and validated.
///
/// Embedded YAML goes through the same strict parser as any recipe, so a bad
/// bundled recipe fails tests rather than producing odd findings.
List<Recipe> bundledRecipes() => [
  for (final MapEntry(key: origin, value: yaml) in bundledRecipeFiles.entries)
    parseRecipe(yaml, origin: 'recipes/$origin'),
];
