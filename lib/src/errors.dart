/// A problem the user can fix, such as running plumb outside a Flutter app.
///
/// The [message] is shown to the user verbatim, so it should say what went
/// wrong and what to do about it.
class PlumbException implements Exception {
  /// Creates an exception with a user-facing [message].
  const PlumbException(this.message);

  /// User-facing explanation, including what to do next.
  final String message;

  @override
  String toString() => message;
}
