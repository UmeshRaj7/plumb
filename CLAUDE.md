# plumb — native config for Flutter

> Vision tagline (long term, NOT for v0.0.1 copy): "Expo-style prebuild for Flutter™. Declare native config once."
> v0.0.1 public description: "plumb — native config for Flutter™. `plumb doctor` checks your iOS and
> Android config against what your plugins' docs require. Read-only."
> Flutter and the related logo are trademarks of Google LLC. plumb is not affiliated with or endorsed by Google.

Related docs (keep in sync — update in the same commit as any decision change):
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — design source of truth for v0.0.1
- [docs/STRATEGY.md](docs/STRATEGY.md) — positioning, honest claims, decisions log, launch, risks
- [STATUS.md](STATUS.md) — current milestone, checklist, open decisions, known issues
- [CONTRIBUTING.md](CONTRIBUTING.md) — code style and how to write a recipe

## What this project is
An open-source Dart CLI that lets Flutter apps and plugins **declare** the native setup they need
(permission purpose strings, Info.plist keys, entitlements, AndroidManifest permissions/queries,
URL schemes, deep links, SDK levels) and then **checks** — and later **applies** — that config to
`ios/` and `android/` safely and idempotently.

Why it matters (research, Oct 2026):
- Flutter Q2 2026 survey: top dissatisfaction theme was "Platform and ecosystem maturity" (44%) —
  upgrade pain, version-matrix guesswork, native setup.
- 2026 migration wave: SwiftPM default (CocoaPods trunk read-only Dec 2, 2026), UIScene required
  with Xcode 27, AGP 9 / built-in Kotlin, Play 16 KB page size, targetSdk 36 floor.
- No plugin-level declarative native-config system exists on pub.dev. Expo (React Native) has
  config plugins + prebuild; Flutter has nothing comparable. flutter/flutter#77104 (custom create
  templates) still open; #117883 (generate Info.plist from config) closed as not planned.

Goal order: (1) reputation in the Flutter community, (2) monetization later (open core). Build and
succeed on Flutter first — domain, npm, pro tier are explicitly deferred.

## Naming / brand rules
- Package + CLI name: `plumb` (pub.dev name still free on 2026-11-01).
- Never brand it "Flutter Plumb" / "Flutter Prebuild" — Flutter brand guidelines forbid using the
  Flutter mark in product names. Use "plumb — native config for Flutter™" in descriptions.
- Another unrelated company "Plumb" (Murmur Labs, AI pipeline builder) owns plumb.dev. Fine for
  OSS; do a trademark search before any paid tier.
- **Honest copy rule:** pubspec description, README, CLI help and posts describe only what the
  released version does. No "prebuild", "apply", "fix" or "never open Xcode" until those ship.

## Current milestone: v0.0.1 — `plumb doctor` (READ-ONLY)
```
dart pub global activate plumb
cd my_flutter_app && plumb doctor [path] [--json] [--strict] [--verbose]
```
Behaviour (details: ARCHITECTURE.md §5–§6):
1. Detect the Flutter app root (nearest pubspec.yaml with a flutter SDK dependency; plugin and
   pure-Dart packages are rejected with a clear message).
2. Resolve plugins from `pubspec.lock` (excluding `direct dev`); fallback
   `.dart_tool/package_config.json`. Workspaces: look at the workspace root.
3. Load bundled recipes; match by package name + version range (`pub_semver`).
4. Compare requirements against:
   - `ios/Runner/Info.plist` (XML plist; binary plist → clear error)
   - `ios/Runner/*.entitlements`
   - `ios/Runner.xcodeproj/project.pbxproj` (text search for `INFOPLIST_KEY_*` only → ℹ, never ✗)
   - `android/app/src/main/AndroidManifest.xml`
   - the launcher activity's `.kt`/`.java` source (only for `activity_class`)
5. Report findings: ✓ ok, ✗ missing (or error), ⚠ placeholder / wrong type / partial,
   ℹ conditional (`when_used`), manual step, or "can't verify".
   Every `*UsageDescription` in Info.plist is placeholder-checked even without a recipe.
6. `--json` → machine-readable output (format 1). Exit codes: 0 ok; 1 `--strict` and any ✗/⚠;
   2 incomplete (setup error or unreadable native file); 64 usage error.

Hard rule for v0.0.1: **plumb writes nothing to the user's project.** Trust first, `apply` later.
Precision over recall: when unsure, report ℹ, never ✗.

### Bundled recipes (first 10)
image_picker, camera, geolocator, local_auth, url_launcher, firebase_messaging,
google_maps_flutter, flutter_local_notifications, sign_in_with_apple, permission_handler.

Every recipe MUST be written from the plugin's own docs (README, endorsed platform package
README, or the official docs it links to) and include a `source:` URL. Do not invent requirements.
If unsure, mark `required: when_used` with a hint. If the plugin's own AndroidManifest already
declares a permission, it is NOT `required: true` (manifest merger adds it). `versions:` covers only
versions whose docs were actually compared. Requirements in files plumb doesn't read → `manual:`.

