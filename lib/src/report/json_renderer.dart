import 'dart:convert';

import '../checks/doctor_report.dart';
import '../version.dart';

/// The JSON output format version. Additive changes only; a breaking change
/// bumps it.
const jsonFormatVersion = 1;

/// Renders [report] as JSON for CI and AI agents.
///
/// Every key is always present (null when not applicable), and the output
/// has no absolute paths or timestamps, so it is stable across machines.
String renderJson(DoctorReport report) {
  final document = {
    'format': jsonFormatVersion,
    'plumb_version': packageVersion,
    'project': {
      'name': report.projectName,
      'dependency_source': report.dependencySource.label,
    },
    'packages': [
      for (final package in report.packages)
        {
          'name': package.name,
          'version': package.version?.toString(),
          'status': switch (package.status) {
            PackageStatus.checked => 'checked',
            PackageStatus.versionNotCovered => 'version_not_covered',
            PackageStatus.versionUnknown => 'version_unknown',
          },
          'recipe': package.recipe,
        },
    ],
    'findings': [
      for (final finding in report.findings)
        {
          'id': finding.id,
          'severity': finding.severity.name,
          'package': finding.package,
          'platform': finding.platform?.name,
          'file': finding.file,
          'key': finding.key,
          'message': finding.message,
          'fix': finding.fix,
          'source': finding.source,
          'also_needed_by': finding.alsoNeededBy,
          'ignored': finding.ignoredReason,
        },
    ],
    'summary': {
      for (final MapEntry(:key, :value) in report.summary.entries)
        key.name: value,
      'ignored': report.ignoredCount,
    },
  };
  return '${const JsonEncoder.withIndent('  ').convert(document)}\n';
}

/// Renders a setup error (e.g. "not a Flutter app") as JSON, so `--json`
/// callers always get JSON on stdout.
String renderJsonError(String message) =>
    '${const JsonEncoder.withIndent('  ').convert({'format': jsonFormatVersion, 'plumb_version': packageVersion, 'error': message})}\n';
