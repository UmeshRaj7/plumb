import 'package:plumb/src/parsers/activity_source.dart';
import 'package:test/test.dart';

void main() {
  group('findSuperclass', () {
    test('Kotlin (Flutter template)', () {
      const source = '''
package dev.example.app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
''';
      expect(findSuperclass(source, 'MainActivity'), 'FlutterActivity');
    });

    test('Kotlin with body, modifiers and no space before the colon', () {
      const source = '''
open class MainActivity: FlutterFragmentActivity() {
}''';
      expect(findSuperclass(source, 'MainActivity'), 'FlutterFragmentActivity');
    });

    test('Kotlin fully-qualified superclass', () {
      const source =
          'class MainActivity : io.flutter.embedding.android.FlutterFragmentActivity()';
      expect(
        findSuperclass(source, 'MainActivity'),
        'io.flutter.embedding.android.FlutterFragmentActivity',
      );
    });

    test('Java', () {
      const source = '''
public class MainActivity extends FlutterFragmentActivity {
}''';
      expect(findSuperclass(source, 'MainActivity'), 'FlutterFragmentActivity');
    });

    test('ignores commented-out declarations', () {
      const source = '''
// class MainActivity : FlutterFragmentActivity()
/* class MainActivity : FlutterFragmentActivity() */
class MainActivity : FlutterActivity()
''';
      expect(findSuperclass(source, 'MainActivity'), 'FlutterActivity');
    });

    test('does not match a class whose name only starts the same', () {
      const source = 'class MainActivityHelper : Base()';
      expect(findSuperclass(source, 'MainActivity'), isNull);
    });

    test('returns null when the class has no superclass or is absent', () {
      expect(findSuperclass('class MainActivity {}', 'MainActivity'), isNull);
      expect(findSuperclass('', 'MainActivity'), isNull);
    });
  });
}
