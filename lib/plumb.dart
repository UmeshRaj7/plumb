/// plumb — native config for Flutter™.
///
/// The command-line tool is the main entry point (`plumb doctor`). This
/// library exposes the same check as a Dart API for tools that want the
/// findings without parsing CLI output.
library;

export 'src/errors.dart' show PlumbException;
export 'src/exit_codes.dart' show ExitCodes;
export 'src/version.dart' show packageVersion;
