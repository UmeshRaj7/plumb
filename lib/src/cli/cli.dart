import 'dart:async';
import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../errors.dart';
import '../exit_codes.dart';
import '../version.dart';
import 'doctor_command.dart';

/// Where the CLI writes output and how it should look. Injected so tests can
/// capture output without touching the real terminal.
class Console {
  /// Creates a console writing to [out] and [err].
  const Console({
    required this.out,
    required this.err,
    this.supportsAnsi = false,
    this.environment = const {},
  });

  /// A console bound to the process's real stdout/stderr.
  factory Console.system() => Console(
    out: io.stdout,
    err: io.stderr,
    supportsAnsi: io.stdout.hasTerminal && io.stdout.supportsAnsiEscapes,
    environment: io.Platform.environment,
  );

  /// Normal output (reports).
  final StringSink out;

  /// Error messages.
  final StringSink err;

  /// Whether [out] is a terminal that understands ANSI color codes.
  final bool supportsAnsi;

  /// Process environment, used for `NO_COLOR`.
  final Map<String, String> environment;
}

/// Runs the plumb CLI with [args] and returns the process exit code.
Future<int> runCli(List<String> args, {Console? console}) async {
  final terminal = console ?? Console.system();
  final runner = _PlumbCommandRunner(terminal);
  try {
    // package:args prints help with `print`; route it to our console.
    return await runZoned(
      () async => await runner.run(args) ?? ExitCodes.ok,
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => terminal.out.writeln(line),
      ),
    );
  } on UsageException catch (e) {
    terminal.err.writeln(e.message);
    terminal.err.writeln();
    terminal.err.writeln(e.usage);
    return ExitCodes.usage;
  } on PlumbException catch (e) {
    terminal.err.writeln('plumb: ${e.message}');
    return ExitCodes.incomplete;
  }
}

class _PlumbCommandRunner extends CommandRunner<int> {
  _PlumbCommandRunner(this._console)
    : super(
        'plumb',
        'plumb — native config for Flutter™.\n'
            'Checks your iOS and Android config against what your plugins\' '
            'docs require. Read-only: plumb never changes your project.',
      ) {
    argParser.addFlag(
      'version',
      negatable: false,
      help: 'Print the plumb version.',
    );
    addCommand(DoctorCommand());
  }

  final Console _console;

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults.flag('version')) {
      _console.out.writeln('plumb $packageVersion');
      return ExitCodes.ok;
    }
    return super.runCommand(topLevelResults);
  }
}
