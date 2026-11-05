# plumb launch study: 25 popular open-source Flutter apps

Before announcing [plumb](https://pub.dev/packages/plumb), I ran `plumb doctor` on the 25
most-starred open-source Flutter apps on GitHub and checked every ✗ and ⚠ by hand. The first
version was wrong more often than right; this is how I found out and what changed. This folder
has the method, the raw output and the scripts, so every number can be checked or reproduced.

Date: 2026-11-02, corrected 2026-11-05. Every number below comes from [STATS.md](STATS.md),
which [stats.py](stats.py) generates from [results/](results/) and [verdicts.tsv](verdicts.tsv).

> **Correction (2026-11-05).** The first version of this study said plumb 0.1.0 had 4 findings,
> all correct, and that 3 apps had a real problem. One of those was wrong. ServerBox's Xcode
> project builds with `Runner/Info-$(CONFIGURATION).plist`, which does set
> `NSFaceIDUsageDescription`; the `Info.plist` plumb read is an unused leftover. Its maintainer
> pointed this out in [ServerBox #1851](https://github.com/lollipopkit/flutter_server_box/issues/1851)
> a day after the report (and removed the leftover file). My hand check missed it too. plumb
> 0.1.1 reads `INFOPLIST_FILE` from the Xcode project and no longer checks an `Info.plist` the
> build doesn't use. The numbers below are corrected and include 0.1.1.

## Headline numbers

| | plumb 0.0.1 | plumb 0.1.0 | plumb 0.1.1 |
|---|---|---|---|
| Apps scanned | 25 | 25 | 25 |
| ✗/⚠ findings | 8, in 5 apps | 4, in 3 apps | **3, in 2 apps** |
| Confirmed real (checked by hand) | 2 | 2 | **2** |
| Required by the plugin docs, low practical impact | 1 | 1 | 1 |
| False positives | 5 | 1 | **0** |
| Precision (real or docs-backed ÷ all ✗/⚠) | 3/8 = 38% | 3/4 = 75% | **3/3 = 100%** |
| Real issues hidden by the change | n/a | 0 (all 4 downgraded items checked) | 0 (the 1 changed item checked) |
| ✓ checks passed | 92 | 92 | 90 |

- 2 of 25 apps had a real native-config problem their plugins' docs warn about: an empty
  purpose string and a missing push background mode.
- 23 of 25 apps were clean (19 of the 21 with an iOS app, and all 4 Android-only apps).
- 0.1.1 passes 2 fewer ✓ checks because it no longer reads ServerBox's unused `Info.plist`;
  those keys are now listed as "not checked".
- The apps have 4.9k to 97k GitHub stars each (median 15.5k, 573k combined). 21 have an iOS
  app, 4 are Android-only, 5 live in a monorepo subfolder.

## Method

1. **Selection, fixed before running:** GitHub search `language:dart`, pushed since
   2026-05-01, not archived, ranked by stars. Kept end-user apps with `android/` or `ios/` and
   a committed `pubspec.lock`. Excluded libraries, samples, templates, curated lists and
   adult-content apps. Took the top 25 ([apps.tsv](apps.tsv)).
2. **Pilot and held-out set:** the top 10 were a pilot. They exposed plumb's false positives,
   and two recipe fixes followed (0.1.0). The other 15 apps were fetched and scanned only after
   the fixes, as a held-out check. The 0.1.1 fix came from a maintainer's reply, after the study
   was published.
3. **Only the files plumb reads,** at each default branch's commit on 2026-11-02
   ([apps_pinned.tsv](apps_pinned.tsv)): pubspec and lockfile (workspace root when needed),
   `ios/Runner/Info*.plist`, `*.entitlements`, `project.pbxproj`, every
   `android/app/src/*/AndroidManifest.xml` and the launcher activity source. No clones;
   about 3 MB in total ([fetch.py](fetch.py)).
4. **Every version** (0.0.1, 0.1.0, 0.1.1) ran on every app ([run.sh](run.sh)).
5. **Every ✗/⚠ from either version was checked by hand** against the file itself, the plugin's
   own docs, how the app's Dart code uses the plugin (code search, then the file at the pinned
   commit, including transitive packages and submodules), and the plugin's native source
   where behavior mattered. Verdicts and evidence: [verdicts.tsv](verdicts.tsv).
6. **Recall check:** every item a new version downgraded from ✗ to ℹ was checked, to make sure
   no real issue was hidden.

## Results by app (plumb 0.1.1)

| # | App | ⭐ | Platforms | Plugins plumb checked | ✗/⚠ | Verdict |
|---|---|---|---|---|---|---|
| 1 | [localsend](https://github.com/localsend/localsend) | 97.0k | iOS, Android | image_picker, permission_handler, url_launcher | 0 | clean (0.0.1: 1 false positive) |
| 2 | [AppFlowy](https://github.com/AppFlowy-IO/AppFlowy) | 78.1k | iOS, Android | image_picker, permission_handler, url_launcher | 0 | clean |
| 3 | [FlClash](https://github.com/chen08209/FlClash) | 60.5k | Android | image_picker, url_launcher | 0 | clean |
| 4 | [Kazumi](https://github.com/Predidit/Kazumi) | 40.7k | iOS (sideload), Android | image_picker, url_launcher | 2 | 1 real ⚠, 1 docs-backed ✗ |
| 5 | [hiddify](https://github.com/hiddify/hiddify-app) | 33.6k | iOS, Android | url_launcher | 0 | clean |
| 6 | [ente Photos](https://github.com/ente/ente) | 29.8k | iOS, Android | camera, firebase_messaging, flutter_local_notifications, local_auth, permission_handler, url_launcher | 0 | clean (0.0.1: 1 false positive) |
| 7 | [gopeed](https://github.com/GopeedLab/gopeed) | 27.3k | iOS, Android | flutter_local_notifications, permission_handler, url_launcher | 0 | clean |
| 8 | [Obtainium](https://github.com/ImranR98/Obtainium) | 21.1k | Android | flutter_local_notifications, permission_handler, url_launcher | 0 | clean |
| 9 | [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) | 20.2k | iOS, Android | image_picker, url_launcher | 0 | clean |
| 10 | [lantern](https://github.com/getlantern/lantern) | 16.6k | iOS, Android | flutter_local_notifications, image_picker, url_launcher | 0 | clean |
| 11 | [Bagisto mobile](https://github.com/bagisto/opensource-ecommerce-mobile-app) | 16.1k | iOS, Android | camera, firebase_messaging, image_picker, permission_handler, url_launcher | 1 | 1 real ✗ |
| 12 | [karing](https://github.com/KaringX/karing) | 15.9k | iOS, Android | flutter_local_notifications, image_picker, permission_handler, url_launcher | 0 | clean |
| 13 | [gsy_github_app_flutter](https://github.com/CarGuo/gsy_github_app_flutter) | 15.5k | iOS, Android | permission_handler, url_launcher | 0 | clean |
| 14 | [proxypin](https://github.com/wanghongenpin/proxypin) | 14.3k | iOS, Android | permission_handler, url_launcher | 0 | clean |
| 15 | [pixez](https://github.com/Notsfsssf/pixez-flutter) | 13.3k | iOS, Android | image_picker, permission_handler, url_launcher | 0 | clean |
| 16 | [clashmi](https://github.com/KaringX/clashmi) | 10.2k | iOS, Android | image_picker, permission_handler, url_launcher | 0 | clean |
| 17 | [anx-reader](https://github.com/Anxcye/anx-reader) | 9.2k | iOS, Android | permission_handler, url_launcher | 0 | clean |
| 18 | [ServerBox](https://github.com/lollipopkit/flutter_server_box) | 8.9k | iOS, Android | camera, flutter_local_notifications, image_picker, local_auth, url_launcher | 0 | clean (0.0.1: 2 false positives, 0.1.0: 1) |
| 19 | [FlutterUnit](https://github.com/toly1994328/FlutterUnit) | 8.9k | iOS, Android | permission_handler, sign_in_with_apple, url_launcher | 0 | clean |
| 20 | [Mornye](https://github.com/mornyeapp/Mornye) | 7.6k | iOS, Android | flutter_local_notifications, permission_handler, url_launcher | 0 | clean |
| 21 | [AniCh](https://github.com/Sle2p/AniCh) | 7.6k | iOS, Android | permission_handler, url_launcher | 0 | clean |
| 22 | [dsh-Go](https://github.com/ccch1mneyyy/dsh-Go) | 5.6k | Android | image_picker, url_launcher | 0 | clean |
| 23 | [aves](https://github.com/deckerst/aves) | 5.5k | Android | google_maps_flutter, local_auth, permission_handler, url_launcher | 0 | clean |
| 24 | [saber](https://github.com/saber-notes/saber) | 5.0k | iOS, Android | permission_handler, url_launcher | 0 | clean |
| 25 | [oblivion](https://github.com/bepass-org/oblivion) | 4.9k | iOS, Android | url_launcher | 0 | clean |

Stars as of 2026-11-02. Raw output per app and version: `results/<version>/<owner>_<repo>.json`
(machine-readable) and `.txt` (what you'd see in a terminal, with `--verbose`).

## The real findings

Each was reported to the app's maintainers in a friendly GitHub issue on 2026-11-02. These
are small, common slips. Most of the 25 apps got everything right.

- **Kazumi:** `NSPhotoLibraryAddUsageDescription` is an empty string
  ([Info.plist L51-52](https://github.com/Predidit/Kazumi/blob/69ba855ef4554b79a18d8becc83165c0fd000443/ios/Runner/Info.plist#L51-L52)),
  while the app saves images to Photos
  ([info_actions_menu.dart L88](https://github.com/Predidit/Kazumi/blob/69ba855ef4554b79a18d8becc83165c0fd000443/lib/pages/info/info_actions_menu.dart#L88)).
  Users see a permission prompt with no explanation.
  Reported: [Kazumi #2807](https://github.com/Predidit/Kazumi/issues/2807).
- **Bagisto mobile:** no `UIBackgroundModes` → `remote-notification`, although push is enabled
  and the app registers
  [`FirebaseMessaging.onBackgroundMessage`](https://github.com/bagisto/opensource-ecommerce-mobile-app/blob/18a2c27c6d25a2e98a1bc84b69328e72d6a5bded/lib/main.dart#L48).
  Apple: "To receive background notifications, you must add the remote notifications background
  mode to your app."
  Reported: [Bagisto #79](https://github.com/bagisto/opensource-ecommerce-mobile-app/issues/79).
- **Docs-backed, low impact (Kazumi):** image_picker's README asks for
  `NSPhotoLibraryUsageDescription` ("App Store policy requires including the plist entry").
  Kazumi isn't on the App Store and picks with PHPicker on iOS 14+, so this matters little.

No app was built or run on a device. Impacts are stated from the docs, not observed.

## The false positives, and the fixes

| App | 0.0.1 said | Reality | Evidence |
|---|---|---|---|
| localsend | image_picker camera key ✗ | image_picker is only imported for `XFile`; the app never picks | [cross_file_converters.dart L5](https://github.com/localsend/localsend/blob/92e133aa43869e94d394fd04fa70c50a0f796a64/app/lib/util/native/cross_file_converters.dart#L5) |
| Kazumi | image_picker camera key ✗ | gallery only | [image_search_page.dart L136](https://github.com/Predidit/Kazumi/blob/69ba855ef4554b79a18d8becc83165c0fd000443/lib/pages/search/image_search_page.dart#L136) |
| ente Photos | camera mic key ✗ | `enableAudio: false` | [ritual_camera_page.dart L289-292](https://github.com/ente/ente/blob/31a12bfbb70137fccad399a5aecac7469e43a384/mobile/apps/photos/lib/ui/rituals/ritual_camera_page.dart#L289-L292) |
| ServerBox | camera mic key ✗ | camera comes from the QR scanner `qr_code_dart_scan` 0.14.0, which sets `enableAudio: false` | `qr_code_dart_scan_controller.dart` L233-236 in the pub.dev archive |
| ServerBox (also in 0.1.0) | local_auth Face ID key ✗ | the build uses `Runner/Info-$(CONFIGURATION).plist`, which sets it; `Info.plist` is unused | [project.pbxproj L828](https://github.com/lollipopkit/flutter_server_box/blob/3ddb7b5612a1c34ef95e99de5f772d7eca6c320a/ios/Runner.xcodeproj/project.pbxproj#L828), [Info-Release.plist](https://github.com/lollipopkit/flutter_server_box/blob/3ddb7b5612a1c34ef95e99de5f772d7eca6c320a/ios/Runner/Info-Release.plist), [#1851](https://github.com/lollipopkit/flutter_server_box/issues/1851) |

**Why (first four):** the plugin READMEs list these keys without a condition, but the plugins
only ask for them for an optional feature. image_picker_ios requests camera access only for
`ImageSource.camera`; camera_avfoundation requests the microphone only when `enableAudio` is
true.

**Fix in 0.1.0:** both keys became `when_used` (reported as ℹ, with a hint naming the feature).
The fix was designed on the 10-app pilot. On the 15 held-out apps it removed the one new false
positive of that kind (ServerBox's mic key) and kept the one new real finding (Bagisto).

**Why (the fifth):** a different mistake. plumb read `ios/Runner/Info.plist`, but ServerBox's
Xcode project builds with per-configuration plists (`INFOPLIST_FILE`). plumb listed those
files as "not checked" but still trusted the leftover `Info.plist`. I missed it in the hand
check too; the app's maintainer caught it.

**Fix in 0.1.1:** plumb reads `INFOPLIST_FILE` from `project.pbxproj`. If the app builds only
with other plists in `ios/Runner/`, plumb says so (ℹ) and lists each `Info.plist` requirement as
"not checked" instead of ✗. It doesn't read those other plists yet.

**Recall:** 0.1.0 downgraded exactly 4 items, and all 4 are verified false positives. 0.1.1
changed exactly 1 item across the 25 apps (ServerBox's Face ID key), also a verified false
positive. Known trade-off: an app that records video with camera's default
`enableAudio: true` and no microphone string now gets ℹ instead of ✗. None of the 25 apps did
that.

## Other observations

- Plugins with plumb recipes, by number of apps: url_launcher 25/25, permission_handler 17,
  image_picker 12, flutter_local_notifications 8 (1 on a version plumb doesn't cover yet),
  camera 3, local_auth 3, firebase_messaging 2, google_maps_flutter 1, sign_in_with_apple 1.
- 5 of 25 apps live in a monorepo subfolder; 2 use pub workspaces (localsend, ente).
- 5 apps have flavor-specific manifests or plists, which plumb lists as "not checked" (ente,
  pixez, ServerBox, FlutterUnit, Mornye).
- Plugins often arrive indirectly: in ServerBox, camera and local_auth come through a
  submodule, so neither appears in `pubspec.yaml`.
- 1 app (ServerBox) builds with per-configuration plists instead of `Info.plist`.

## Limitations

- 25 popular open-source apps: likely better maintained than the average app, and not a
  random sample.
- plumb checks only what its recipes cover (10 plugins) and only the main `Info.plist` and
  `AndroidManifest.xml`. No flavor files, Gradle, Podfile or AppDelegate.
- A hand check can be wrong too: one of mine was, until a maintainer corrected it.
- ℹ items were not checked by hand; they never fail a run.

## Reproduce

```sh
python3 -I study/2026-11-launch/fetch.py /tmp/plumb-study     # only the files plumb reads
dart pub global activate plumb 0.1.1
sh study/2026-11-launch/run.sh /tmp/plumb-study "$(command -v plumb)"
python3 -I study/2026-11-launch/stats.py                      # recompute the numbers
```

`fetch.py` downloads each app at the commit pinned in `apps_pinned.tsv`, so you check exactly
what I checked. The unauthenticated GitHub API allows 60 calls an hour; if it runs out, the
script stops cleanly and a rerun resumes. Re-fetching localsend this way reproduces its
committed results byte for byte.
