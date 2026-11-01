// Runs plumb's read-only check from Dart and prints each finding.
//
// Usage: dart run example/plumb_example.dart path/to/flutter_app
import 'dart:io';

import 'package:plumb/plumb.dart';

void main(List<String> args) {
  try {
    final report = runDoctor(args.isEmpty ? '.' : args.first);
    for (final finding in report.findings) {
      stdout.writeln('${finding.severity.name.padRight(7)} ${finding.message}');
    }
    stdout.writeln(report.summary);
    exitCode = report.exitCode(strict: true);
  } on PlumbException catch (e) {
    stderr.writeln(e.message);
    exitCode = ExitCodes.incomplete;
  }
}
