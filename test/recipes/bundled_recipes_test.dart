import 'dart:io';

import 'package:plumb/src/recipes/bundled.dart';
import 'package:plumb/src/recipes/recipe.dart';
import 'package:plumb/src/recipes/recipe_index.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/generate_bundled_recipes.dart';
import 'recipe_schema_test.dart' show loadRecipeSchema, toJson;

void main() {
  final files = readRecipeFiles();

  test(
    'the generated file is up to date (run tool/generate_bundled_recipes.dart)',
    () {
      expect(
        File(generatedPath).readAsStringSync().replaceAll('\r\n', '\n'),
        generateBundledRecipes(files),
      );
    },
  );

  test('the generated file is already dart-formatted', () {
    final result = Process.runSync('dart', [
      'format',
      '--output=none',
      '--set-exit-if-changed',
      generatedPath,
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });

  test('every bundled recipe parses and none overlap', () {
    expect(() => RecipeIndex(bundledRecipes()), returnsNormally);
  });

  test('recipe file names match their package', () {
    for (final recipe in bundledRecipes()) {
      final file = recipe.origin.split('/').last;
      expect(
        file == '${recipe.package}.yaml' ||
            file.startsWith('${recipe.package}@'),
        isTrue,
        reason:
            '$file should be named ${recipe.package}.yaml or ${recipe.package}@<label>.yaml',
      );
    }
  });

  // Keys the docs list without a condition but only an optional feature uses.
  // Real apps ship without them, so they must stay `when_used`.
  test('feature-only keys are when_used, not required', () {
    Necessity necessityOf(String package, String key) => bundledRecipes()
        .firstWhere((recipe) => recipe.package == package)
        .requirements
        .firstWhere((requirement) => requirement.key == key)
        .necessity;

    expect(
      necessityOf('image_picker', 'NSCameraUsageDescription'),
      Necessity.whenUsed,
    );
    expect(
      necessityOf('camera', 'NSMicrophoneUsageDescription'),
      Necessity.whenUsed,
    );
  });

  group('every bundled recipe matches the JSON Schema:', () {
    final schema = loadRecipeSchema();
    for (final MapEntry(key: name, value: yaml) in files.entries) {
      test(name, () {
        final result = schema.validate(toJson(loadYaml(yaml)));
        expect(result.isValid, isTrue, reason: result.errors.join('\n'));
      });
    }
  });
}
