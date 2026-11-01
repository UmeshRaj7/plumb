/// Process exit codes used by the plumb CLI.
abstract final class ExitCodes {
  /// The run completed; with `--strict`, nothing is missing or a placeholder.
  static const int ok = 0;

  /// `--strict` was given and at least one finding is `missing` or `warning`.
  static const int findings = 1;

  /// plumb could not complete the check (setup error or unreadable native file).
  static const int incomplete = 2;

  /// The command line was invalid (sysexits `EX_USAGE`, as used by `dart`).
  static const int usage = 64;
}
