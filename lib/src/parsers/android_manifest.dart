import 'package:xml/xml.dart';

const _androidNs = 'http://schemas.android.com/apk/res/android';
const _toolsNs = 'http://schemas.android.com/tools';

/// The `<application>` child elements plumb understands.
enum ComponentKind {
  /// `<activity>`
  activity,

  /// `<receiver>`
  receiver,

  /// `<service>`
  service,

  /// `<provider>`
  provider,
}

/// A component declared directly under `<application>`.
class ManifestComponent {
  /// Creates a component.
  const ManifestComponent(this.kind, this.name, {this.removed = false});

  /// Element type.
  final ComponentKind kind;

  /// `android:name` exactly as written (may be relative, e.g. `.MainActivity`).
  final String name;

  /// Whether it is marked `tools:node="remove"`.
  final bool removed;
}

/// One `<queries><intent>` entry.
class QueryIntent {
  /// Creates a query intent.
  const QueryIntent({
    required this.actions,
    required this.schemes,
    required this.mimeTypes,
  });

  /// `<action android:name>` values.
  final Set<String> actions;

  /// `<data android:scheme>` values.
  final Set<String> schemes;

  /// `<data android:mimeType>` values.
  final Set<String> mimeTypes;
}

/// The parts of an AndroidManifest.xml that plumb checks.
///
/// Only the places plugin docs tell you to edit are read: direct children of
/// `<manifest>` and of `<application>`. Nested elements (e.g. an activity's
/// own `<meta-data>`) are ignored on purpose.
class AndroidManifest {
  /// Creates a manifest model.
  const AndroidManifest({
    this.packageName,
    this.permissions = const {},
    this.removedPermissions = const {},
    this.metaData = const {},
    this.components = const [],
    this.launcherActivity,
    this.queryIntents = const [],
    this.queryPackages = const {},
  });

  /// The legacy `package` attribute (modern projects set it in Gradle).
  final String? packageName;

  /// Declared `<uses-permission>` / `<uses-permission-sdk-23>` names.
  final Set<String> permissions;

  /// Permissions marked `tools:node="remove"`.
  final Set<String> removedPermissions;

  /// `<application><meta-data>`: name → `android:value` (or `android:resource`).
  final Map<String, String?> metaData;

  /// Components directly under `<application>`, in document order.
  final List<ManifestComponent> components;

  /// `android:name` of the MAIN/LAUNCHER activity (alias targets resolved).
  final String? launcherActivity;

  /// `<queries><intent>` entries.
  final List<QueryIntent> queryIntents;

  /// `<queries><package android:name>` values.
  final Set<String> queryPackages;
}

/// Parses AndroidManifest.xml. Throws [FormatException] for malformed XML or
/// a root element other than `<manifest>`.
AndroidManifest parseAndroidManifest(String xml) {
  final XmlElement root;
  try {
    root = XmlDocument.parse(_stripBom(xml)).rootElement;
  } on XmlException catch (e) {
    throw FormatException('Invalid XML: ${e.message}');
  }
  if (root.name.local != 'manifest') {
    throw FormatException(
      'Expected <manifest> root element, found <${root.name.local}>.',
    );
  }

  final permissions = <String>{};
  final removedPermissions = <String>{};
  for (final element in root.childElements) {
    final tag = element.name.local;
    if (tag != 'uses-permission' && tag != 'uses-permission-sdk-23') continue;
    final name = _android(element, 'name');
    if (name == null) continue;
    (_isRemoved(element) ? removedPermissions : permissions).add(name);
  }

  final application = _firstChild(root, 'application');
  final queries = _firstChild(root, 'queries');
  return AndroidManifest(
    packageName: root.getAttribute('package'),
    permissions: permissions,
    removedPermissions: removedPermissions,
    metaData: application == null ? const {} : _readMetaData(application),
    components: application == null ? const [] : _readComponents(application),
    launcherActivity: application == null
        ? null
        : _findLauncherActivity(application),
    queryIntents: queries == null ? const [] : _readQueryIntents(queries),
    queryPackages: {
      if (queries != null)
        for (final p in queries.childElements.where(_isTag('package')))
          ?_android(p, 'name'),
    },
  );
}

Map<String, String?> _readMetaData(XmlElement application) => {
  for (final m in application.childElements.where(_isTag('meta-data')))
    ?_android(m, 'name'): _android(m, 'value') ?? _android(m, 'resource'),
};

List<ManifestComponent> _readComponents(XmlElement application) => [
  for (final element in application.childElements)
    if (_componentKind(element.name.local) case final kind?)
      if (_android(element, 'name') case final name?)
        ManifestComponent(kind, name, removed: _isRemoved(element)),
];

String? _findLauncherActivity(XmlElement application) {
  for (final element in application.childElements) {
    final tag = element.name.local;
    if (tag != 'activity' && tag != 'activity-alias') continue;
    if (!_isLauncher(element)) continue;
    return tag == 'activity-alias'
        ? _android(element, 'targetActivity')
        : _android(element, 'name');
  }
  return null;
}

bool _isLauncher(XmlElement activity) {
  for (final filter in activity.childElements.where(_isTag('intent-filter'))) {
    final actions = _androidNames(filter, 'action');
    final categories = _androidNames(filter, 'category');
    if (actions.contains('android.intent.action.MAIN') &&
        categories.contains('android.intent.category.LAUNCHER')) {
      return true;
    }
  }
  return false;
}

List<QueryIntent> _readQueryIntents(XmlElement queries) => [
  for (final intent in queries.childElements.where(_isTag('intent')))
    QueryIntent(
      actions: _androidNames(intent, 'action'),
      schemes: {
        for (final d in intent.childElements.where(_isTag('data')))
          ?_android(d, 'scheme'),
      },
      mimeTypes: {
        for (final d in intent.childElements.where(_isTag('data')))
          ?_android(d, 'mimeType'),
      },
    ),
];

ComponentKind? _componentKind(String tag) => switch (tag) {
  'activity' => ComponentKind.activity,
  'receiver' => ComponentKind.receiver,
  'service' => ComponentKind.service,
  'provider' => ComponentKind.provider,
  _ => null,
};

/// `android:name` values of child elements with the given [tag].
Set<String> _androidNames(XmlElement parent, String tag) => {
  for (final child in parent.childElements.where(_isTag(tag)))
    ?_android(child, 'name'),
};

String? _android(XmlElement element, String attribute) =>
    _attribute(element, attribute, _androidNs);

bool _isRemoved(XmlElement element) {
  final node = _attribute(element, 'node', _toolsNs);
  return node == 'remove' || node == 'removeAll';
}

/// Looks up an attribute by namespace URI, so any prefix works. (Matching on
/// `XmlName` keeps us compatible with both package:xml 6 and 7.)
String? _attribute(XmlElement element, String local, String namespaceUri) {
  for (final attribute in element.attributes) {
    if (attribute.name.local == local &&
        attribute.name.namespaceUri == namespaceUri) {
      return attribute.value;
    }
  }
  return null;
}

XmlElement? _firstChild(XmlElement parent, String tag) =>
    parent.childElements.where(_isTag(tag)).firstOrNull;

bool Function(XmlElement) _isTag(String tag) =>
    (element) => element.name.local == tag;

String _stripBom(String text) =>
    text.startsWith('\uFEFF') ? text.substring(1) : text;
