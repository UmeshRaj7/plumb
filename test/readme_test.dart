import 'dart:io';

import 'package:plumb/src/recipes/bundled.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

/// The README's "Supported plugins" table must match the bundled recipes, so
/// what we claim on pub.dev is exactly what plumb checks.
void main() {
  final readme = File('README.md').readAsStringSync();
  final recipes = bundledRecipes();
  final packages = {for (final r in recipes) r.package}.toList()..sort();

  for (final package in packages) {
    test('README lists $package with its recipe version range', () {
      final ranges = [
        for (final r in recipes)
          if (r.package == package) r.versions as VersionRange,
      ];
      final min = ranges.map((r) => r.min!).reduce((a, b) => a < b ? a : b);
      final max = ranges.map((r) => r.max!).reduce((a, b) => a > b ? a : b);
      // pub_semver stores "<2.0.0" as "<2.0.0-0" (no pre-releases of 2.0.0);
      // the README shows the bound as written in the recipe.
      final shownMax = '$max'.replaceFirst(RegExp(r'-0$'), '');
      expect(
        readme,
        contains(
          '| [$package](https://pub.dev/packages/$package) | '
          '$min – <$shownMax |',
        ),
      );
    });
  }

  test('README lists no plugin without a recipe', () {
    final listed = RegExp(
      r'^\| \[(\w+)\]\(https://pub\.dev/packages/\w+\) \|',
      multiLine: true,
    ).allMatches(readme).map((m) => m.group(1)).toList();
    expect(listed, packages);
  });
}
