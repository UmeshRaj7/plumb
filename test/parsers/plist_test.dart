import 'dart:convert';
import 'dart:typed_data';

import 'package:plumb/src/parsers/plist.dart';
import 'package:test/test.dart';

String plist(String body) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
$body
</plist>
''';

void main() {
  group('parsePlist', () {
    test('reads every value type', () {
      final result = parsePlist(
        plist('''
<dict>
  <key>s</key><string>Hello &amp; welcome</string>
  <key>empty</key><string/>
  <key>t</key><true/>
  <key>f</key><false/>
  <key>i</key><integer>-42</integer>
  <key>r</key><real>1.5</real>
  <key>d</key><date>2026-11-01T10:00:00Z</date>
  <key>b</key><data>aGk=</data>
  <key>a</key><array><string>fetch</string><integer>1</integer></array>
  <key>nested</key><dict><key>k</key><string>v</string></dict>
</dict>'''),
      );

      expect(result['s'], 'Hello & welcome');
      expect(result['empty'], '');
      expect(result['t'], true);
      expect(result['f'], false);
      expect(result['i'], -42);
      expect(result['r'], 1.5);
      expect(result['d'], DateTime.utc(2026, 11, 1, 10));
      expect(result['b'], utf8.encode('hi'));
      expect(result['a'], ['fetch', 1]);
      expect(result['nested'], {'k': 'v'});
    });

    test('accepts a UTF-8 BOM and CRLF line endings', () {
      final text =
          '\uFEFF${plist('<dict><key>k</key><string>v</string></dict>')}'
              .replaceAll('\n', '\r\n');
      expect(parsePlist(text), {'k': 'v'});
    });

    test('accepts an empty dict', () {
      expect(parsePlist(plist('<dict/>')), isEmpty);
    });

    test('rejects malformed XML', () {
      expect(
        () => parsePlist('<plist><dict><key>k</key>'),
        throwsFormatException,
      );
    });

    test('rejects a root that is not a dict', () {
      expect(
        () => parsePlist(plist('<array/>')),
        throwsA(
          isFormatException.having(
            (e) => e.message,
            'message',
            contains('dict'),
          ),
        ),
      );
    });

    test('rejects a document without <plist>', () {
      expect(() => parsePlist('<dict/>'), throwsFormatException);
    });

    test('rejects a key without a value', () {
      expect(
        () => parsePlist(plist('<dict><key>k</key></dict>')),
        throwsFormatException,
      );
    });

    test('rejects an unknown value element', () {
      expect(
        () => parsePlist(plist('<dict><key>k</key><nope/></dict>')),
        throwsFormatException,
      );
    });

    test('rejects an invalid integer', () {
      expect(
        () =>
            parsePlist(plist('<dict><key>k</key><integer>x</integer></dict>')),
        throwsFormatException,
      );
    });
  });

  group('looksLikeBinaryPlist', () {
    test('detects the bplist magic', () {
      expect(looksLikeBinaryPlist(ascii.encode('bplist00\x00\x01')), isTrue);
    });

    test('is false for XML', () {
      expect(looksLikeBinaryPlist(utf8.encode(plist('<dict/>'))), isFalse);
    });

    test('is false for short input', () {
      expect(looksLikeBinaryPlist([0x62]), isFalse);
    });
  });

  group('PlistType.of', () {
    test('maps Dart values to plist types', () {
      expect(PlistType.of('x'), PlistType.string);
      expect(PlistType.of(true), PlistType.boolean);
      expect(PlistType.of(1), PlistType.integer);
      expect(PlistType.of(1.0), PlistType.real);
      expect(PlistType.of(<Object?>[]), PlistType.array);
      expect(PlistType.of(<String, Object?>{}), PlistType.dict);
      expect(PlistType.of(DateTime(2026)), PlistType.date);
      expect(PlistType.of(Uint8List.fromList([1])), PlistType.data);
    });
  });
}
