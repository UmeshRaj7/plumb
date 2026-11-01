import 'package:args/command_runner.dart';

import '../errors.dart';

/// `plumb doctor`: checks the native config of a Flutter app (read-only).
class DoctorCommand extends Command<int> {
  /// Creates the command and its flags.
  DoctorCommand() {
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

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Check Info.plist, entitlements and AndroidManifest against what your '
      'plugins need. Never modifies your project.';

  @override
  String get invocation => 'plumb doctor [path] [options]';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length > 1) {
      usageException('Expected at most one path, got ${rest.length}.');
    }
    // Wired up in milestone 12; until then fail loudly instead of pretending.
    throw const PlumbException('doctor is not implemented yet.');
  }
}
