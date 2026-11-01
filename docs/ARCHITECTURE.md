# plumb — Architecture (v0.0.1)

This document is the design source of truth for v0.0.1 (`plumb doctor`, read-only).
If code and this document disagree, one of them is a bug — fix both in the same commit.

- Audience: contributors and future maintainers.
- Scope: what exists in v0.0.1. Future ideas live in [STRATEGY.md](STRATEGY.md), not here.

---

## 1. What v0.0.1 does (and does not)

`plumb doctor` reads a Flutter app, works out which plugins it uses, and compares the
native setup those plugins document against three kinds of files:

| Platform | File(s) read | Used for |
|---|---|---|
| iOS | `ios/Runner/Info.plist` (XML) | purpose strings, `UIBackgroundModes`, other keys |
| iOS | `ios/Runner/*.entitlements` (XML) | entitlements (e.g. `aps-environment`) |
| iOS | `ios/Runner.xcodeproj/project.pbxproj` (text search only) | detect `INFOPLIST_KEY_*` build settings, so we don't report keys set there as missing |
| Android | `android/app/src/main/AndroidManifest.xml` | permissions, `<queries>`, `<meta-data>`, components |
| Android | `MainActivity.kt` / `.java` (found via the launcher activity) | `activity_class` (e.g. `FlutterFragmentActivity`) |

**It never writes to the user's project.** No temp files, no caches, no "fixing".

It does **not** check (documented in README "What plumb does not check"):
Gradle files (minSdk, desugaring), Podfile / SwiftPM settings, `AppDelegate` code,
merged manifests from plugins, flavor-specific manifests/plists, localized
`InfoPlist.strings`, macOS/web/desktop, Firebase config files. Where a plugin's docs
require one of these, the recipe lists it as a **manual** step, shown as ℹ.

## 2. Design principles

1. **Precision over recall.** A wrong ✗ costs more trust than a missed one. When plumb
   can't be sure, it says ℹ ("can't verify") instead of ✗.
2. **Every finding is cited.** Each one carries the URL of the plugin doc it came from.
3. **Pure core, thin shell.** Parsers and checks are pure functions over strings/models.
   All file I/O lives in one place (`project/snapshot_loader.dart`). Tests need no disk
   except fixture/golden tests.
4. **Shallow structure.** Plain classes, top-level functions, `switch` over enums. No DI
   framework, no abstract factories, no plugin system in v0.0.1.
5. **Stable contracts.** The recipe format (schema 1) and the JSON output (format 1) are
   public contracts. Additive changes only; breaking changes bump the number.

## 3. Data flow

```
plumb doctor [path]
      │
      ▼
findFlutterProject(start)          project/flutter_project.dart   (I/O: reads pubspec.yaml)
      │  FlutterProject
      ▼
loadSnapshot(project)              project/snapshot_loader.dart   (I/O: the ONLY place that reads native files)
      │  ProjectSnapshot  ← uses pure parsers: parsers/plist.dart, parsers/android_manifest.dart,
      │                     parsers/activity_source.dart, project/dependencies.dart
      ▼
runChecks(snapshot, recipes)       checks/doctor_checks.dart      (pure)
      │  DoctorReport (findings + summary)
      ▼
renderText(report) / renderJson(report)   report/                 (pure, returns String)
      │
      ▼
stdout + exit code                 cli/                           (I/O)
```

## 4. Modules and public API

Signatures are indicative; dartdoc on the code is authoritative.

### `bin/plumb.dart`
`Future<void> main(List<String> args)` → `exitCode = await runCli(args)`.

### `lib/plumb.dart` (package public API)
Exports the models and `runDoctor`. Everything else stays in `lib/src/`.
```dart
DoctorReport runDoctor(String startDirectory, {List<Recipe>? recipes});
// + Finding, Severity, NativePlatform, DoctorReport, Recipe, Requirement, PlumbException
```

### `lib/src/cli/`
- `cli.dart` — `Future<int> runCli(List<String> args)`; builds the `CommandRunner`,
  maps exceptions to exit codes, prints errors.
- `doctor_command.dart` — `DoctorCommand`: flags, calls `runDoctor`, picks renderer.

