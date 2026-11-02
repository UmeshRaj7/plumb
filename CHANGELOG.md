# Changelog

## 0.1.0

Fewer false alarms, based on running plumb on popular open-source Flutter apps.

- **image_picker:** a missing `NSCameraUsageDescription` is now ℹ ("needed if you
  use `ImageSource.camera`") instead of ✗. Apps that only pick from the gallery
  don't need it.
- **camera:** a missing `NSMicrophoneUsageDescription` is now ℹ ("needed unless
  every `CameraController` uses `enableAudio: false`") instead of ✗.
- README: what to do when the `plumb` command is not found (common on Windows),
  running it with `dart pub global run plumb doctor`, and the dev_dependency
  option (`flutter pub add --dev plumb` + `dart run plumb doctor`).
- README: how to update, and `actions/checkout` in the CI example.
- README screenshot and JSON example updated to the new output.
- Releases are now published from GitHub Actions when a version tag is pushed.

Updating: `dart pub global activate plumb`. As a dev dependency, `^0.0.1` only
allows 0.0.1, so run `flutter pub upgrade --major-versions plumb` once. From
`^0.1.0` on, later 0.1.x fixes arrive with a normal `flutter pub upgrade`, which
is why this release is 0.1.0 rather than 0.0.2.

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
