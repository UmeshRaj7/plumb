/// Recipe samples shared by the Dart parser tests and the JSON Schema
/// agreement test, so both validators are held to the same cases.
library;

/// A valid recipe that uses every section and field.
const fullRecipe = '''
schema: 1
package: example_plugin
versions: ">=1.0.0 <2.0.0"
source: https://pub.dev/packages/example_plugin
ios:
  info_plist:
    NSCameraUsageDescription: { required: true, hint: "Explain camera use" }
    LSApplicationQueriesSchemes: { required: when_used, hint: "Schemes", expect_type: array }
  entitlements:
    aps-environment: { required: true, hint: "Push", source: "https://developer.apple.com/aps" }
  background_modes:
    remote-notification: { required: true, hint: "Background push" }
  manual:
    - { id: appdelegate-key, required: true, hint: "Set the key in AppDelegate" }
android:
  permissions:
    android.permission.CAMERA: { required: true, hint: "Camera" }
  queries:
    - { intent: { action: android.intent.action.VIEW, scheme: https }, required: when_used, hint: "Browser" }
    - { package: com.example.other, required: when_used, hint: "Other app" }
  manifest_meta_data:
    com.example.API_KEY: { required: true, hint: "API key" }
  components:
    com.example.Receiver: { kind: receiver, required: when_used, hint: "Receiver" }
  activity_class:
    io.flutter.embedding.android.FlutterFragmentActivity: { required: true, hint: "Fragment activity" }
  manual:
    - { id: desugaring, required: true, hint: "Enable desugaring" }
''';

/// A valid recipe with empty and null sections.
const minimalRecipe = '''
schema: 1
package: tiny
versions: any
source: https://pub.dev/packages/tiny
ios:
  info_plist: {}
  entitlements:
android:
  permissions: {}
  queries: []
''';

const _header = '''
schema: 1
package: p
versions: any
source: https://pub.dev/packages/p
''';

/// An invalid recipe and a substring of the expected problem message.
typedef InvalidRecipe = ({String description, String yaml, String problem});

/// Recipes every validator must reject.
const List<InvalidRecipe> invalidRecipes = [
  (description: 'not a map', yaml: '- a', problem: 'must be a map'),
  (description: 'invalid YAML', yaml: 'a: [', problem: 'Invalid YAML'),
  (
    description: 'missing schema',
    yaml: 'package: p\nversions: any\nsource: https://x.dev',
    problem: 'schema',
  ),
  (
    description: 'unsupported schema version',
    yaml: 'schema: 2\npackage: p\nversions: any\nsource: https://x.dev',
    problem: 'schema',
  ),
  (
    description: 'invalid package name',
    yaml: 'schema: 1\npackage: Not-Valid\nversions: any\nsource: https://x.dev',
    problem: 'package',
  ),
  (
    description: 'unparseable version constraint',
    yaml:
        'schema: 1\npackage: p\nversions: "not a range"\nsource: https://x.dev',
    problem: 'versions',
  ),
  (
    description: 'non-https source',
    yaml: 'schema: 1\npackage: p\nversions: any\nsource: http://x.dev',
    problem: 'source',
  ),
  (
    description: 'unknown top-level key',
    yaml: '${_header}macos: {}',
    problem: 'macos',
  ),
  (
    description: 'unknown ios section',
    yaml: '${_header}ios:\n  podfile: {}',
    problem: 'podfile',
  ),
  (
    description: 'required: false',
    yaml: '${_header}ios:\n  info_plist:\n    K: { required: false, hint: h }',
    problem: 'required',
  ),
  (
    description: 'missing hint',
    yaml: '${_header}ios:\n  info_plist:\n    K: { required: true }',
    problem: 'hint',
  ),
  (
    description: 'empty hint',
    yaml: '${_header}ios:\n  info_plist:\n    K: { required: true, hint: "" }',
    problem: 'hint',
  ),
  (
    description: 'unknown spec field',
    yaml:
        '${_header}android:\n  permissions:\n    P: { required: true, hint: h, maxSdk: 1 }',
    problem: 'maxSdk',
  ),
  (
    description: 'expect_type outside plist sections',
    yaml:
        '${_header}android:\n  permissions:\n    P: { required: true, hint: h, expect_type: string }',
    problem: 'expect_type',
  ),
  (
    description: 'unknown expect_type',
    yaml:
        '${_header}ios:\n  info_plist:\n    K: { required: true, hint: h, expect_type: text }',
    problem: 'expect_type',
  ),
  (
    description: 'component without kind',
    yaml:
        '${_header}android:\n  components:\n    C: { required: true, hint: h }',
    problem: 'kind',
  ),
  (
    description: 'unknown component kind',
    yaml:
        '${_header}android:\n  components:\n    C: { kind: widget, required: true, hint: h }',
    problem: 'kind',
  ),
  (
    description: 'two activity_class entries',
    yaml:
        '${_header}android:\n  activity_class:\n    A: { required: true, hint: h }\n    B: { required: true, hint: h }',
    problem: 'activity_class',
  ),
  (
    description: 'query with both intent and package',
    yaml:
        '${_header}android:\n  queries:\n    - { intent: { action: a }, package: p, required: true, hint: h }',
    problem: 'exactly one of',
  ),
  (
    description: 'query intent without action',
    yaml:
        '${_header}android:\n  queries:\n    - { intent: { scheme: s }, required: true, hint: h }',
    problem: 'action',
  ),
  (
    description: 'manual step without id',
    yaml: '${_header}ios:\n  manual:\n    - { required: true, hint: h }',
    problem: 'id',
  ),
  (
    description: 'manual id not kebab-case',
    yaml:
        '${_header}ios:\n  manual:\n    - { id: Not_Kebab, required: true, hint: h }',
    problem: 'id',
  ),
  (
    description: 'per-item source not https',
    yaml:
        '${_header}ios:\n  info_plist:\n    K: { required: true, hint: h, source: "ftp://x" }',
    problem: 'source',
  ),
];