### `lib/src/project/`
- `flutter_project.dart` — `FlutterProject findFlutterProject(String start)`:
  walks up from `start` to the nearest `pubspec.yaml`; validates it is a Flutter **app**.
  Fields: `root`, `name`, `resolutionRoot` (workspace root when `resolution: workspace`).
- `dependencies.dart` — pure:
  `List<ResolvedPackage> parsePubspecLock(String yaml)`,
  `List<ResolvedPackage> parsePackageConfig(String json, {required Uri configUri})`.
  `ResolvedPackage { name, Version? version, DependencyKind kind }`.
- `snapshot.dart` — models: `ProjectSnapshot`, `IosFiles`, `AndroidFiles`,
  `FileRead<T>` (path + value or problem).
- `snapshot_loader.dart` — `ProjectSnapshot loadSnapshot(FlutterProject)`.
  Reads files, calls parsers, never throws for a bad native file (records the problem
  instead, so the report can show it).

### `lib/src/parsers/` (all pure, `String` in → model out, throw `FormatException`)
- `plist.dart` — `Map<String, Object?> parsePlist(String xml)`; `bool looksLikeBinaryPlist(List<int> bytes)`.
- `android_manifest.dart` — `AndroidManifest parseAndroidManifest(String xml)`.
- `activity_source.dart` — `String? findSuperclass(String source, String className)`.

### `lib/src/recipes/`
- `recipe.dart` — `Recipe`, `Requirement`, enums.
- `recipe_parser.dart` — `Recipe parseRecipe(String yaml, {required String origin})`;
  strict validation, throws `RecipeFormatException(origin, List<String> problems)`.
- `recipe_index.dart` — `RecipeIndex(List<Recipe>)`, `RecipeLookup lookup(String package, Version? version)`;
  constructor rejects overlapping ranges for the same package.
- `bundled_recipes.g.dart` — **generated** from `recipes/*.yaml` by
  `tool/generate_bundled_recipes.dart` (see §8). `bundled.dart` — `List<Recipe> bundledRecipes()`.

### `lib/src/checks/` (pure)
- `finding.dart` — `Finding`, `Severity`, `NativePlatform`.
- `placeholder.dart` — `bool isPlaceholder(String)`, `bool isBuildVariable(String)`.
- `ios_checks.dart` — `List<Finding> checkIosRequirement(Requirement, Recipe, IosFiles)`.
- `android_checks.dart` — `List<Finding> checkAndroidRequirement(Requirement, Recipe, AndroidFiles)`.
- `project_checks.dart` — findings not tied to one recipe (see §6.3).
- `doctor_checks.dart` — `DoctorReport runChecks(ProjectSnapshot, RecipeIndex)`.
- `doctor_report.dart` — `DoctorReport { project, packages, findings, summary; int exitCode({required bool strict}) }`.

### `lib/src/report/` (pure, return `String`)
- `text_renderer.dart` — `String renderText(DoctorReport, {bool color, bool verbose})`.
- `json_renderer.dart` — `String renderJson(DoctorReport)`.

### `lib/src/doctor.dart`
`runDoctor` = `findFlutterProject` → `loadSnapshot` → `runChecks`. ~15 lines, no logic.

## 5. Data model

### 5.1 Recipe / Requirement
```dart
class Recipe {
  final int schema;                 // 1
  final String package;             // pub package name
  final VersionConstraint versions; // pub_semver
  final String source;              // https URL of the plugin's setup docs
  final String origin;              // recipe file name, for error messages
  final List<Requirement> requirements;
}

enum NativePlatform { ios, android }
enum RequirementKind {
  infoPlistKey, entitlement, backgroundMode,                  // iOS
  permission, query, metaData, component, activityClass,      // Android
  manual,                                                     // either; never verifiable
}
enum Necessity { required, whenUsed }   // YAML: `true` | `when_used`

class Requirement {
  final NativePlatform platform;
  final RequirementKind kind;
  final String key;                 // NSCameraUsageDescription, android.permission.CAMERA, manual id, …
  final Necessity necessity;
  final String hint;                // human sentence: why / what to add
  final String? source;             // overrides Recipe.source when the fact is on another page
  final PlistType? expectType;      // infoPlistKey / entitlement only
  final AndroidQuery? query;        // kind == query
  final ComponentKind? componentKind; // kind == component
}
```
One `Requirement` class with a `kind` (instead of a class per kind) keeps parsing,
sorting and rendering trivial; checks `switch` on `kind`.

