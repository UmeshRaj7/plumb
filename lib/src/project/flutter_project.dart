import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../errors.dart';

/// A Flutter app plumb can check.
class FlutterProject {
  /// Creates a project description.
  const FlutterProject({
    required this.root,
    required this.name,
    required this.resolutionRoot,
    this.ignore = const {},
  });

  /// Absolute path of the directory containing the app's pubspec.yaml.
  final String root;

  /// The app's package name.
  final String name;

  /// Where pubspec.lock / .dart_tool live: [root], or the pub workspace root
  /// when the app has `resolution: workspace`.
  final String resolutionRoot;

  /// Finding ids to ignore, with the reason (`plumb: ignore:` in pubspec.yaml).
  final Map<String, String> ignore;
}

/// What a pubspec.yaml says about its package.
class PubspecInfo {
  /// Creates pubspec info.
  const PubspecInfo({
    required this.name,
    required this.dependsOnFlutter,
    required this.isPlugin,
    required this.isWorkspaceMember,
    required this.isWorkspaceRoot,
    this.ignore = const {},
  });

  /// `name:`
  final String name;

  /// `dependencies: flutter: sdk: flutter`
  final bool dependsOnFlutter;

  /// `flutter: plugin:` is present.
  final bool isPlugin;

  /// `resolution: workspace`
  final bool isWorkspaceMember;

  /// `workspace:` is present.
  final bool isWorkspaceRoot;

  /// `plumb: ignore:`: finding id → why it is safe to ignore.
  final Map<String, String> ignore;
}

/// Reads the facts plumb needs from pubspec.yaml contents.
/// Throws [FormatException] if it isn't a YAML map with a `name`, or if its
/// `plumb:` section is invalid.
PubspecInfo parsePubspec(String yaml) {
  final Object? document;
  try {
    document = loadYaml(yaml);
  } on YamlException catch (e) {
    throw FormatException('Invalid YAML: ${e.message}');
  }
  if (document is! Map || document['name'] is! String) {
    throw const FormatException('Expected a map with a "name" field.');
  }
  final dependencies = document['dependencies'];
  final flutterDependency = dependencies is Map
      ? dependencies['flutter']
      : null;
  final flutterSection = document['flutter'];
  return PubspecInfo(
    name: document['name'] as String,
    dependsOnFlutter:
        flutterDependency is Map && flutterDependency['sdk'] == 'flutter',
    isPlugin: flutterSection is Map && flutterSection['plugin'] != null,
    isWorkspaceMember: document['resolution'] == 'workspace',
    isWorkspaceRoot: document.containsKey('workspace'),
    ignore: _parsePlumbSection(document['plumb']),
  );
}

/// The `plumb:` section of pubspec.yaml. Strict, like recipes: a typo
/// should fail loudly instead of silently ignoring nothing.
///
/// ```yaml
/// plumb:
///   ignore:
///     <finding id>: <why it is safe to ignore>
/// ```
Map<String, String> _parsePlumbSection(Object? section) {
  if (section == null) return const {};
  if (section is! Map) {
    throw const FormatException(
      '`plumb:` must be a map, e.g. `plumb: {ignore: {<finding id>: <reason>}}`.',
    );
  }
  for (final key in section.keys) {
    if (key != 'ignore') {
      throw FormatException('Unknown key `plumb.$key` (supported: ignore).');
    }
  }
  final ignore = section['ignore'];
  if (ignore == null) return const {};
  if (ignore is! Map) {
    throw const FormatException(
      '`plumb.ignore` must map finding ids to reasons, e.g. '
      '`local_auth/ios/info_plist/NSFaceIDUsageDescription: Set in Info-Release.plist`.',
    );
  }
  final reasons = <String, String>{};
  for (final MapEntry(:key, :value) in ignore.entries) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException(
        '`plumb.ignore` entry "$key" needs a reason: say why it is safe to '
        'ignore, so the next person knows.',
      );
    }
    reasons['$key'] = value.trim();
  }
  return reasons;
}

/// Finds the Flutter app containing [start] by walking up to the nearest
/// pubspec.yaml.
///
/// Throws [PlumbException] with a next step when [start] isn't inside a
/// Flutter app (plain Dart package, plugin package, no pubspec at all).
FlutterProject findFlutterProject(String start) {
  final startDir = p.normalize(p.absolute(start));
  if (!Directory(startDir).existsSync()) {
    throw PlumbException('Directory not found: $startDir');
  }
  final root = _findUp(startDir, (dir) => _pubspec(dir).existsSync());
  if (root == null) {
    throw PlumbException(
      'No pubspec.yaml found in $startDir or any parent directory. '
      'Run plumb inside a Flutter app.',
    );
  }

  final info = _readPubspec(root);
  if (info.isPlugin) {
    throw PlumbException(
      '${info.name} is a Flutter plugin package. plumb checks apps; '
      'run it in the plugin\'s example/ app instead.',
    );
  }
  if (!info.dependsOnFlutter) {
    throw PlumbException(
      '${info.name} is not a Flutter app (no `flutter: sdk: flutter` '
      'dependency in $root/pubspec.yaml).',
    );
  }

  var resolutionRoot = root;
  if (info.isWorkspaceMember) {
    final workspace = _findUp(
      p.dirname(root),
      (dir) => _pubspec(dir).existsSync() && _readPubspec(dir).isWorkspaceRoot,
    );
    if (workspace == null) {
      throw PlumbException(
        '${info.name} uses `resolution: workspace` but no workspace root '
        'pubspec.yaml was found above $root.',
      );
    }
    resolutionRoot = workspace;
  }
  return FlutterProject(
    root: root,
    name: info.name,
    resolutionRoot: resolutionRoot,
    ignore: info.ignore,
  );
}

File _pubspec(String dir) => File(p.join(dir, 'pubspec.yaml'));

PubspecInfo _readPubspec(String dir) {
  final file = _pubspec(dir);
  try {
    return parsePubspec(file.readAsStringSync());
  } on FormatException catch (e) {
    throw PlumbException('Could not read ${file.path}: ${e.message}');
  }
}

/// Returns the first of [dir] and its ancestors satisfying [test].
String? _findUp(String dir, bool Function(String dir) test) {
  var current = dir;
  while (true) {
    if (test(current)) return current;
    final parent = p.dirname(current);
    if (parent == current) return null;
    current = parent;
  }
}
