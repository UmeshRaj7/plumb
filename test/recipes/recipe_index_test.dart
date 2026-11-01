import 'package:plumb/src/errors.dart';
import 'package:plumb/src/recipes/recipe.dart';
import 'package:plumb/src/recipes/recipe_index.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

Recipe recipe(String package, String versions, {String? origin}) => Recipe(
  package: package,
  versions: VersionConstraint.parse(versions),
  source: 'https://pub.dev/packages/$package',
  origin: origin ?? '$package.yaml',
  requirements: const [],
);

void main() {
  final v1 = recipe('a', '>=1.0.0 <2.0.0', origin: 'a.yaml');
  final v2 = recipe('a', '>=2.0.0 <3.0.0', origin: 'a@2.yaml');
  final index = RecipeIndex([v1, v2]);

  test('finds the recipe whose range allows the version', () {
    final lookup = index.lookup('a', Version(2, 1, 0));
    expect(lookup.status, LookupStatus.found);
    expect(lookup.recipe, same(v2));
  });

  test('reports a version outside every range', () {
    final lookup = index.lookup('a', Version(3, 0, 0));
    expect(lookup.status, LookupStatus.versionNotCovered);
    expect(lookup.candidates, [v1, v2]);
  });

  test('reports an unknown version', () {
    expect(index.lookup('a', null).status, LookupStatus.versionUnknown);
  });

  test('reports packages without recipes', () {
    expect(index.lookup('b', Version(1, 0, 0)).status, LookupStatus.noRecipe);
  });

  test('pre-releases of the next major are not covered (pub semantics)', () {
    expect(
      index.lookup('a', Version.parse('3.0.0-dev.1')).status,
      LookupStatus.versionNotCovered,
    );
  });

  test('rejects overlapping ranges for the same package', () {
    expect(
      () => RecipeIndex([v1, recipe('a', '>=1.5.0', origin: 'overlap.yaml')]),
      throwsA(
        isA<PlumbException>().having(
          (e) => e.message,
          'message',
          allOf(contains('a.yaml'), contains('overlap.yaml')),
        ),
      ),
    );
  });
}
