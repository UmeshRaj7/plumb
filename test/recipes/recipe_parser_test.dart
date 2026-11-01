import 'package:plumb/src/parsers/android_manifest.dart';
import 'package:plumb/src/parsers/plist.dart';
import 'package:plumb/src/recipes/recipe.dart';
import 'package:plumb/src/recipes/recipe_parser.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'recipe_samples.dart';

void main() {
  group('parseRecipe accepts', () {
    test('a recipe using every section', () {
      final recipe = parseRecipe(fullRecipe, origin: 'full.yaml');

      expect(recipe.schema, 1);
      expect(recipe.package, 'example_plugin');
      expect(recipe.versions.allows(Version(1, 5, 0)), isTrue);
      expect(recipe.versions.allows(Version(2, 0, 0)), isFalse);
      expect(recipe.source, 'https://pub.dev/packages/example_plugin');
      expect(recipe.origin, 'full.yaml');

      expect(
        recipe.requirements.map(
          (r) => (r.platform, r.kind, r.key, r.necessity),
        ),
        [
          (
            NativePlatform.ios,
            RequirementKind.infoPlistKey,
            'NSCameraUsageDescription',
            Necessity.required,
          ),
          (
            NativePlatform.ios,
            RequirementKind.infoPlistKey,
            'LSApplicationQueriesSchemes',
            Necessity.whenUsed,
          ),
          (
            NativePlatform.ios,
            RequirementKind.entitlement,
            'aps-environment',
            Necessity.required,
          ),
          (
            NativePlatform.ios,
            RequirementKind.backgroundMode,
            'remote-notification',
            Necessity.required,
          ),
          (
            NativePlatform.ios,
            RequirementKind.manual,
            'appdelegate-key',
            Necessity.required,
          ),
          (
            NativePlatform.android,
            RequirementKind.permission,
            'android.permission.CAMERA',
            Necessity.required,
          ),
          (
            NativePlatform.android,
            RequirementKind.query,
            'intent:android.intent.action.VIEW scheme=https',
            Necessity.whenUsed,
          ),
          (
            NativePlatform.android,
            RequirementKind.query,
            'package:com.example.other',
            Necessity.whenUsed,
          ),
          (
            NativePlatform.android,
            RequirementKind.metaData,
            'com.example.API_KEY',
            Necessity.required,
          ),
          (
            NativePlatform.android,
            RequirementKind.component,
            'com.example.Receiver',
            Necessity.whenUsed,
          ),
          (
            NativePlatform.android,
            RequirementKind.activityClass,
            'io.flutter.embedding.android.FlutterFragmentActivity',
            Necessity.required,
          ),
          (
            NativePlatform.android,
            RequirementKind.manual,
            'desugaring',
            Necessity.required,
          ),
        ],
      );

      final byKey = {for (final r in recipe.requirements) r.key: r};
      expect(byKey['LSApplicationQueriesSchemes']!.expectType, PlistType.array);
      expect(
        byKey['aps-environment']!.source,
        'https://developer.apple.com/aps',
      );
      expect(
        byKey['com.example.Receiver']!.componentKind,
        ComponentKind.receiver,
      );
      expect(
        byKey['package:com.example.other']!.query!.package,
        'com.example.other',
      );
      expect(byKey['NSCameraUsageDescription']!.hint, 'Explain camera use');
    });

    test('a minimal recipe with empty or null sections', () {
      final recipe = parseRecipe('''
schema: 1
package: tiny
versions: any
source: https://pub.dev/packages/tiny
ios:
  info_plist: {}
  entitlements:
android:
  permissions: {}
  queries: []
''', origin: 'tiny.yaml');
      expect(recipe.requirements, isEmpty);
    });
  });

  group('parseRecipe rejects', () {
    for (final sample in invalidRecipes) {
      test(sample.description, () {
        expect(
          () => parseRecipe(sample.yaml, origin: 'bad.yaml'),
          throwsA(
            isA<RecipeFormatException>()
                .having(
                  (e) => e.problems.join('\n'),
                  'problems',
                  contains(sample.problem),
                )
                .having((e) => e.message, 'message', contains('bad.yaml')),
          ),
        );
      });
    }

    test('reports every problem at once', () {
      try {
        parseRecipe(
          'schema: 2\npackage: Bad-Name\nversions: "?"\nsource: http://x',
          origin: 'bad.yaml',
        );
        fail('expected RecipeFormatException');
      } on RecipeFormatException catch (e) {
        expect(e.problems, hasLength(4));
      }
    });
  });
}