### Recipe format — schema 1 (full spec: ARCHITECTURE.md §7)
```yaml
# recipes/image_picker.yaml
schema: 1
package: image_picker
versions: ">=0.8.0 <2.0.0"
source: https://pub.dev/packages/image_picker#ios
ios:
  info_plist:
    NSPhotoLibraryUsageDescription: { required: true, hint: "Why your app reads photos" }
    NSMicrophoneUsageDescription: { required: when_used, hint: "Needed if you record videos" }
  entitlements: {}
  background_modes: {}
  manual: []
android:
  permissions: {}          # name → spec
  queries: []              # [{ intent: {action, scheme?, mime_type?} | package: name, required, hint }]
  manifest_meta_data: {}
  components: {}           # name → { kind: activity|receiver|service|provider, required, hint }
  activity_class: {}       # at most one: class → spec
  manual: []               # [{ id, required, hint, source? }]
```
Spec: `required` (`true` | `when_used`), `hint`, optional `source`, `expect_type` (iOS plist only).
Unknown keys are errors. Validated by the Dart parser at load time and by
`schema/recipe.schema.json` in tests (agreement test, `json_schema` dev dependency).
Recipes are embedded via `tool/generate_bundled_recipes.dart` → `lib/src/recipes/bundled_recipes.g.dart`.

## Repo layout
```
plumb/
  bin/plumb.dart
  lib/plumb.dart           # public API: runDoctor + models
  lib/src/cli/             # CommandRunner, doctor command, exit codes
  lib/src/project/         # detect Flutter app, resolve dependencies, load snapshot (only I/O here + cli)
  lib/src/parsers/         # plist (XML), AndroidManifest, activity source — pure
  lib/src/recipes/         # model, strict parser, index, bundled (generated)
  lib/src/checks/          # recipe vs snapshot → findings — pure
  lib/src/report/          # text + json renderers — pure
  recipes/*.yaml           # source of truth for bundled recipes
  schema/recipe.schema.json
  tool/                    # generate_bundled_recipes.dart
  test/fixtures/           # tiny sample Flutter projects (good, broken, edge cases)
  test/goldens/            # expected text + json output
  docs/                    # ARCHITECTURE.md, STRATEGY.md
```
Dependencies: args, yaml, xml, path, pub_semver, package_config. Dev: test, lints, json_schema.
SDK `^3.8.0`. Pure Dart; must run on Linux/macOS/Windows without Xcode.

## Engineering conventions (full list: CONTRIBUTING.md)
- Simple, readable, testable. Plain classes + top-level functions; no deep patterns.
- Parsers and checks are pure functions over file contents; no I/O inside checks.
- Every finding has: id, severity, package, platform, file, key, message, fix hint, source URL.
- Golden-test the text and JSON output against fixtures. Output is deterministic (no abs paths).
- Keep `dart analyze` clean with `package:lints/recommended.yaml`; aim for 160/160 pub points.
- CHANGELOG.md, example/, and a README with a 20-second GIF before publishing.

## Working agreement (for Claude Code)
- Each milestone step: tests first where practical → implement → `dart format .`,
  `dart analyze` (zero issues), `dart test` → small Conventional Commit → update STATUS.md.
- Never push or publish unless the owner says so. No new dependencies without asking.
- Decisions change → update CLAUDE.md + ARCHITECTURE.md (+ STRATEGY.md decisions log) in the same commit.
- Raise scope cuts, better approaches, launch ideas and competitor risks briefly with a recommendation;
  never silently change scope. Ask one precise question when unsure.

## Roadmap after v0.0.1
- v0.1: `plumb.yaml` app spec (identity, SDK levels, permissions w/ localized strings, URL schemes,
  associated domains/App Links, entitlements, flavors) + `apply` (marker-region, idempotent,
  never clobbers hand edits) + `check` (CI drift) + `diff`.
- Plugin-shipped recipes: auto-discover `plumb.yaml` inside dependency packages; community recipe
  registry repo for plugins that haven't adopted it (DefinitelyTyped model — this is the moat).
- Migration packs as rules: UIScene, 16 KB / NDK, AGP 9 built-in Kotlin, targetSdk floor,
  SwiftPM-vs-CocoaPods report.
- AI-agent surface: MCP server (add_capability, explain_native_config, validate) + agent skill.
- Later (only after traction): GitHub Action, auto-PR app, pro tier, ports (Capacitor, KMP, MAUI).

## Launch plan for v0.0.1 (details: docs/STRATEGY.md)
Run `plumb doctor --json` on 20–30 popular open-source Flutter apps, **hand-verify every ✗/⚠**,
then publish the data ("X of 25 popular OSS Flutter apps ship missing/placeholder permission
strings"). Post on r/FlutterDev, X, LinkedIn, Flutter forum. Open friendly PRs/issues on affected repos.
