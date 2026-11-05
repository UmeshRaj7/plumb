import 'package:plumb/src/parsers/pbxproj.dart';
import 'package:test/test.dart';

void main() {
  group('infoPlistFileSettings', () {
    test('reads quoted and unquoted values, sorted, without duplicates', () {
      const pbxproj = '''
		INFOPLIST_FILE = Runner/Info.plist;
		INFOPLIST_FILE = "Runner/Info-\$(CONFIGURATION).plist";
		INFOPLIST_FILE = StatusWidget/Info.plist;
		INFOPLIST_FILE = Runner/Info.plist;
''';
      expect(infoPlistFileSettings(pbxproj), [
        r'Runner/Info-$(CONFIGURATION).plist',
        'Runner/Info.plist',
        'StatusWidget/Info.plist',
      ]);
    });

    test('ignores GENERATE_INFOPLIST_FILE and INFOPLIST_KEY_*', () {
      const pbxproj = '''
		GENERATE_INFOPLIST_FILE = YES;
		INFOPLIST_KEY_NSCameraUsageDescription = "Scan receipts";
''';
      expect(infoPlistFileSettings(pbxproj), isEmpty);
    });

    test(r'drops a leading $(SRCROOT)/', () {
      const pbxproj = r'''
		INFOPLIST_FILE = "$(SRCROOT)/Runner/Info.plist";
		INFOPLIST_FILE = ${SRCROOT}/Runner/Info-Prod.plist;
''';
      expect(infoPlistFileSettings(pbxproj), [
        'Runner/Info-Prod.plist',
        'Runner/Info.plist',
      ]);
    });
  });

  group('runnerInfoPlistSettings', () {
    test('keeps only plists in Runner/', () {
      const pbxproj = '''
		INFOPLIST_FILE = "Runner/Info-\$(CONFIGURATION).plist";
		INFOPLIST_FILE = ShareExtension/Info.plist;
		INFOPLIST_FILE = RunnerTests/Info.plist;
''';
      expect(runnerInfoPlistSettings(pbxproj), [
        r'Runner/Info-$(CONFIGURATION).plist',
      ]);
    });
  });
}
