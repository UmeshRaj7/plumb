import 'checks/doctor_checks.dart';
import 'checks/doctor_report.dart';
import 'project/flutter_project.dart';
import 'project/snapshot_loader.dart';
import 'recipes/bundled.dart';
import 'recipes/recipe.dart';
import 'recipes/recipe_index.dart';

/// Checks the Flutter app containing [startDirectory] against [recipes]
/// (the bundled recipes by default). Read-only: never writes to the project.
///
/// Throws `PlumbException` when [startDirectory] isn't inside a Flutter app
/// or its dependencies can't be resolved.
DoctorReport runDoctor(String startDirectory, {List<Recipe>? recipes}) {
  final project = findFlutterProject(startDirectory);
  final snapshot = loadSnapshot(project);
  return runChecks(snapshot, RecipeIndex(recipes ?? bundledRecipes()));
}
