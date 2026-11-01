/// plumb — native config for Flutter™.
///
/// The command-line tool is the main entry point (`plumb doctor`). This
/// library exposes the same read-only check as a Dart API, for tools that
/// want the findings without parsing CLI output:
///
/// ```dart
/// final report = runDoctor('path/to/my_app');
/// for (final finding in report.findings) {
///   print('${finding.severity.name}: ${finding.message}');
/// }
/// ```
library;

export 'src/checks/doctor_report.dart'
    show CheckedPackage, DoctorReport, PackageStatus;
export 'src/checks/finding.dart' show Finding, Severity;
export 'src/doctor.dart' show runDoctor;
export 'src/errors.dart' show PlumbException;
export 'src/exit_codes.dart' show ExitCodes;
export 'src/project/dependencies.dart' show DependencySource;
export 'src/recipes/bundled.dart' show bundledRecipes;
export 'src/recipes/recipe.dart'
    show NativePlatform, Necessity, Recipe, Requirement, RequirementKind;
export 'src/recipes/recipe_parser.dart' show RecipeFormatException, parseRecipe;
export 'src/report/json_renderer.dart' show renderJson;
export 'src/report/text_renderer.dart' show renderText;
export 'src/version.dart' show packageVersion;
