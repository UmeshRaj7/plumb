# plumb — native config for Flutter™

`plumb doctor` checks your Flutter app's **Info.plist**, **entitlements** and
**AndroidManifest.xml** against what your plugins' own documentation says they
need: missing purpose strings, placeholder text like `"TODO"`, missing
permissions, the wrong `MainActivity` base class, and more.

**Read-only.** plumb never changes your project.

```text
$ plumb doctor
plumb doctor · my_app
Found 3 plugins with recipes (read from pubspec.lock).

camera 0.12.2
  ⚠ ios      Info.plist  NSCameraUsageDescription looks like a placeholder: "TODO"
                         also: image_picker
                         fix:  Replace it with a real value. Add NSCameraUsageDescription to Info.plist with a usage description.
                         docs: https://pub.dev/packages/camera#ios
  ✗ ios      Info.plist  NSMicrophoneUsageDescription is missing
                         fix:  Add NSMicrophoneUsageDescription to Info.plist with a usage description.
                         docs: https://pub.dev/packages/camera#ios

image_picker 1.2.4
  ✓ ios      Info.plist  NSPhotoLibraryUsageDescription is set
  ℹ 1 conditional item (run with --verbose to list)

local_auth 3.0.2
  ✓ ios      Info.plist       NSFaceIDUsageDescription is set
  ✗ android  MainActivity.kt  MainActivity extends FlutterActivity, not FlutterFragmentActivity
                              fix:  local_auth needs a FragmentActivity: make MainActivity extend FlutterFragmentActivity (or use FlutterFragmentActivity directly in AndroidManifest.xml).
                              docs: https://pub.dev/packages/local_auth_android#setup
  ℹ 1 conditional item and 1 manual step (run with --verbose to list)

Summary: 2 ok · 2 missing · 1 warning · 3 info
```

## Install

```sh
dart pub global activate plumb
```

Requires Dart 3.8+ (Flutter 3.32+). Runs on macOS, Linux and Windows; Xcode is not needed.

## Usage

```sh
cd my_flutter_app
plumb doctor            # human-readable report
plumb doctor --strict   # exit 1 if anything is missing or a placeholder (for CI)
plumb doctor --json     # machine-readable report (for CI and AI agents)
plumb doctor --verbose  # also list conditional and manual items
plumb doctor path/to/app
```

plumb finds the app by walking up to the nearest `pubspec.yaml`, reads your
dependencies from `pubspec.lock` (or `.dart_tool/package_config.json`), and
applies the recipe for each plugin version it knows.

| Symbol | Meaning |
|---|---|
| ✓ | Present and valid |
| ✗ | Required and missing, or a file plumb couldn't read |
| ⚠ | Present but a placeholder (empty, `TODO`, `your … here`…), the wrong type, or only in some `.entitlements` files |
| ℹ | Only needed for some features, a manual step plumb can't check, or something it can't verify |

**Exit codes:** `0` done (with `--strict`: nothing missing or placeholder) ·
`1` `--strict` and something is missing or a placeholder · `2` the check is
incomplete (not a Flutter app, no `pubspec.lock`, unreadable native file) ·
`64` invalid command line. ℹ never fails a run.

### In CI

```yaml
# .github/workflows/native-config.yml
- uses: dart-lang/setup-dart@v1
- run: dart pub global activate plumb
- run: plumb doctor --strict
```

## What plumb checks

| File | What |
|---|---|
| `ios/Runner/Info.plist` (XML) | purpose strings and other keys, `UIBackgroundModes`; every `*UsageDescription` is checked for placeholder text, even without a recipe |
| `ios/Runner/*.entitlements` | entitlements such as `aps-environment`, in every `.entitlements` file |
| `ios/Runner.xcodeproj/project.pbxproj` | only to notice keys set as `INFOPLIST_KEY_*` build settings (reported as ℹ, never ✗) |
| `android/app/src/main/AndroidManifest.xml` | `<uses-permission>`, `<queries>`, `<meta-data>`, `<receiver>`/`<activity>`/`<service>` |
| `MainActivity.kt` / `.java` | the base class of your launcher activity |

### Supported plugins

Each recipe is written from the plugin's own documentation and links to it in
every finding. Versions outside the range are reported as ℹ "not checked".

