/// The `INFOPLIST_FILE` build settings in an Xcode `project.pbxproj`, as
/// written but without quotes or a leading `$(SRCROOT)/`, sorted and
/// without duplicates. `GENERATE_INFOPLIST_FILE` is a different setting and
/// is not included.
///
/// plumb doesn't parse targets or build configurations; a text search is
/// enough to tell which plist files the project points at.
List<String> infoPlistFileSettings(String pbxproj) {
  final setting = RegExp(
    r'(?<![A-Za-z0-9_])INFOPLIST_FILE\s*=\s*(?:"([^"]*)"|([^;\s]+))\s*;',
  );
  final values = <String>{
    for (final match in setting.allMatches(pbxproj))
      (match[1] ?? match[2]!).replaceFirst(RegExp(r'^\$[({]SRCROOT[)}]/'), ''),
  };
  return values.toList()..sort();
}

/// The `INFOPLIST_FILE` settings that point into `ios/Runner/` (paths
/// relative to `ios/`), e.g. `Runner/Info.plist` or
/// `Runner/Info-$(CONFIGURATION).plist`.
List<String> runnerInfoPlistSettings(String pbxproj) => [
  for (final value in infoPlistFileSettings(pbxproj))
    if (value.startsWith('Runner/')) value,
];