### 5.2 ProjectSnapshot
```dart
class ProjectSnapshot {
  final String name;
  final String root;                       // absolute; never printed (goldens stay portable)
  final DependencySource dependencySource; // pubspecLock | packageConfig
  final List<ResolvedPackage> packages;    // dev dependencies already excluded
  final IosFiles? ios;                     // null when ios/ does not exist
  final AndroidFiles? android;             // null when android/ does not exist
}
class IosFiles {
  final FileRead<Map<String, Object?>> infoPlist;
  final List<FileRead<Map<String, Object?>>> entitlements; // every ios/Runner/*.entitlements
  final String? pbxproj;                                   // raw text, for INFOPLIST_KEY_ lookup
  final List<String> otherInfoPlists;                      // e.g. Info-dev.plist → ℹ "not checked"
}
class AndroidFiles {
  final FileRead<AndroidManifest> manifest;
  final FileRead<String>? mainActivitySource;              // null if not locatable
  final List<String> otherManifests;                       // src/<flavor>/AndroidManifest.xml
}
class FileRead<T> { final String path; final T? value; final FileProblem? problem; final String? detail; }
enum FileProblem { missing, binaryPlist, malformed }
```
All paths are project-relative with `/` separators (portable output on Windows).

### 5.3 Finding
```dart
class Finding {
  final String id;          // stable: "<package|app>/<platform>/<area>/<key>", e.g. image_picker/ios/info_plist/NSCameraUsageDescription
  final Severity severity;
  final String? package;    // null = app-level / setup finding
  final NativePlatform? platform;
  final String? file;       // project-relative path
  final String? key;
  final String message;     // what plumb observed
  final String? fix;        // what to do (from recipe hint)
  final String? source;     // URL
}
enum Severity { error, missing, warning, ok, info }
```

### 5.4 Severity rules (complete table)

