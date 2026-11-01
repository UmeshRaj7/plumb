/// Values that look like they were never filled in. Kept deliberately small
/// (ARCHITECTURE.md §6.2): each pattern must almost never match a real
/// purpose string, because a false ⚠ costs more trust than a missed one.
final _placeholderPatterns = [
  RegExp(r'\b(TODO|FIXME|TBD)\b', caseSensitive: false),
  RegExp(r'lorem ipsum', caseSensitive: false),
  RegExp(r'placeholder', caseSensitive: false),
  // Whole value "your … here", e.g. "your usage description here" (camera
  // README) or "YOUR KEY HERE" (google_maps_flutter README).
  RegExp(r'^your\b.{0,40}\bhere\W*$', caseSensitive: false),
  RegExp(r'\bYOUR_[A-Z0-9_]+\b'),
];

final _buildVariable = RegExp(r'\$\([^)]+\)|\$\{[^}]+\}');

/// Whether [value] is empty or a known placeholder such as "TODO".
/// Build variables (see [isBuildVariable]) are never placeholders.
bool isPlaceholder(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return true;
  if (isBuildVariable(trimmed)) return false;
  return _placeholderPatterns.any((p) => p.hasMatch(trimmed));
}

/// Whether [value] contains an Xcode `$(VAR)` or Gradle `${var}` reference,
/// which is only resolved at build time (so plumb can't see the real value).
bool isBuildVariable(String value) => _buildVariable.hasMatch(value);

/// The message for a placeholder [value] of [subject]: "is empty" or
/// "looks like a placeholder".
String placeholderMessage(String subject, String value) => value.trim().isEmpty
    ? '$subject is empty'
    : '$subject looks like a placeholder: "${value.trim()}"';

/// The fix for a placeholder: replace it, then the recipe's own hint.
String placeholderFix(String hint) => 'Replace it with a real value. $hint';
