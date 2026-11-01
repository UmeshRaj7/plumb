# plumb examples

## Command line

```sh
dart pub global activate plumb
cd my_flutter_app

plumb doctor            # report
plumb doctor --strict   # fail CI on ✗ and ⚠
plumb doctor --json     # machine-readable
```

## Dart API

The same read-only check is available as a library; see
[plumb_example.dart](plumb_example.dart):

```dart
import 'package:plumb/plumb.dart';

void main(List<String> args) {
  final report = runDoctor(args.isEmpty ? '.' : args.first);
  for (final finding in report.findings) {
    print('${finding.severity.name.padRight(7)} ${finding.message}');
  }
  print(report.summary);
}
```
