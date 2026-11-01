import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'recipe_samples.dart';

/// Validates [yaml] against schema/recipe.schema.json.
bool schemaAccepts(JsonSchema schema, String yaml) =>
    schema.validate(toJson(loadYaml(yaml))).isValid;

/// Converts parsed YAML (YamlMap/YamlList) into plain JSON values.
Object? toJson(Object? yaml) => switch (yaml) {
  Map() => {
    for (final MapEntry(:key, :value) in yaml.entries) '$key': toJson(value),
  },
  List() => [for (final item in yaml) toJson(item)],
  _ => yaml,
};

JsonSchema loadRecipeSchema() => JsonSchema.create(
  jsonDecode(File('schema/recipe.schema.json').readAsStringSync()) as Object,
);

void main() {
  final schema = loadRecipeSchema();

  for (final (name, yaml) in [
    ('full', fullRecipe),
    ('minimal', minimalRecipe),
  ]) {
    test('the JSON Schema accepts the $name sample recipe', () {
      final result = schema.validate(toJson(loadYaml(yaml)));
      expect(result.isValid, isTrue, reason: result.errors.join('\n'));
    });
  }

  group('the JSON Schema rejects what the Dart parser rejects:', () {
    for (final sample in invalidRecipes) {
      test(sample.description, () {
        final Object? document;
        try {
          document = loadYaml(sample.yaml);
        } on YamlException {
          return; // Not YAML at all; nothing for a JSON Schema to validate.
        }
        expect(schema.validate(toJson(document)).isValid, isFalse);
      });
    }
  });
}
