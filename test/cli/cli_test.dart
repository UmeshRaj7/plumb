import 'package:plumb/src/cli/cli.dart';
import 'package:plumb/src/exit_codes.dart';
import 'package:plumb/src/version.dart';
import 'package:test/test.dart';

/// Runs the CLI with captured output.
Future<({int code, String out, String err})> run(List<String> args) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runCli(
    args,
    console: Console(out: out, err: err),
  );
  return (code: code, out: out.toString(), err: err.toString());
}

void main() {
  test('--version prints the package version', () async {
    final result = await run(['--version']);
    expect(result.code, ExitCodes.ok);
    expect(result.out.trim(), 'plumb $packageVersion');
  });

  test('help describes plumb as read-only', () async {
    final result = await run(['help']);
    expect(result.code, ExitCodes.ok);
    expect(result.out, contains('Read-only'));
    expect(result.out, contains('doctor'));
  });

  test('unknown flag is a usage error (exit 64)', () async {
    final result = await run(['doctor', '--nope']);
    expect(result.code, ExitCodes.usage);
    expect(result.err, contains('nope'));
  });

  test('more than one path is a usage error', () async {
    final result = await run(['doctor', 'a', 'b']);
    expect(result.code, ExitCodes.usage);
  });
}
