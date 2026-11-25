part of 'terminal.dart';

/// Formats the DECRQSS (`DCS $ q`) replies: "what is the current value of
/// this setting?".
///
/// This is a mixin rather than a standalone class because every value it
/// reports is owned elsewhere — the buffer margins, the cursor style, the
/// mode flags, the device settings — so there is no state left for an
/// independent object to hold. The members below are declared abstract here
/// and satisfied structurally by [Terminal]'s own fields of the same name,
/// which is what lets this mixin be typechecked on its own without an `on`
/// clause pointing back at Terminal. The list doubles as the honest
/// dependency footprint of DECRQSS reporting.
mixin _StatusStringReports {
  Buffer get _buffer;

  CursorStyle get _cursorStyle;

  _TerminalModes get _modes;

  _DeviceSettings get _settings;

  Map<int, ({int foreground, int background})> get _assignedColors;

  int get _viewWidth;

  int get _viewHeight;

  String? _statusString(String query) {
    final titleModeStatus = _titleModeStatusString(query);
    if (titleModeStatus != null) return titleModeStatus;

    final colorStatus = _attributeColorStatusString(query);
    if (colorStatus != null) return colorStatus;

    return switch (query) {
      'm' => _sgrStatusString(),
      '>4m' => '>4;${_modes._modifyOtherKeysMode}' 'm',
      '|' => '${_settings.transmitTerminationCharacter}|',
      "'s" => "${_settings.lineTransmitTerminationCharacter}'s",
      '}' => '${_settings.protectedFieldsAttribute}}',
      '"p' =>
        '${_settings.conformanceLevel};${_settings.conformanceControls}"p',
      '"q' => '${switch (_cursorStyle.isProtected) {
          true => 1,
          false => 0,
        }}"q',
      r'$|' => '$_viewWidth\$|',
      r'$}' => '${_settings.activeStatusDisplay}\$}',
      '*x' => '${switch (_settings.attributeChangeExtentRectangular) {
          true => 2,
          false => 0,
        }}*x',
      '*|' => '$_viewHeight*|',
      r'$~' => '${_settings.statusLineType}\$~',
      ' q' => '${_cursorShapeStatus()} q',
      ' r' => '${_settings.keyClickVolume} r',
      ' u' => '${_settings.marginBellVolume} u',
      ' v' => '${_settings.lockKeyStyle} v',
      ' t' => '${_settings.warningBellVolume} t',
      ' ~' => '${_settings.terminalModeEmulation} ~',
      'r' => '${_buffer.marginTop + 1};${_buffer.marginBottom + 1}r',
      's' => _leftRightMarginStatusString(),
      't' => '${_viewHeight}t',
      '+q' ||
      '*}' ||
      '+r' ||
      '-q' ||
      ',z' ||
      '-r' ||
      '*u' ||
      '*r' ||
      ')p' ||
      r'$q' ||
      '*s' ||
      r'$s' ||
      '"t' ||
      '*p' ||
      'p' ||
      ',x' ||
      '+w' ||
      ' p' ||
      '"u' ||
      '-p' ||
      '){' ||
      ',{' ||
      ',y' =>
        '0$query',
      _ => null,
    };
  }

  String? _attributeColorStatusString(String query) {
    if (query.endsWith(',}')) {
      final attribute = int.tryParse(query.substring(0, query.length - 2));
      if (attribute == null || attribute < 0 || attribute > 15) return null;
      final color = _settings.alternateTextColors[attribute];
      return '$attribute;${color?.foreground ?? 0};${color?.background ?? 0},}';
    }

    if (query.endsWith(',|')) {
      final attribute = int.tryParse(query.substring(0, query.length - 2));
      if (attribute == null || attribute < 1 || attribute > 2) return null;
      final color = _assignedColors[attribute];
      return '$attribute;${color?.foreground ?? 0};${color?.background ?? 0},|';
    }

    return null;
  }

  String? _titleModeStatusString(String query) {
    if (!query.startsWith('>') || !query.endsWith('t')) return null;
    final mode = int.tryParse(query.substring(1, query.length - 1));
    if (mode == null || mode < 0 || mode > 3) return null;
    final enabled = switch (_settings.titleModes.contains(mode)) {
      true => 1,
      false => 0,
    };
    return '>$mode;${enabled}t';
  }

  String? _leftRightMarginStatusString() {
    if (!_modes._leftRightMarginMode) return null;
    return '${_buffer.marginLeft + 1};${_buffer.marginRight + 1}s';
  }

  int _cursorShapeStatus() {
    return switch ((_modes._applicationCursorType, _modes._cursorBlinkMode)) {
      (TerminalCursorType.block || null, true) => 1,
      (TerminalCursorType.block || null, false) => 2,
      (TerminalCursorType.underline, true) => 3,
      (TerminalCursorType.underline, false) => 4,
      (TerminalCursorType.verticalBar, true) => 5,
      (TerminalCursorType.verticalBar, false) => 6,
    };
  }

  /// Formats the current cursor attributes as the DECRQSS reply to `SGR`.
  String _sgrStatusString() {
    final attributes = <int>[0];
    if (_cursorStyle.isBold) attributes.add(1);
    if (_cursorStyle.isFaint) attributes.add(2);
    if (_cursorStyle.isItalic) attributes.add(3);
    if (_cursorStyle.isUnderline) attributes.add(4);
    if (_cursorStyle.isBlink) attributes.add(5);
    if (_cursorStyle.isInverse) attributes.add(7);
    if (_cursorStyle.isInvisible) attributes.add(8);
    if (_cursorStyle.attrs & CellAttr.strikethrough != 0) attributes.add(9);
    if (_cursorStyle.isDoubleUnderline) attributes.add(21);
    if (_cursorStyle.isFramed) attributes.add(51);
    if (_cursorStyle.isEncircled) attributes.add(52);
    if (_cursorStyle.isOverline) attributes.add(53);
    _appendSgrColor(attributes, _cursorStyle.foreground, 30, 90, 38);
    _appendSgrColor(attributes, _cursorStyle.background, 40, 100, 48);
    _appendSgrColor(attributes, _cursorStyle.underlineColor, 0, 0, 58);
    return '${attributes.join(';')}m';
  }

  void _appendSgrColor(
    List<int> attributes,
    int color,
    int namedBase,
    int brightBase,
    int extendedPrefix,
  ) {
    final type = color & CellColor.typeMask;
    final value = color & CellColor.valueMask;
    switch (type) {
      case CellColor.named:
        if (extendedPrefix == 58) {
          attributes.addAll([58, 5, value]);
          return;
        }
        if (value < 8) {
          attributes.add(namedBase + value);
          return;
        }
        attributes.add(brightBase + value - 8);
        return;
      case CellColor.palette:
        attributes.addAll([extendedPrefix, 5, value]);
        return;
      case CellColor.rgb:
        attributes.addAll([
          extendedPrefix,
          2,
          (value >> 16) & 0xFF,
          (value >> 8) & 0xFF,
          value & 0xFF,
        ]);
    }
  }
}
