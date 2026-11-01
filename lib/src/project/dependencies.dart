import 'dart:io';

import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import '../errors.dart';
import 'flutter_project.dart';

/// How a package is depended on (from pubspec.lock's `dependency:` field).
enum DependencyKind {
  /// `direct main` or `direct overridden`.
  direct,

  /// `transitive`.
  transitive,

  /// `direct dev` (excluded from checks: dev tools don't ship in the app).
  dev,

  /// Not known (package_config.json doesn't record it).
  unknown,
}

/// Which file the dependency list came from.
enum DependencySource {
  /// `pubspec.lock` (preferred: has versions and dependency kinds).
  pubspecLock('pubspec.lock'),

  /// `.dart_tool/package_config.json` (fallback).
  packageConfig('.dart_tool/package_config.json');

  const DependencySource(this.label);

  /// File name shown to users.
  final String label;
}

/// A package the app depends on.
class ResolvedPackage {
  /// Creates a resolved package.
  const ResolvedPackage(this.name, this.version, this.kind);

  /// Pub package name.
  final String name;

  /// Resolved version, when known.
  final Version? version;

  /// How it is depended on.
  final DependencyKind kind;
}

/// The packages an app uses, and where that list came from.
typedef Dependencies = ({
  DependencySource source,
  List<ResolvedPackage> packages,
});

/// Reads the app's dependencies from pubspec.lock, falling back to
/// `.dart_tool/package_config.json`. Dev dependencies are excluded.
///
/// Throws [PlumbException] when neither file exists or the one found is
/// unreadable.
Dependencies resolveDependencies(FlutterProject project) {
  final lock = File(p.join(project.resolutionRoot, 'pubspec.lock'));
  if (lock.existsSync()) {
    return (
      source: DependencySource.pubspecLock,
      packages: _withoutDev(_parseOrFail(lock, parsePubspecLock)),
    );
  }
  final config = File(
    p.join(project.resolutionRoot, '.dart_tool', 'package_config.json'),
  );
  if (config.existsSync()) {
    final packages = _parseOrFail(
      config,
      (text) => parsePackageConfig(text, configUri: config.absolute.uri),
    );
    return (
      source: DependencySource.packageConfig,
      packages: [
        for (final package in packages)
          if (package.name != project.name) package,
      ],
    );
  }
  throw PlumbException(
    'No pubspec.lock or .dart_tool/package_config.json in '
    '${project.resolutionRoot}. Run `flutter pub get` first.',
  );
}

/// Parses pubspec.lock. Throws [FormatException] if it isn't one.
List<ResolvedPackage> parsePubspecLock(String yaml) {
  final Object? document;
  try {
    document = loadYaml(yaml);
  } on YamlException catch (e) {
    throw FormatException('Invalid YAML: ${e.message}');
  }
  final packages = document is Map ? document['packages'] : null;
  if (packages is! Map) {
    throw const FormatException('Missing "packages" map.');
  }
  return [
    for (final MapEntry(:key, :value) in packages.entries)
      if (value is Map)
        ResolvedPackage(
          '$key',
          _tryParseVersion(value['version']),
          switch (value['dependency']) {
            'direct main' || 'direct overridden' => DependencyKind.direct,
            'direct dev' => DependencyKind.dev,
            'transitive' => DependencyKind.transitive,
            _ => DependencyKind.unknown,
          },
        ),
  ];
}

/// Parses `.dart_tool/package_config.json` located at [configUri].
///
/// Versions are taken from hosted pub-cache paths (`…/<name>-<version>/`);
/// other sources (path, git, the app itself) get a null version.
List<ResolvedPackage> parsePackageConfig(
  String json, {
  required Uri configUri,
}) {
  final config = PackageConfig.parseString(json, configUri);
  return [
    for (final package in config.packages)
      ResolvedPackage(
        package.name,
        _versionFromRoot(package.name, package.root),
        DependencyKind.unknown,
      ),
  ];
}

Version? _versionFromRoot(String name, Uri root) {
  final segments = root.pathSegments.where((s) => s.isNotEmpty);
  if (segments.isEmpty) return null;
  final last = segments.last;
  if (!last.startsWith('$name-')) return null;
  return _tryParseVersion(last.substring(name.length + 1));
}

Version? _tryParseVersion(Object? value) {
  if (value is! String) return null;
  try {
    return Version.parse(value);
  } on FormatException {
    return null;
  }
}

List<ResolvedPackage> _withoutDev(List<ResolvedPackage> packages) => [
  for (final package in packages)
    if (package.kind != DependencyKind.dev) package,
];

List<ResolvedPackage> _parseOrFail(
  File file,
  List<ResolvedPackage> Function(String) parse,
) {
  try {
    return parse(file.readAsStringSync());
  } on FormatException catch (e) {
    throw PlumbException('Could not read ${file.path}: ${e.message}');
  }
}
