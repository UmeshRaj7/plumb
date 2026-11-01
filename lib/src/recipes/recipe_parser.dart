import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import '../errors.dart';
import '../parsers/android_manifest.dart';
import '../parsers/plist.dart';
import 'recipe.dart';

/// A recipe file that doesn't follow schema 1. Lists every problem found.
class RecipeFormatException extends PlumbException {
  /// Creates the exception for the recipe at [origin].
  RecipeFormatException(this.origin, this.problems)
    : super(
        'Invalid recipe $origin:\n${problems.map((p) => '  - $p').join('\n')}',
      );

  /// The recipe file name.
  final String origin;

  /// One message per problem, each prefixed with its YAML path.
  final List<String> problems;
}

/// Parses and strictly validates a schema 1 recipe (ARCHITECTURE.md §7).
///
/// Throws [RecipeFormatException] listing every problem; never returns a
/// partially valid recipe.
Recipe parseRecipe(String yaml, {required String origin}) =>
    _RecipeParser(origin).parse(yaml);

const _specFields = {'required', 'hint', 'source'};
const _iosSections = {
  'info_plist': RequirementKind.infoPlistKey,
  'entitlements': RequirementKind.entitlement,
  'background_modes': RequirementKind.backgroundMode,
  'manual': RequirementKind.manual,
};
const _androidSections = {
  'permissions': RequirementKind.permission,
  'queries': RequirementKind.query,
  'manifest_meta_data': RequirementKind.metaData,
  'components': RequirementKind.component,
  'activity_class': RequirementKind.activityClass,
  'manual': RequirementKind.manual,
};
final _packageName = RegExp(r'^[a-z][a-z0-9_]*$');
final _kebabCase = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

/// Collects problems while walking the YAML, so authors see all of them in
/// one run. Each `_read*` method returns null for an invalid value after
/// recording why.
class _RecipeParser {
  _RecipeParser(this.origin);

  final String origin;
  final problems = <String>[];
  final requirements = <Requirement>[];

  Recipe parse(String yaml) {
    final Object? document;
    try {
      document = loadYaml(yaml);
    } on YamlException catch (e) {
      throw RecipeFormatException(origin, ['Invalid YAML: ${e.message}']);
    }
    if (document is! Map) {
      throw RecipeFormatException(origin, ['The recipe must be a map.']);
    }

    _checkKeys(document, const {
      'schema',
      'package',
      'versions',
      'source',
      'ios',
      'android',
    }, 'recipe');
    if (document['schema'] != 1) {
      problems.add('schema: must be 1 (got ${document['schema']}).');
    }
    final package = document['package'];
    if (package is! String || !_packageName.hasMatch(package)) {
      problems.add('package: must be a pub package name (got $package).');
    }
    final versions = _readConstraint(document['versions']);
    final source = _readUrl(document['source'], 'source', required: true);
    _readPlatform(document['ios'], NativePlatform.ios, _iosSections);
    _readPlatform(
      document['android'],
      NativePlatform.android,
      _androidSections,
    );

    if (problems.isNotEmpty) throw RecipeFormatException(origin, problems);
    return Recipe(
      package: package as String,
      versions: versions!,
      source: source!,
      origin: origin,
      requirements: List.unmodifiable(requirements),
    );
  }

  VersionConstraint? _readConstraint(Object? value) {
    if (value is String) {
      try {
        return VersionConstraint.parse(value);
      } on FormatException {
        // Reported below.
      }
    }
    problems.add('versions: must be a pub version constraint (got $value).');
    return null;
  }

