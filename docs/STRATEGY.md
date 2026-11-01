# plumb — Strategy

Positioning, honest claims, launch, risks. The technical design is in
[ARCHITECTURE.md](ARCHITECTURE.md); current progress is in [../STATUS.md](../STATUS.md).

## Positioning

- **Vision (long term):** declarative native config for Flutter — apps and plugins declare
  what they need, plumb checks and later applies it (Expo-style prebuild).
- **What we say for v0.0.1:** *"plumb — native config for Flutter™. `plumb doctor` checks
  your iOS and Android config against what your plugins' docs require. Read-only."*
- We do **not** say "never open Xcode again", "prebuild", "fixes", or "applies" until
  `apply` ships. Every public text (pubspec description, README, CLI help, posts) must
  describe only what the released version does.

## Claims we can make for v0.0.1 (and their limits)

| Claim | Limit we state openly |
|---|---|
| Checks Info.plist, entitlements, AndroidManifest against 10 popular plugins | Main manifest/plist only; flavors listed but not checked |
| Flags placeholder purpose strings (empty, "TODO", "your … here") | Can't judge whether a real sentence is good enough for App Review |
| Every finding links to the plugin's documentation | Recipes reflect docs as of the recipe's date and version range |
| JSON output for CI and AI agents | Format 1; additive changes only |
| Never modifies your project | — |
| Lists manual steps (Gradle, Podfile, AppDelegate) it can't verify | Shown as ℹ, never ✗ |

## Decisions log (v0.0.1)

| Decision | Why |
|---|---|
| `pubspec.lock` primary, `package_config.json` fallback | lock has versions + dev/transitive info; works on repos without `pub get` (launch scan) |
| `--strict` fails on ✗ **and** ⚠; exit 2 for incomplete results; 64 for usage | placeholder strings get App Store rejections; CI must not pass on a partial run |
| Recipes embedded via generated Dart file | files outside `lib/` aren't readable after global activate / compile exe |
| Strict Dart validator + JSON Schema, agreement tested with `json_schema` (dev only) | runtime needs good error messages; editors need the schema; test prevents drift |
| Keep `permission_handler` | most-used permission plugin; its purpose strings get placeholder checks; conditional items collapse to one line |
| Recipe-independent placeholder check on all `*UsageDescription` keys | it's the launch headline and deterministic |
| `android.components` added to schema 1 | two of the ten plugins document required `<receiver>`/`<activity>` entries |
| `manual` steps in recipes | honest coverage of requirements outside the files we read |
| Downgrade "README says add X" to `when_used` when the plugin's own manifest already declares X | Android manifest merger adds it; reporting ✗ would be a false positive |
| Recipe version ranges only cover versions whose docs we compared | no invented coverage; uncovered versions show ℹ |
| SDK `^3.8.0` (Flutter 3.32+) | broad reach; dependency ranges allow newest majors too |

## Launch plan (after v0.0.1 is DONE)

1. Pick 25 popular open-source Flutter apps (list + selection criteria committed in repo).
2. Run `plumb doctor --json` on each at a pinned commit; store raw JSON.
3. **Hand-verify every ✗ and ⚠** before publishing a number. Drop anything ambiguous.
4. Publish the write-up with methodology and the data; post on r/FlutterDev, X,
   LinkedIn, Flutter forum.
5. Open friendly issues/PRs on affected repos (one per repo, with the doc link).

## Risks

| Risk | Mitigation |
|---|---|
| False positives damage reputation | precision rules (ARCHITECTURE §2, §5.4), hand-verified launch data |
| Recipes go stale as plugins change | version ranges + `source` URLs; CI job later to diff upstream READMEs |
| Google/Flutter team ships something similar | move fast to plugin-shipped recipes (the moat is the recipe ecosystem) |
| AI coding agents do native setup ad hoc | `--json` now, MCP server later: be the tool agents call |
| "Plumb" trademark (Murmur Labs owns plumb.dev) | fine for OSS; trademark search before any paid tier |

## Deferred (not in v0.0.1)
`apply`, `plumb.yaml` app spec, plugin-shipped recipes, migration packs, MCP server,
GitHub Action, macOS/desktop, flavor-aware checks, Gradle/Podfile parsing. See CLAUDE.md roadmap.