| Situation | Severity | Symbol |
|---|---|---|
| Native file needed for a check is missing (`ios/` exists, `Info.plist` doesn't), binary plist, malformed XML | `error` | ✗ |
| `required: true` item absent | `missing` | ✗ |
| Item present but value is a placeholder (§6.2) | `warning` | ⚠ |
| Item present but wrong plist type (`expect_type`) | `warning` | ⚠ |
| Entitlement present in some `.entitlements` files but not all | `warning` | ⚠ |
| Permission/component removed with `tools:node="remove"` and required | `missing` | ✗ |
| Item present and valid; value is a build variable `$(X)`/`${X}` (noted in message) | `ok` | ✓ |
| `required: when_used` item absent | `info` | ℹ |
| Key not in Info.plist but set as `INFOPLIST_KEY_<key>` in project.pbxproj | `info` | ℹ |
| `manual` step (Gradle, Podfile, AppDelegate…) | `info` | ℹ |
| MainActivity superclass can't be determined | `info` | ℹ |
| Plugin used but its version isn't covered by any bundled recipe | `info` | ℹ |
| `ios/` or `android/` directory absent (and a recipe needed it) | `info` | ℹ |
| Flavor manifests / extra Info*.plist found but not checked | `info` | ℹ |

### 5.5 Exit codes

| Code | Meaning |
|---|---|
| 0 | Ran to completion. With `--strict`: no `missing` and no `warning`. |
| 1 | `--strict` and at least one `missing` or `warning`. |
| 2 | plumb could not do its job: not a Flutter app, no dependency info, or any `error` finding (incomplete result). Takes precedence over 1. |
| 64 | Usage error (bad flag / argument). Dart/sysexits convention. |

`info` never affects the exit code.

## 6. Check semantics

### 6.1 Matching plugins to recipes
- Dependencies come from `pubspec.lock` (primary): every package except
  `dependency: direct dev`. Transitive packages are included (a plugin pulled in by
  another package still needs its native setup). Known limitation: transitive
  dependencies *of dev dependencies* can't be told apart in `pubspec.lock`.
- Fallback: `.dart_tool/package_config.json`. Versions are read from hosted cache paths
  (`…/hosted/pub.dev/<name>-<version>/`); otherwise version is unknown. Dev
  dependencies can't be excluded here — the report says which source was used.
- Workspaces: if the app's pubspec has `resolution: workspace`, both files are looked
  up at the workspace root. There, pub records the members' dependencies as
  `transitive`, so a member's dev dependencies can't be excluded (same limitation as above).
- Neither file → setup error (exit 2): "run `flutter pub get`".
- Lookup: recipes for the package whose `versions` constraint allows the installed
  version. Unknown version or no matching range → one ℹ finding, recipe not applied.

### 6.2 Placeholder and build-variable rules (`checks/placeholder.dart`)
A string value is a **placeholder** if, after trimming, it is empty, or (case-insensitive):
contains a word `TODO`, `FIXME`, `TBD`; contains `lorem ipsum` or `placeholder`;
matches `your … here` (e.g. *"your usage description here"*, *"YOUR KEY HERE"* — both
copied from plugin READMEs); or contains `YOUR_[A-Z_]+` (e.g. `YOUR_API_KEY`).
A value containing `$(…)` or `${…}` is a **build variable**: reported ✓ with
"resolved at build time; not verified". The list is intentionally small to avoid false ⚠.

### 6.3 App-level checks (not tied to a recipe)
- **Every** `*UsageDescription` string in Info.plist is placeholder-checked, even if no
  recipe mentions it (the core launch claim; deterministic, no false positives by design).
  Keys already checked by a matched recipe are skipped to avoid duplicates.
- Platform directory missing, flavor files not checked, dependency source used.

### 6.4 iOS rules
- `info_plist`: key present at top level of Info.plist dict. `expect_type` checked when set.
  Not present but `INFOPLIST_KEY_<key> =` appears in project.pbxproj → ℹ.
- `entitlements`: evaluated across all `ios/Runner/*.entitlements`. None exist and the
  item is required → ✗ ("no .entitlements file"). Present in all → ✓; some → ⚠.
- `background_modes`: value present in the `UIBackgroundModes` array.

### 6.5 Android rules
- Only `<manifest>` direct children / `<application>` direct children are read, matching
  where the docs tell you to put things.
- `permissions`: `<uses-permission>` or `<uses-permission-sdk-23>` with that `android:name`.
  `tools:node="remove"` counts as absent (message says it was removed explicitly).
- `queries`: a `<queries><intent>` whose `<action>` matches and whose `<data>` has every
  attribute the recipe specifies (`scheme`, `mime_type`), or `<queries><package android:name>`.
- `manifest_meta_data`: `<application><meta-data android:name>`; value placeholder-checked.
- `components`: `<application>` child of the given kind (`activity|receiver|service|provider`)
  with that `android:name` (fully-qualified compare).
- `activity_class`: find the launcher activity (intent-filter MAIN + LAUNCHER). If its
  `android:name` is the required class (fully-qualified or simple) → ✓; `FlutterActivity`
  → ✗; otherwise locate `<SimpleName>.kt|.java` under `android/app/src/main/{kotlin,java}`
  and read the superclass. Simple name equals required → ✓; `FlutterActivity` → ✗;
  anything else or file not found → ℹ (custom base classes can't be verified).

### 6.6 Native file problems
- Binary plist (`bplist00` magic) → `error`: "Info.plist is a binary plist; plumb reads
  XML plists. Convert with `plutil -convert xml1 ios/Runner/Info.plist`" (the command is a
  suggestion for the user; plumb never runs it).
- Malformed XML → `error` with the parser message. Checks against that file are skipped.
- UTF-8 BOM and CRLF are accepted.

## 7. Recipe schema 1

```yaml
# recipes/<package>.yaml (several files per package allowed if version ranges don't overlap)
schema: 1                                   # required, must be 1
package: image_picker                       # required, pub package name
versions: ">=0.8.0 <2.0.0"                  # required, pub version constraint
source: https://pub.dev/packages/image_picker#setup   # required, https URL
ios:                                        # optional
  info_plist:                               # key → spec
    NSPhotoLibraryUsageDescription: { required: true, hint: "…", expect_type: string }
  entitlements:
    aps-environment: { required: true, hint: "…", source: "https://developer.apple.com/…" }
  background_modes:
    remote-notification: { required: true, hint: "…" }
  manual:
    - { id: appdelegate-api-key, required: true, hint: "…" }
android:                                    # optional
  permissions:
    android.permission.ACCESS_COARSE_LOCATION: { required: true, hint: "…" }
  queries:
    - { intent: { action: android.support.customtabs.action.CustomTabsService }, required: when_used, hint: "…" }
    - { package: com.example.other, required: when_used, hint: "…" }
  manifest_meta_data:
    com.google.android.geo.API_KEY: { required: true, hint: "…" }
  components:
    com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver: { kind: receiver, required: when_used, hint: "…" }
  activity_class:                            # at most one entry
    io.flutter.embedding.android.FlutterFragmentActivity: { required: true, hint: "…" }
  manual:
    - { id: core-library-desugaring, required: true, hint: "…" }
```

Spec fields: `required` (`true` | `when_used`, required), `hint` (non-empty, required),
`source` (https URL, optional), `expect_type` (`string|boolean|integer|real|array|dict`,
iOS plist sections only), `kind` (components only), `id` (manual only, kebab-case).

Validation rules (enforced by `recipe_parser.dart` at load time **and** by
`schema/recipe.schema.json` in tests — a test asserts both accept/reject the same samples):
unknown keys are errors; `required: false` is an error (just omit the item); version
constraint must parse; every bundled package+range pair must not overlap.

Version matching: `VersionConstraint.parse(versions).allows(installedVersion)` (pub_semver,
same semantics as pubspec constraints, including pre-release handling).

Forward compatibility: schema 1 is strict for now because all recipes are bundled.
When v0.1 loads recipes shipped inside plugins, unknown *optional* keys will become a
warning instead of an error. A breaking change means `schema: 2`.

## 8. Bundled recipes

`recipes/*.yaml` is the source of truth (easy to read, review and copy). Files outside
`lib/` can't be read reliably after `dart pub global activate` or `dart compile exe`, so
`tool/generate_bundled_recipes.dart` embeds them as strings in
`lib/src/recipes/bundled_recipes.g.dart`. A test regenerates in memory and fails if the
committed file is stale. Embedded YAML goes through the same parser as any recipe.

## 9. CLI UX

```
plumb doctor [path] [--json] [--strict] [--verbose] [--[no-]color]
plumb --version
plumb help [command]
```
- `path` defaults to the current directory; plumb walks up to the nearest `pubspec.yaml`.
- `--json` prints JSON only (no colors, no progress text). Errors are JSON too.
- `--verbose` lists every ℹ item (by default they are counted per package).
- Colors only when stdout is a terminal that supports ANSI and `NO_COLOR` is not set.

Text output (sample):
```
plumb doctor · my_app
Checked 3 plugins with recipes (dependencies from pubspec.lock).

geolocator 14.1.2
  ✓ android  AndroidManifest.xml  android.permission.ACCESS_COARSE_LOCATION
  ✗ ios      Info.plist           NSLocationWhenInUseUsageDescription is missing
             fix:  Add NSLocationWhenInUseUsageDescription to ios/Runner/Info.plist explaining why your app needs location while in use.
             docs: https://pub.dev/packages/geolocator#usage
  ℹ 4 conditional or manual items (run with --verbose to list)

image_picker 1.2.4
  ⚠ ios      Info.plist           NSCameraUsageDescription looks like a placeholder: "TODO"
             fix:  …
             docs: https://pub.dev/packages/image_picker#ios

Summary: 5 ok · 1 missing · 1 warning · 6 info
```

JSON output (format 1):
```json
{
  "format": 1,
  "plumb_version": "0.0.1",
  "project": { "name": "my_app", "dependency_source": "pubspec.lock" },
  "packages": [
    { "name": "geolocator", "version": "14.1.2", "recipe": "geolocator.yaml", "status": "checked" }
  ],
  "findings": [
    {
      "id": "geolocator/ios/info_plist/NSLocationWhenInUseUsageDescription",
      "severity": "missing", "package": "geolocator", "platform": "ios",
      "file": "ios/Runner/Info.plist", "key": "NSLocationWhenInUseUsageDescription",
      "message": "NSLocationWhenInUseUsageDescription is missing",
      "fix": "…", "source": "https://pub.dev/packages/geolocator#usage"
    }
  ],
  "summary": { "error": 0, "missing": 1, "warning": 1, "ok": 5, "info": 6 }
}
```
The JSON contains no absolute paths or timestamps, so output is reproducible.

Ordering (both renderers): app-level findings first, then packages alphabetically, then
recipe declaration order. Deterministic output is what makes golden tests possible.

## 10. Test strategy

| Layer | Kind | Where |
|---|---|---|
| parsers | unit, inline strings (namespaces, BOM, CRLF, binary magic, malformed, `tools:node`) | `test/parsers/` |
| recipes | parser accept/reject table; JSON-schema agreement; bundled recipes valid, cited, non-overlapping, generated file fresh | `test/recipes/` |
| project | lockfile/package_config parsing; project detection (app, plugin, pure Dart, workspace) on fixtures | `test/project/` |
| checks | unit per severity rule in §5.4 with tiny in-memory snapshots | `test/checks/` |
| report | renderer unit tests | `test/report/` |
| end-to-end | fixture → text + JSON **goldens** + exit codes | `test/doctor_golden_test.dart`, `test/goldens/` |

Fixtures (`test/fixtures/`, tiny, committed — `.gitignore` re-includes their `pubspec.lock`):
`good_app`, `broken_app`, `edge_app` (build variables, INFOPLIST_KEY, partial entitlements,
flavors, uncovered version), `binary_plist_app`, `ios_only_app`, `plugin_package`,
`dart_package`, `workspace/` (workspace root + app member), `package_config_only_app`.

Goldens regenerate with `UPDATE_GOLDENS=1 dart test test/doctor_golden_test.dart`; diffs
are reviewed like code. Coverage target ≥ 90% of `lib/src` (measured ad hoc with
`dart pub global run coverage:test_with_coverage`; not a dependency).

## 11. Code conventions (summary — full list in CONTRIBUTING.md)
- One concept per file; files stay < ~300 lines; functions short and named for intent.
- Doc comments (`///`) on every public symbol; regular comments explain *why*, not *what*.
- Immutable models (`final` fields, `const` constructors where possible), no `late`.
- No I/O outside `cli/` and `project/` loaders. No global mutable state.
- Errors: user-facing problems → `PlumbException` (message is shown verbatim);
  programmer errors → let them crash in tests.
- `dart format .` + `dart analyze` (zero issues, `package:lints/recommended.yaml`) + `dart test` before every commit.

## 12. Milestones (each ≤ 1–2 h, independently committable)

| # | Step | Done when |
|---|---|---|
| 1 | Docs: ARCHITECTURE, STRATEGY, STATUS, CONTRIBUTING, CLAUDE.md | committed |
| 2 | Scaffold: pubspec, analysis_options, `bin/`, CLI with `--version` + `doctor` stub, CI workflow | analyze/test green |
| 3 | Plist parser (+binary detection) | unit tests green |
| 4 | AndroidManifest + activity source parsers | unit tests green |
| 5 | Recipe model + strict parser | accept/reject tests green |
| 6 | JSON Schema + agreement test (`json_schema` dev dep) | green |
| 7 | Recipe index + bundled generator + freshness test | green |
| 8 | Project detection + dependency resolution | fixture tests green |
| 9 | Snapshot loader | fixture tests green |
| 10 | Checks (iOS, Android, app-level, placeholder) | one test per §5.4 row |
| 11 | Report model, text + JSON renderers, exit codes | unit tests green |
| 12 | The 10 recipes, each from the plugin's own docs, cited (a few per commit) | recipe tests green |
| 13 | Wire `doctor`; fixtures + goldens (on the real recipes, so goldens show real output) | goldens green |
| 14 | README, CHANGELOG, example/, pubspec metadata | `dart pub publish --dry-run` clean |
| 15 | Validate on a real `flutter create` app with all 10 plugins | findings reviewed by hand |
