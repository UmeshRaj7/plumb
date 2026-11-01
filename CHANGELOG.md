# Changelog

## 0.0.1

First release: `plumb doctor`, a read-only check of native config.

- Checks `ios/Runner/Info.plist`, `ios/Runner/*.entitlements` and
  `android/app/src/main/AndroidManifest.xml` (plus the launcher activity's base
  class) against bundled recipes.
- Recipes for 10 plugins, each written from the plugin's own docs and cited:
  camera, firebase_messaging, flutter_local_notifications, geolocator,
  google_maps_flutter, image_picker, local_auth, permission_handler,
  sign_in_with_apple, url_launcher.
- Flags placeholder purpose strings (empty, `TODO`, `your … here`…) in every
  `*UsageDescription`, with or without a recipe.
- Text output, `--json` (format 1), `--strict`, `--verbose`, `--[no-]color`
  (respects `NO_COLOR`).
- Exit codes: 0 ok, 1 `--strict` findings, 2 incomplete check, 64 usage error.
- Never writes to the project it checks.
