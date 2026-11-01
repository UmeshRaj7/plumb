import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

/// The value types an XML property list can contain.
enum PlistType {
  /// `<string>` → [String].
  string,

  /// `<true/>` / `<false/>` → [bool].
  boolean,

  /// `<integer>` → [int].
  integer,

  /// `<real>` → [double].
  real,

  /// `<date>` → [DateTime].
  date,

  /// `<data>` → [Uint8List].
  data,

  /// `<array>` → `List<Object?>`.
  array,

  /// `<dict>` → `Map<String, Object?>`.
  dict;

  /// The plist type of a value produced by [parsePlist].
  static PlistType of(Object? value) => switch (value) {
    String() => string,
    bool() => boolean,
    int() => integer,
    double() => real,
    DateTime() => date,
    // Before List: Uint8List is also a List.
    Uint8List() => data,
    List<Object?>() => array,
    Map<String, Object?>() => dict,
    _ => throw ArgumentError.value(value, 'value', 'not a plist value'),
  };
}

/// Parses an XML property list whose root is a `<dict>`, such as Info.plist
/// or an `.entitlements` file.
///
/// Returns plain Dart values (see [PlistType]). Throws [FormatException] for
/// malformed XML or a document that isn't a plist dict. Binary plists must be
/// rejected before calling this (see [looksLikeBinaryPlist]).
Map<String, Object?> parsePlist(String xml) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(_stripBom(xml));
  } on XmlException catch (e) {
    throw FormatException('Invalid XML: ${e.message}');
  }
  final root = document.rootElement;
  if (root.name.local != 'plist') {
    throw FormatException(
      'Expected <plist> root element, found <${root.name.local}>.',
    );
  }
  final values = root.childElements.toList();
  if (values.length != 1 || values.single.name.local != 'dict') {
    throw const FormatException(
      'Expected the plist to contain a single <dict>.',
    );
  }
  return _readDict(values.single);
}

/// Whether [bytes] start with the binary plist magic (`bplist`).
bool looksLikeBinaryPlist(List<int> bytes) {
  const magic = [0x62, 0x70, 0x6c, 0x69, 0x73, 0x74]; // "bplist"
  if (bytes.length < magic.length) return false;
  for (var i = 0; i < magic.length; i++) {
    if (bytes[i] != magic[i]) return false;
  }
  return true;
}

String _stripBom(String text) =>
    text.startsWith('\uFEFF') ? text.substring(1) : text;

Map<String, Object?> _readDict(XmlElement dict) {
  final result = <String, Object?>{};
  final children = dict.childElements.toList();
  for (var i = 0; i < children.length; i += 2) {
    final keyElement = children[i];
    if (keyElement.name.local != 'key') {
      throw FormatException(
        'Expected <key> in <dict>, found <${keyElement.name.local}>.',
      );
    }
    if (i + 1 >= children.length) {
      throw FormatException('Key "${keyElement.innerText}" has no value.');
    }
    result[keyElement.innerText] = _readValue(children[i + 1]);
  }
  return result;
}

Object? _readValue(XmlElement element) {
  final text = element.innerText;
  switch (element.name.local) {
    case 'string':
      return text;
    case 'true':
      return true;
    case 'false':
      return false;
    case 'integer':
      return int.tryParse(text.trim()) ??
          (throw FormatException('Invalid <integer>: "$text".'));
    case 'real':
      return double.tryParse(text.trim()) ??
          (throw FormatException('Invalid <real>: "$text".'));
    case 'date':
      return DateTime.tryParse(text.trim()) ??
          (throw FormatException('Invalid <date>: "$text".'));
    case 'data':
      try {
        return base64.decode(text.replaceAll(RegExp(r'\s'), ''));
      } on FormatException {
        throw FormatException('Invalid <data>: "$text".');
      }
    case 'array':
      return [for (final child in element.childElements) _readValue(child)];
    case 'dict':
      return _readDict(element);
    default:
      throw FormatException('Unknown plist element <${element.name.local}>.');
  }
}
