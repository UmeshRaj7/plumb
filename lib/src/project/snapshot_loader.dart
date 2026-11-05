import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../parsers/android_manifest.dart';
import '../parsers/pbxproj.dart';
import '../parsers/plist.dart';
import 'dependencies.dart';
import 'flutter_project.dart';
import 'snapshot.dart';

/// Flutter's template adds these build-type manifests (INTERNET permission
/// for development only). They aren't flavors, so they aren't reported.
const _standardBuildTypes = {'main', 'debug', 'profile'};

/// Reads everything plumb checks from [project]. This is the only place
/// (besides the CLI and project detection) that touches the file system, and
/// it only ever reads.
///
/// A missing or unparseable native file is recorded in the snapshot, not
/// thrown, so the report can show it next to the other findings.
ProjectSnapshot loadSnapshot(FlutterProject project) {
  final dependencies = resolveDependencies(project);
  final loader = _Loader(project.root);
  return ProjectSnapshot(
    name: project.name,
    root: project.root,
    dependencySource: dependencies.source,
    packages: dependencies.packages,
    ios: loader.exists('ios') ? loader.ios() : null,
    android: loader.exists('android') ? loader.android() : null,
  );
}

class _Loader {
  _Loader(this.root);

  final String root;

  bool exists(String relative) => Directory(_abs(relative)).existsSync();

  IosFiles ios() {
    final runner = Directory(_abs('ios/Runner'));
    final plists = _list(runner, (name) => name.endsWith('.plist'));
    final pbxproj = _readText('ios/Runner.xcodeproj/project.pbxproj');
    return IosFiles(
      infoPlist: _readInfoPlist(pbxproj),
      entitlements: [
        for (final name in _list(runner, (n) => n.endsWith('.entitlements')))
          _readPlist('ios/Runner/$name'),
      ],
      pbxproj: pbxproj,
      otherInfoPlists: [
        for (final name in plists)
          if (name.startsWith('Info') && name != 'Info.plist')
            'ios/Runner/$name',
      ],
    );
  }

  AndroidFiles android() {
    const manifestPath = 'android/app/src/main/AndroidManifest.xml';
    final manifest = _read(manifestPath, parseAndroidManifest);
    final launcher = manifest.value?.launcherActivity;
    return AndroidFiles(
      manifest: manifest,
      mainActivitySource: launcher == null ? null : _activitySource(launcher),
      otherManifests: [
        for (final dir in _list(
          Directory(_abs('android/app/src')),
          (_) => true,
        ))
          if (!_standardBuildTypes.contains(dir) &&
              File(
                _abs('android/app/src/$dir/AndroidManifest.xml'),
              ).existsSync())
            'android/app/src/$dir/AndroidManifest.xml',
      ],
    );
  }

  /// Finds `<SimpleName>.kt` / `.java` for the launcher activity under the
  /// main source sets. Returns null for Flutter's own activity classes,
  /// which have no source in the app.
  FileRead<String>? _activitySource(String activityName) {
    if (activityName.startsWith('io.flutter.')) return null;
    final simpleName = activityName.split('.').last;
    final candidates = <String>[
      for (final sourceSet in ['kotlin', 'java'])
        ..._findFiles('android/app/src/main/$sourceSet', {
          '$simpleName.kt',
          '$simpleName.java',
        }),
    ];
    final pattern =
        'android/app/src/main/{kotlin,java}/**/$simpleName.{kt,java}';
    if (candidates.isEmpty) {
      return FileRead.failed(pattern, FileProblem.missing);
    }
    if (candidates.length > 1) {
      return FileRead.failed(
        pattern,
        FileProblem.ambiguous,
        candidates.join(', '),
      );
    }
    return FileRead.ok(candidates.single, _readText(candidates.single)!);
  }

  /// `ios/Runner/Info.plist`, unless the Xcode project builds the app with
  /// other plists in Runner/ only (e.g. `Runner/Info-$(CONFIGURATION).plist`).
  /// Then Info.plist isn't what ships, and checking it would report keys as
  /// missing that the app does have.
  FileRead<Map<String, Object?>> _readInfoPlist(String? pbxproj) {
    const path = 'ios/Runner/Info.plist';
    final settings = pbxproj == null
        ? const <String>[]
        : runnerInfoPlistSettings(pbxproj);
    if (settings.isNotEmpty && !settings.contains('Runner/Info.plist')) {
      return FileRead.failed(path, FileProblem.notUsed, settings.join(', '));
    }
    return _readPlist(path);
  }

  FileRead<Map<String, Object?>> _readPlist(String relative) {
    final file = File(_abs(relative));
    if (!file.existsSync()) {
      return FileRead.failed(relative, FileProblem.missing);
    }
    final bytes = file.readAsBytesSync();
    if (looksLikeBinaryPlist(bytes)) {
      return FileRead.failed(relative, FileProblem.binaryPlist);
    }
    return _parse(
      relative,
      utf8.decode(bytes, allowMalformed: true),
      parsePlist,
    );
  }

  FileRead<T> _read<T>(String relative, T Function(String) parse) {
    final text = _readText(relative);
    if (text == null) return FileRead.failed(relative, FileProblem.missing);
    return _parse(relative, text, parse);
  }

  FileRead<T> _parse<T>(
    String relative,
    String text,
    T Function(String) parse,
  ) {
    try {
      return FileRead.ok(relative, parse(text));
    } on FormatException catch (e) {
      return FileRead.failed(relative, FileProblem.malformed, e.message);
    }
  }

  String? _readText(String relative) {
    final file = File(_abs(relative));
    if (!file.existsSync()) return null;
    return utf8.decode(file.readAsBytesSync(), allowMalformed: true);
  }

  /// Relative paths (with `/`) of files named one of [names] under [relativeDir].
  List<String> _findFiles(String relativeDir, Set<String> names) {
    final dir = Directory(_abs(relativeDir));
    if (!dir.existsSync()) return const [];
    return [
      for (final entity in dir.listSync(recursive: true))
        if (entity is File && names.contains(p.basename(entity.path)))
          _relative(entity.path),
    ]..sort();
  }

  /// Sorted names of the direct children of [dir] matching [test].
  List<String> _list(Directory dir, bool Function(String name) test) {
    if (!dir.existsSync()) return const [];
    return [
      for (final entity in dir.listSync())
        if (test(p.basename(entity.path))) p.basename(entity.path),
    ]..sort();
  }

  String _abs(String relative) => p.joinAll([root, ...relative.split('/')]);

  String _relative(String absolute) =>
      p.split(p.relative(absolute, from: root)).join('/');
}
