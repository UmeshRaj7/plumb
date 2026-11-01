import 'dart:convert';

import 'package:plumb/src/cli/cli.dart';
import 'package:plumb/src/exit_codes.dart';
import 'package:plumb/src/version.dart';
import 'package:test/test.dart';

/// Runs the CLI with captured output.
Future<({int code, String out, String err})> run(
  List<String> args, {
  bool ansi = false,
  Map<String, String> environment = const {},
}) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runCli(
    args,
    console: Console(
      out: out,
      err: err,
      supportsAnsi: ansi,
      environment: environment,
    ),
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

  group('doctor setup errors', () {
    test('a non-Flutter package is exit 2 with the reason on stderr', () async {
      final result = await run(['doctor', 'test/fixtures/dart_package']);
      expect(result.code, ExitCodes.incomplete);
      expect(result.out, isEmpty);
      expect(result.err, contains('not a Flutter app'));
    });

    test('with --json the error is JSON on stdout', () async {
      final result = await run([
        'doctor',
        'test/fixtures/dart_package',
        '--json',
      ]);
      expect(result.code, ExitCodes.incomplete);
      final json = jsonDecode(result.out) as Map<String, Object?>;
      expect(json['error'], contains('not a Flutter app'));
    });
  });

  group('doctor colors', () {
    const app = 'test/fixtures/broken_app';

    test('are used on an ANSI terminal', () async {
      final result = await run(['doctor', app], ansi: true);
      expect(result.out, contains('\x1B['));
    });

    test('respect NO_COLOR', () async {
      final result = await run(
        ['doctor', app],
        ansi: true,
        environment: {'NO_COLOR': '1'},
      );
      expect(result.out, isNot(contains('\x1B[')));
    });

    test('respect --no-color', () async {
      final result = await run(['doctor', app, '--no-color'], ansi: true);
      expect(result.out, isNot(contains('\x1B[')));
    });

    test('are never used in JSON', () async {
      final result = await run(['doctor', app, '--json'], ansi: true);
      expect(result.out, isNot(contains('\x1B[')));
    });
  });
}