| Plugin | Versions |
|---|---|
| [camera](https://pub.dev/packages/camera) | 0.9.0 – <0.13.0 |
| [firebase_messaging](https://pub.dev/packages/firebase_messaging) | 14.0.0 – <18.0.0 |
| [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) | 19.0.0 – <23.0.0 |
| [geolocator](https://pub.dev/packages/geolocator) | 11.0.0 – <15.0.0 |
| [google_maps_flutter](https://pub.dev/packages/google_maps_flutter) | 2.0.0 – <3.0.0 |
| [image_picker](https://pub.dev/packages/image_picker) | 0.8.0 – <2.0.0 |
| [local_auth](https://pub.dev/packages/local_auth) | 2.0.0 – <4.0.0 |
| [permission_handler](https://pub.dev/packages/permission_handler) | 11.0.0 – <14.0.0 |
| [sign_in_with_apple](https://pub.dev/packages/sign_in_with_apple) | 5.0.0 – <9.0.0 |
| [url_launcher](https://pub.dev/packages/url_launcher) | 6.0.0 – <7.0.0 |

### What plumb does not check

Being clear about this matters more than looking complete:

- **Gradle, Podfile, Swift Package Manager, `AppDelegate`** — steps there (e.g.
  core library desugaring, Google Maps' iOS API key) are listed as ℹ manual steps.
- **Flavors** — only `ios/Runner/Info.plist` and the main `AndroidManifest.xml`
  are checked; other `Info*.plist` files and flavor manifests are listed as ℹ.
- **Merged manifests** — plumb reads your app's manifest, not the merged one.
  Recipes only list what a plugin's docs ask *you* to add.
- **Binary plists** (reported as ✗ with how to convert), localized
  `InfoPlist.strings`, macOS/web/desktop, Firebase config files.
- **Whether a purpose string is good enough for App Review** — plumb only flags
  empty and placeholder text.

## JSON output

`plumb doctor --json` prints a stable document (format `1`; changes are
additive) with no absolute paths or timestamps:

```json
{
  "format": 1,
  "plumb_version": "0.0.1",
  "project": { "name": "my_app", "dependency_source": "pubspec.lock" },
  "packages": [
    { "name": "camera", "version": "0.12.2", "status": "checked", "recipe": "recipes/camera.yaml" }
  ],
  "findings": [
    {
      "id": "camera/ios/info_plist/NSMicrophoneUsageDescription",
      "severity": "missing",
      "package": "camera",
      "platform": "ios",
      "file": "ios/Runner/Info.plist",
      "key": "NSMicrophoneUsageDescription",
      "message": "NSMicrophoneUsageDescription is missing",
      "fix": "Add NSMicrophoneUsageDescription to Info.plist with a usage description.",
      "source": "https://pub.dev/packages/camera#ios",
      "also_needed_by": []
    }
  ],
  "summary": { "error": 0, "missing": 1, "warning": 0, "ok": 0, "info": 0 }
}
```

Finding `id`s are stable, so CI scripts can match on them. Setup errors are
JSON too: `{"format": 1, "plumb_version": "0.0.1", "error": "…"}`.

## Recipes

A recipe is a small YAML file describing what one plugin needs
([`recipes/`](https://github.com/UmeshRaj7/plumb/tree/main/recipes),
[JSON Schema](https://github.com/UmeshRaj7/plumb/blob/main/schema/recipe.schema.json)):

```yaml
schema: 1
package: image_picker
versions: ">=0.8.0 <2.0.0"
source: https://pub.dev/packages/image_picker#ios
ios:
  info_plist:
    NSPhotoLibraryUsageDescription: { required: true, hint: "Describe why your app needs the photo library." }
    NSMicrophoneUsageDescription: { required: when_used, hint: "Needed if you record videos." }
```

Missing a plugin? See [CONTRIBUTING.md](https://github.com/UmeshRaj7/plumb/blob/main/CONTRIBUTING.md#writing-a-recipe):
recipes must come from the plugin's own docs and cite them.

## Status

v0.0.1 only **checks**. It does not create or edit native files; that may come
in a later version, and this README will say so when it does.

---

Flutter and the related logo are trademarks of Google LLC. plumb is not
affiliated with or endorsed by Google.

Licensed under the [MIT License](LICENSE).
