import 'dart:io' show Directory;

import 'package:args/command_runner.dart';

import '../doctor.dart';
import '../errors.dart';
import '../exit_codes.dart';
import '../report/json_renderer.dart';
import '../report/text_renderer.dart';
import 'cli.dart';

/// `plumb doctor`: checks the native config of a Flutter app (read-only).
class DoctorCommand extends Command<int> {
  /// Creates the command, writing output to [_console].
  DoctorCommand(this._console) {
    argParser
      ..addFlag(
        'json',
        negatable: false,
        help: 'Print machine-readable JSON (for CI and AI agents).',
      )
      ..addFlag(
        'strict',
        negatable: false,
        help: 'Exit with code 1 if anything is missing or a placeholder.',
      )
      ..addFlag(
        'verbose',
        negatable: false,
        help: 'List every conditional and manual item instead of a count.',
      )
      ..addFlag(
        'color',
        defaultsTo: true,
        help: 'Use colors when the terminal supports them (respects NO_COLOR).',
      );
  }

  final Console _console;

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Check Info.plist, entitlements and AndroidManifest against what your '
      'plugins need. Never modifies your project.\n\n'
      'Exit codes: 0 done (with --strict: nothing missing), 1 --strict and '
      'something is missing or a placeholder, 2 incomplete check, 64 usage error.';

  @override
  String get invocation => 'plumb doctor [path] [options]';

  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.length > 1) {
      usageException('Expected at most one path, got ${args.rest.length}.');
    }
    final path = args.rest.isEmpty ? Directory.current.path : args.rest.single;
    final json = args.flag('json');

    try {
      final report = runDoctor(path);
      _console.out.write(
        json
            ? renderJson(report)
            : renderText(
                report,
                color: args.flag('color') && _colorAllowed,
                verbose: args.flag('verbose'),
              ),
      );
      return report.exitCode(strict: args.flag('strict'));
    } on PlumbException catch (e) {
      if (!json) rethrow; // runCli prints it to stderr.
      _console.out.write(renderJsonError(e.message));
      return ExitCodes.incomplete;
    }
  }

  /// https://no-color.org: any non-empty NO_COLOR disables color.
  bool get _colorAllowed =>
      _console.supportsAnsi && (_console.environment['NO_COLOR'] ?? '').isEmpty;
}
