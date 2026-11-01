# STATUS

_Last updated: 2026-11-01_

## Current milestone
v0.0.1 — `plumb doctor` (read-only). Step 10 of 15: checks.

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
- [ ] 10. Checks (iOS, Android, app-level, placeholder)
- [ ] 11. Report model, text + JSON renderers, exit codes
- [ ] 12. Recipes (10, cited)
- [ ] 13. Wire `doctor`; fixtures + goldens (on real recipes)
- [ ] 14. README, CHANGELOG, example/, pubspec metadata, publish dry-run
- [ ] 15. Validate on a real Flutter app

## Open decisions (need owner input)
_None blocking._ Flagged for review when recipes land:
- image_picker README lists `NSCameraUsageDescription` unconditionally → recipe uses `required: true`
  (CLAUDE.md's original example had `when_used`).
- local_auth README says add `USE_BIOMETRIC`, but `local_auth_android`'s own manifest already
  declares it → recipe uses `when_used` (manifest merger).
- firebase_messaging docs say enable Background fetch + Remote notifications; the official example
  app only enables `remote-notification` (+ `processing`) → `fetch` is `when_used`.

## Known issues / limitations (by design for v0.0.1)
- Only main AndroidManifest and `ios/Runner/Info.plist` are checked; flavor files are listed as ℹ.
- No Gradle / Podfile / SwiftPM / AppDelegate parsing; such steps appear as ℹ manual items.
- `pubspec.lock` can't distinguish transitive deps of dev dependencies.
- Unicode symbols in text output; no ASCII fallback yet (use `--json` on legacy consoles).
