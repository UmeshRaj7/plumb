import '../checks/doctor_report.dart';
import '../checks/finding.dart';

/// Renders [report] for humans (ARCHITECTURE.md §9).
///
/// Conditional, manual and "can't verify" items of a package are counted on
/// one line unless [verbose]; everything else is always listed. [color]
/// adds ANSI colors.
String renderText(
  DoctorReport report, {
  bool color = false,
  bool verbose = false,
}) {
  final style = _Style(color);
  final out = StringBuffer()
    ..writeln(style.bold('plumb doctor · ${report.projectName}'))
    ..writeln(_intro(report));

  final appFindings = report.findings.where((f) => f.package == null).toList();
  if (appFindings.isNotEmpty) {
    _writeSection(out, style, 'Your app', appFindings, verbose: true);
  }
  for (final package in report.packages) {
    final version = package.version?.toString() ?? '(version unknown)';
    _writeSection(
      out,
      style,
      '${package.name} $version',
      report.findings.where((f) => f.package == package.name).toList(),
      verbose: verbose,
    );
  }

  out
    ..writeln()
    ..writeln(_summary(report.summary));
  return out.toString();
}

String _intro(DoctorReport report) {
  final source = report.dependencySource.label;
  return switch (report.packages.length) {
    0 => 'None of your dependencies has a bundled recipe (read from $source).',
    1 => 'Found 1 plugin with a recipe (read from $source).',
    final n => 'Found $n plugins with recipes (read from $source).',
  };
}

/// Conditional/manual items of a package are collapsed by default; notes
/// about the package itself (e.g. "version not covered") are not.
bool _collapsible(Finding f) =>
    f.severity == Severity.info && f.package != null && f.key != null;

void _writeSection(
  StringBuffer out,
  _Style style,
  String title,
  List<Finding> findings, {
  required bool verbose,
}) {
  final shown = verbose
      ? findings
      : findings.where((f) => !_collapsible(f)).toList();
  final hidden = findings.length - shown.length;

  out
    ..writeln()
    ..writeln(style.bold(title));
  final fileWidth = shown.fold(
    0,
    (w, f) => _fileLabel(f).length > w ? _fileLabel(f).length : w,
  );
  for (final finding in shown) {
    final symbol = style.symbol(finding.severity);
    final String indent;
    if (finding.platform == null && finding.file == null) {
      // Notes about a package as a whole have no columns to align.
      indent = '    ';
      out.writeln('  $symbol ${finding.message}');
    } else {
      final platform = (finding.platform?.name ?? '').padRight(7);
      final file = _fileLabel(finding).padRight(fileWidth);
      indent = ' ' * (4 + 7 + 2 + fileWidth + 2);
      out.writeln('  $symbol $platform  $file  ${finding.message}');
    }
    if (finding.severity != Severity.ok) {
      if (finding.fix != null) out.writeln('${indent}fix:  ${finding.fix}');
      if (finding.source != null) {
        out.writeln('${indent}docs: ${finding.source}');
      }
    }
  }
  if (hidden > 0) {
    final items = hidden == 1 ? 'item' : 'items';
    out.writeln(
      '  ${style.symbol(Severity.info)} $hidden conditional or manual $items (run with --verbose to list)',
    );
  }
}

/// The file name shown in the file column (full path when it's a directory
/// or pattern, so it stays meaningful).
String _fileLabel(Finding finding) {
  final file = finding.file;
  if (file == null) return '';
  if (file.endsWith('/') || file.contains('*') || !file.contains('/')) {
    return file;
  }
  return file.split('/').last;
}

String _summary(Map<Severity, int> counts) {
  final parts = [
    if (counts[Severity.error]! > 0) '${counts[Severity.error]} error',
    '${counts[Severity.ok]} ok',
    '${counts[Severity.missing]} missing',
    '${counts[Severity.warning]} warning',
    '${counts[Severity.info]} info',
  ];
  return 'Summary: ${parts.join(' · ')}';
}

class _Style {
  _Style(this.enabled);

  final bool enabled;

  String bold(String text) => _wrap('1', text);

  String symbol(Severity severity) => switch (severity) {
    Severity.error || Severity.missing => _wrap('31', '✗'),
    Severity.warning => _wrap('33', '⚠'),
    Severity.ok => _wrap('32', '✓'),
    Severity.info => _wrap('36', 'ℹ'),
  };

  String _wrap(String code, String text) =>
      enabled ? '\x1B[${code}m$text\x1B[0m' : text;
}
