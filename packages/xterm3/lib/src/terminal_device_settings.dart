part of 'terminal.dart';

/// Terminal settings that are written by an escape sequence and read back
/// only by a report — DECSKCV/DECSMBV/DECSWBV volumes, DECSLCK, DECSTGLT,
/// DECSASD/DECSSDT, DECSCL, DECSPMA, DECTTC/DECSTTC, the DECRARA/DECCARA
/// change extent, the OSC title modes, and the DECAC/DECATC colour tables.
///
/// None of these participate in rendering or in the buffer; they exist so
/// that DECRQSS (and, for the supplemental set, DECRQUPSS) can report the
/// value back to the application. Grouping them here keeps [Terminal] free of
/// a dozen otherwise unrelated scalar fields, and gives the DECRQSS
/// formatting in [_StatusStringReports] a single object to read from.
///
/// The clamping in the mutators is part of the observed behaviour and is
/// preserved exactly: a value that does not survive the clamp is never
/// reported back.
class _DeviceSettings {
  /// DECRARA/DECCARA change extent: rectangular when set, stream otherwise.
  bool attributeChangeExtentRectangular = false;

  int keyClickVolume = 0;

  int marginBellVolume = 0;

  int warningBellVolume = 0;

  int lockKeyStyle = 0;

  int terminalModeEmulation = 0;

  int activeStatusDisplay = 0;

  int statusLineType = 0;

  int conformanceLevel = 61;

  int conformanceControls = 1;

  int protectedFieldsAttribute = 0;

  int transmitTerminationCharacter = 0;

  int lineTransmitTerminationCharacter = 0;

  int preferredSupplementalSetSize = 94;

  String preferredSupplementalSetFinal = '%5';

  /// The OSC title modes (0..3) currently enabled through `CSI > Pm t`.
  final titleModes = <int>{};

  /// DECATC alternate text colours, keyed by attribute (0..15).
  final alternateTextColors = <int, ({int foreground, int background})>{};

  void setKeyClickVolume(int volume) {
    keyClickVolume = volume.clamp(0, 8);
  }

  void setMarginBellVolume(int volume) {
    marginBellVolume = volume.clamp(0, 8);
  }

  void setWarningBellVolume(int volume) {
    warningBellVolume = volume.clamp(0, 8);
  }

  void setActiveStatusDisplay(int display) {
    activeStatusDisplay = display.clamp(0, 1);
  }

  void setStatusLineType(int type) {
    statusLineType = type.clamp(0, 2);
  }

  void setConformanceLevel(int level, int controls) {
    conformanceLevel = level;
    conformanceControls = switch (controls) {
      0 => 1,
      _ => controls,
    };
  }

  void setTitleMode(int mode, bool enabled) {
    if (mode < 0 || mode > 3) return;
    if (enabled) {
      titleModes.add(mode);
      return;
    }
    titleModes.remove(mode);
  }
}