  String? _readUrl(Object? value, String path, {bool required = false}) {
    if (value == null && !required) return null;
    final uri = value is String ? Uri.tryParse(value) : null;
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      problems.add('$path: must be an https URL (got $value).');
      return null;
    }
    return value as String;
  }

  void _readPlatform(
    Object? value,
    NativePlatform platform,
    Map<String, RequirementKind> sections,
  ) {
    if (value == null) return;
    final path = platform.name;
    if (value is! Map) {
      problems.add('$path: must be a map.');
      return;
    }
    _checkKeys(value, sections.keys.toSet(), path);
    for (final MapEntry(:key, value: section) in value.entries) {
      final kind = sections[key];
      if (kind == null || section == null) continue;
      final sectionPath = '$path.$key';
      switch (kind) {
        case RequirementKind.query:
          _readQueries(section, sectionPath);
        case RequirementKind.manual:
          _readManual(section, platform, sectionPath);
        default:
          _readKeyedSection(section, platform, kind, sectionPath);
      }
    }
  }

  /// Sections shaped `key → spec` (everything except queries and manual).
  void _readKeyedSection(
    Object? section,
    NativePlatform platform,
    RequirementKind kind,
    String path,
  ) {
    if (section is! Map) {
      problems.add('$path: must be a map of key → spec.');
      return;
    }
    if (kind == RequirementKind.activityClass && section.length > 1) {
      problems.add('$path: at most one class can be required.');
    }
    final isPlist =
        kind == RequirementKind.infoPlistKey ||
        kind == RequirementKind.entitlement;
    final isComponent = kind == RequirementKind.component;
    for (final MapEntry(:key, :value) in section.entries) {
      final itemPath = '$path.$key';
      if (key is! String || key.isEmpty) {
        problems.add('$path: keys must be non-empty strings (got $key).');
        continue;
      }
      final spec = _readSpec(value, itemPath, {
        if (isPlist) 'expect_type',
        if (isComponent) 'kind',
      });
      if (spec == null) continue;
      final expectType = isPlist ? _readExpectType(spec, itemPath) : null;
      final componentKind = isComponent
          ? _readComponentKind(spec, itemPath)
          : null;
      if (spec.necessity == null || (isComponent && componentKind == null)) {
        continue;
      }
      requirements.add(
        Requirement(
          platform: platform,
          kind: kind,
          key: key,
          necessity: spec.necessity!,
          hint: spec.hint!,
          source: spec.source,
          expectType: expectType,
          componentKind: componentKind,
        ),
      );
    }
  }

  void _readQueries(Object? section, String path) {
    if (section is! List) {
      problems.add('$path: must be a list.');
      return;
    }
    for (final (index, item) in section.indexed) {
      final itemPath = '$path[$index]';
      final spec = _readSpec(item, itemPath, const {'intent', 'package'});
      if (spec == null) continue;
      final query = _readQuery(spec.map, itemPath);
      if (query == null || spec.necessity == null) continue;
      requirements.add(
        Requirement(
          platform: NativePlatform.android,
          kind: RequirementKind.query,
          key: query.describe(),
          necessity: spec.necessity!,
          hint: spec.hint!,
          source: spec.source,
          query: query,
        ),
      );
    }
  }

  AndroidQuery? _readQuery(Map<Object?, Object?> spec, String path) {
    final intent = spec['intent'];
    final package = spec['package'];
    if ((intent == null) == (package == null)) {
      problems.add('$path: must have exactly one of "intent" or "package".');
      return null;
    }
    if (package != null) {
      if (package is String && package.isNotEmpty) {
        return AndroidQuery.package(package);
      }
      problems.add('$path.package: must be a non-empty string.');
      return null;
    }
    if (intent is! Map) {
      problems.add('$path.intent: must be a map.');
      return null;
    }
    _checkKeys(intent, const {'action', 'scheme', 'mime_type'}, '$path.intent');
    final action = intent['action'];
    if (action is! String || action.isEmpty) {
      problems.add('$path.intent.action: is required.');
      return null;
    }
    return AndroidQuery.intent(
      action: action,
      scheme: intent['scheme']?.toString(),
      mimeType: intent['mime_type']?.toString(),
    );
  }

  void _readManual(Object? section, NativePlatform platform, String path) {
    if (section is! List) {
      problems.add('$path: must be a list.');
      return;
    }
    for (final (index, item) in section.indexed) {
      final itemPath = '$path[$index]';
      final spec = _readSpec(item, itemPath, const {'id'});
      if (spec == null) continue;
      final id = spec.map['id'];
      if (id is! String || !_kebabCase.hasMatch(id)) {
        problems.add('$itemPath.id: must be a kebab-case id (got $id).');
        continue;
      }
      if (spec.necessity == null) continue;
      requirements.add(
        Requirement(
          platform: platform,
          kind: RequirementKind.manual,
          key: id,
          necessity: spec.necessity!,
          hint: spec.hint!,
          source: spec.source,
        ),
      );
    }
  }

  /// Reads the fields every item has (`required`, `hint`, `source`) and
  /// rejects fields other than those plus [extraFields].
  _Spec? _readSpec(Object? value, String path, Set<String> extraFields) {
    if (value is! Map) {
      problems.add('$path: must be a map with "required" and "hint".');
      return null;
    }
    _checkKeys(value, {..._specFields, ...extraFields}, path);

    final required = value['required'];
    final necessity = switch (required) {
      true => Necessity.required,
      'when_used' => Necessity.whenUsed,
      _ => null,
    };
    if (necessity == null) {
      problems.add(
        '$path.required: must be true or when_used (got $required). '
        'To drop an item, remove it instead of using false.',
      );
    }
    final hint = value['hint'];
    if (hint is! String || hint.trim().isEmpty) {
      problems.add('$path.hint: must be a non-empty string.');
    }
    final source = _readUrl(value['source'], '$path.source');
    return _Spec(
      value,
      necessity: hint is String && hint.trim().isNotEmpty ? necessity : null,
      hint: hint is String ? hint : null,
      source: source,
    );
  }

  PlistType? _readExpectType(_Spec spec, String path) {
    final value = spec.map['expect_type'];
    if (value == null) return null;
    final type = PlistType.values.where((t) => t.name == value).firstOrNull;
    if (type == null) {
      final names = PlistType.values.map((t) => t.name).join(', ');
      problems.add('$path.expect_type: must be one of $names (got $value).');
    }
    return type;
  }

  ComponentKind? _readComponentKind(_Spec spec, String path) {
    final value = spec.map['kind'];
    final kind = ComponentKind.values.where((k) => k.name == value).firstOrNull;
    if (kind == null) {
      final names = ComponentKind.values.map((k) => k.name).join(', ');
      problems.add('$path.kind: must be one of $names (got $value).');
    }
    return kind;
  }

  void _checkKeys(Map<Object?, Object?> map, Set<String> allowed, String path) {
    for (final key in map.keys) {
      if (!allowed.contains(key)) {
        problems.add(
          '$path: unknown field "$key" (allowed: ${allowed.join(', ')}).',
        );
      }
    }
  }
}

/// The common fields of one recipe item. [necessity] is null when the item
/// is invalid (the problem has already been recorded).
class _Spec {
  _Spec(this.map, {this.necessity, this.hint, this.source});

  final Map<Object?, Object?> map;
  final Necessity? necessity;
  final String? hint;
  final String? source;
}
