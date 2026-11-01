import 'package:plumb/src/checks/placeholder.dart';
import 'package:test/test.dart';

void main() {
  group('isPlaceholder is true for', () {
    for (final value in [
      '',
      '   ',
      'TODO',
      'todo: explain',
      'FIXME',
      'TBD',
      'Lorem ipsum dolor',
      'placeholder',
      'your usage description here',
      'YOUR KEY HERE',
      'Your description here.',
      'YOUR_API_KEY',
    ]) {
      test('"$value"', () => expect(isPlaceholder(value), isTrue));
    }
  });

  group('isPlaceholder is false for', () {
    for (final value in [
      'We use the camera to scan receipts.',
      'We use your location to show stores near here.',
      'Your photos are only used to set your profile picture.',
      'This app needs access to location when open.',
      r'$(PRODUCT_NAME) uses Face ID to unlock',
      r'${MAPS_API_KEY}',
      'AIzaSyD-example-real-looking-key',
      'Todos are synced with your calendar', // a different word
    ]) {
      test('"$value"', () => expect(isPlaceholder(value), isFalse));
    }
  });

  group('isBuildVariable', () {
    test('detects Xcode and Gradle variables', () {
      expect(isBuildVariable(r'$(CAMERA_USAGE)'), isTrue);
      expect(isBuildVariable(r'${MAPS_API_KEY}'), isTrue);
      expect(isBuildVariable(r'Costs $5'), isFalse);
    });
  });
}
