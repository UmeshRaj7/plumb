/// Finds the superclass of [className] in Kotlin or Java [source].
///
/// Returns the name as written (simple or fully qualified), or null when the
/// class isn't declared or has no superclass. This is a deliberate text
/// search, not a compiler: it covers the forms Flutter templates and plugin
/// docs use (`class MainActivity : FlutterFragmentActivity()` and
/// `class MainActivity extends FlutterFragmentActivity`). For Kotlin the
/// first supertype is assumed to be the superclass.
String? findSuperclass(String source, String className) {
  final code = _stripComments(source);
  final name = RegExp.escape(className);
  final kotlin = RegExp('\\bclass\\s+$name\\b[^:{\\n]*:\\s*([\\w.]+)');
  final java = RegExp('\\bclass\\s+$name\\s+extends\\s+([\\w.]+)');
  return (kotlin.firstMatch(code) ?? java.firstMatch(code))?.group(1);
}

String _stripComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');
