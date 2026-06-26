// Error codes raised as PlatformException.code (spec §3.2).

/// Error codes raised as `PlatformException.code` from the native side
/// (spec §3.2). Kept as constants instead of an enum so callers can
/// switch on `PlatformException.code` directly without parsing.
abstract final class AetherlinkSafErrorCode {
  static const String noPermission = 'E_NO_PERMISSION';
  static const String uriStale = 'E_URI_STALE';
  static const String notFound = 'E_NOT_FOUND';
  static const String invalidArg = 'E_INVALID_ARG';
  static const String io = 'E_IO';
  static const String outOfSpace = 'E_OUT_OF_SPACE';
  static const String tooLarge = 'E_TOO_LARGE';
  static const String rangeConflict = 'E_RANGE_CONFLICT';
  static const String notSupported = 'E_NOT_SUPPORTED';
  static const String userCancelled = 'E_USER_CANCELLED';
}
