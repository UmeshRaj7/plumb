import '../checks/doctor_report.dart';
import '../checks/finding.dart';

/// Renders [report] for humans, grouped by package.
///
/// Conditional, manual and "can't verify" items of a package, and findings
/// the app ignores, are counted on one line unless [verbose]; everything
/// else is always listed. [verbose] also shows finding ids (for
/// `plumb: ignore:`). [color] adds ANSI colors.
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
    _writeSection(
      out,
      style,
      'Your app',
      appFindings,
      verbose: verbose,
      collapse: false,
    );
  }
  for (final package in report.packages) {
    final version = package.version?.toString() ?? '(version unknown)';
    _writeSection(
      out,
      style,
      '${package.name} $version',
      report.findings.where((f) => f.package == package.name).toList(),
      verbose: verbose,
      collapse: !verbose,
    );
  }

  out
    ..writeln()
    ..writeln(_summary(report.summary, report.ignoredCount));
  return out.toString();
}

String _intro(DoctorReport report) {
  final source = report.dependencySource.label;
  final found = switch (report.packages.length) {
    0 => 'None of your dependencies has a bundled recipe (read from $source).',
    1 => 'Found 1 plugin with a recipe (read from $source).',
    final n => 'Found $n plugins with recipes (read from $source).',
  };
  final known = report.recipePackageCount;
  if (known == null) return found;
  return '$found\nplumb has recipes for $known plugins so far; others aren\'t checked.';
}

/// Conditional/manual items of a package are collapsed by default; notes
/// about the package itself (e.g. "version not covered") are not.
bool _collapsible(Finding f) =>
    f.severity == Severity.info && f.package != null && f.key != null;

/// Writes one section. Unless [verbose], ignored findings are only counted,
/// and so are collapsible ones when [collapse].
void _writeSection(
  StringBuffer out,
  _Style style,
  String title,
  List<Finding> findings, {
  required bool verbose,
  required bool collapse,
}) {
  final shown = [
    for (final f in findings)
      if (verbose ||
          (f.ignoredReason == null && !(collapse && _collapsible(f))))
        f,
  ];
  final hidden = findings.where((f) => !shown.contains(f)).toList();

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
    if (finding.alsoNeededBy.isNotEmpty) {
      out.writeln('${indent}also: ${finding.alsoNeededBy.join(', ')}');
    }
    if (finding.severity != Severity.ok) {
      if (finding.fix != null) out.writeln('${indent}fix:  ${finding.fix}');
      if (finding.source != null) {
        out.writeln('${indent}docs: ${finding.source}');
      }
      if (verbose) out.writeln('${indent}id:   ${finding.id}');
    }
    if (finding.ignoredReason != null) {
      out.writeln('${indent}ignored: ${finding.ignoredReason}');
    }
  }
  if (findings.isEmpty) {
    // Its files were unreadable or its platform directory is missing;
    // the reason is listed under "Your app".
    out.writeln('  No results (see "Your app" above).');
  }
  if (hidden.isNotEmpty) {
    out.writeln(
      '  ${style.symbol(Severity.info)} ${_hiddenSummary(hidden)} '
      '(run with --verbose to list)',
    );
  }
}

/// "1 ignored, 2 conditional items and 1 manual step" for the hidden findings.
String _hiddenSummary(List<Finding> hidden) {
  final ignored = hidden.where((f) => f.ignoredReason != null).length;
  final manual = hidden
      .where((f) => f.ignoredReason == null && f.file == null)
      .length;
  final conditional = hidden.length - ignored - manual;
  String count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
  final parts = [
    if (ignored > 0) '$ignored ignored',
    if (conditional > 0) count(conditional, 'conditional item'),
    if (manual > 0) count(manual, 'manual step'),
  ];
  if (parts.length < 2) return parts.join();
  return '${parts.take(parts.length - 1).join(', ')} and ${parts.last}';
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

String _summary(Map<Severity, int> counts, int ignored) {
  final parts = [
    if (counts[Severity.error]! > 0) '${counts[Severity.error]} error',
    '${counts[Severity.ok]} ok',
    '${counts[Severity.missing]} missing',
    '${counts[Severity.warning]} warning',
    '${counts[Severity.info]} info',
    if (ignored > 0) '$ignored ignored',
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
