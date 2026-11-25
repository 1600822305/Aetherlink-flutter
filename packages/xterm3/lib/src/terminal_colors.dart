part of 'terminal.dart';

/// Holds the indexed/special/dynamic color overrides set through OSC 4, OSC
/// 5, and OSC 10-19-family sequences, plus the revision counter that lets
/// consumers cheaply detect when any of them changed.
///
/// This does not include [Terminal._assignedColors] or
/// [Terminal._alternateTextColors] (DEC "assign color"/"alternate text
/// color" attributes) - those are a distinct, unrelated mechanism and stay
/// on [Terminal].
class _ColorRegistry {
  final Map<int, int> _indexedColorOverrides = {};
  final Map<int, int> _specialColorOverrides = {};
  final Map<int, int> _auxiliaryDynamicColorOverrides = {};

  int? _foregroundColorOverride;

  int? _backgroundColorOverride;

  int? _cursorColorOverride;

  int? _selectionColorOverride;

  int? _selectionForegroundColorOverride;

  int _colorRevision = 0;
}
