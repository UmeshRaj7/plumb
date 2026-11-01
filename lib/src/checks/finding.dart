import '../recipes/recipe.dart';

/// How a finding affects the user. Order is display priority.
enum Severity {
  /// plumb couldn't read a file it needs (result is incomplete). ✗
  error,

  /// A required item is absent. ✗
  missing,

  /// Present but a placeholder, wrong type, or only partly set. ⚠
  warning,

  /// Present and valid. ✓
  ok,

  /// Conditional, manual, or can't be verified. Never affects exit codes. ℹ
  info,
}

/// One observation about the project. See ARCHITECTURE.md §5.3.
class Finding {
  /// Creates a finding.
  const Finding({
    required this.id,
    required this.severity,
    required this.message,
    this.package,
    this.platform,
    this.file,
    this.key,
    this.fix,
    this.source,
  });

  /// Builds the finding for [requirement] of [recipe]. The id is stable:
  /// `<package>/<platform>/<section>/<key>`.
  factory Finding.forRequirement(
    Recipe recipe,
    Requirement requirement,
    Severity severity, {
    required String message,
    String? file,
  }) => Finding(
    id: [
      recipe.package,
      requirement.platform.name,
      requirement.kind.section,
      requirement.key,
    ].join('/'),
    severity: severity,
    package: recipe.package,
    platform: requirement.platform,
    file: file,
    key: requirement.key,
    message: message,
    fix: severity == Severity.ok ? null : requirement.hint,
    source: requirement.source ?? recipe.source,
  );

  /// Stable identifier, safe to match on in CI or scripts.
  final String id;

  /// How serious it is.
  final Severity severity;

  /// The plugin package this is about; null for app-level findings.
  final String? package;

  /// iOS or Android; null when not platform-specific.
  final NativePlatform? platform;

  /// Project-relative file the finding is about.
  final String? file;

  /// Plist key, permission name, component name, etc.
  final String? key;

  /// What plumb observed.
  final String message;

  /// What to do about it (from the recipe hint).
  final String? fix;

  /// Documentation URL backing the finding.
  final String? source;
}
