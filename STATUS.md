# STATUS

_Last updated: 2026-11-01_

## Current milestone
v0.0.1 — `plumb doctor` (read-only). Step 13 of 15: wire `doctor`, fixtures + goldens.

## Checklist (ARCHITECTURE.md §12; recipes moved before goldens on 2026-11-01)
- [x] 1. Docs: ARCHITECTURE, STRATEGY, STATUS, CONTRIBUTING, CLAUDE.md
- [x] 2. Scaffold: pubspec, analysis_options, bin/, CLI stub, CI workflow
- [x] 3. Plist parser (+ binary detection)
- [x] 4. AndroidManifest + activity source parsers
- [x] 5. Recipe model + strict parser
- [x] 6. JSON Schema + agreement test
- [x] 7. Recipe index + bundled generator + freshness test
- [x] 8. Project detection + dependency resolution
- [x] 9. Snapshot loader
- [x] 10. Checks (iOS, Android, app-level, placeholder)
- [x] 11. Report model, text + JSON renderers, exit codes
- [x] 12. Recipes (10 plugins, 12 files, every URL + anchor verified live)
- [ ] 13. Wire `doctor`; fixtures + goldens (on real recipes)
- [ ] 14. README, CHANGELOG, example/, pubspec metadata, publish dry-run
- [ ] 15. Validate on a real Flutter app

## Open decisions (owner review — none blocking)
Recipe calls made from the docs; please confirm or overrule:
1. **image_picker** — README lists `NSCameraUsageDescription` unconditionally → `required: true`
   (CLAUDE.md's original example had `when_used`).
2. **camera** — README says add both camera and microphone strings → both `required: true`.
3. **local_auth** — README says add `USE_BIOMETRIC`, but `local_auth_android`'s own manifest declares
   it (merged automatically) → `when_used`, hint explains.
4. **firebase_messaging** — Firebase guide says enable Background fetch + Remote notifications; the
   official example app (14.x–17.x) only enables `remote-notification` → `fetch` is `when_used`.
   Range `>=14 <18` is backed by the (unversioned) guide + each major's example app.
5. **geolocator** — split at 14.1.1: README changed from "COARSE *or* FINE" to "COARSE required".
   Older range reports both as ℹ (schema 1 can't say "one of").
6. **firebase_messaging** — split at 17.0.0 (UIScene `configureNotificationCenterDelegate` step is new).

## Known issues / limitations (by design for v0.0.1)
- Only main AndroidManifest and `ios/Runner/Info.plist` are checked; flavor files are listed as ℹ.
- No Gradle / Podfile / SwiftPM / AppDelegate parsing; such steps appear as ℹ manual items.
- "One of these" requirements (geolocator < 14.1.1 location permissions) can't be expressed → ℹ.
- `pubspec.lock` can't distinguish transitive deps of dev dependencies (nor dev deps of workspace members).
- Unicode symbols in text output; no ASCII fallback yet (use `--json` on legacy consoles).

## Ideas parked (not in scope, raise later)
- `tool/check_recipe_links.dart`: verify every recipe URL/anchor (done by hand for v0.0.1).
- CI job that diffs upstream READMEs to flag stale recipes.
