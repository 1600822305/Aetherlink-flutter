part of 'terminal.dart';

/// The XTGETTCAP (`DCS + q`) terminfo capability table and its hex transport
/// decoding.
///
/// These are library-level functions rather than [Terminal] members because
/// the table is a constant: the only terminal state any entry depends on is
/// the viewport size, which is threaded through as [_terminfoCapability]'s
/// `columns`/`rows` parameters. Keeping a ~250 line lookup table out of
/// [Terminal] is most of what it was contributing to that class's size.

String? _hexDecode(String value) {
  if (value.length.isOdd) return null;
  final buffer = StringBuffer();
  for (var i = 0; i < value.length; i += 2) {
    final digits = value.substring(i, i + 2);
    if (!_isHexDigits(digits)) return null;
    final byte = int.parse(digits, radix: 16);
    buffer.writeCharCode(byte);
  }
  return buffer.toString();
}

String? _terminfoCapability(
  String key, {
  required int columns,
  required int rows,
}) {
  final modifiedFunctionKey = _modifiedFunctionKeyCapability(key);
  if (modifiedFunctionKey != null) return modifiedFunctionKey;

  return switch (key) {
    'TN' => 'xterm-256color',
    'Co' => '256',
    'RGB' => '8',
    'AX' => '1',
    'Tc' => '1',
    'Su' => '1',
    'XT' => '1',
    'fullkbd' => '1',
    'colors' => '256',
    'cols' => columns.toString(),
    'it' => '8',
    'lines' => rows.toString(),
    'pairs' => '32767',
    'acsc' =>
      '++\\,\\,--..00``aaffgghhiijjkkllmmnnooppqqrrssttuuvvwwxxyyzz{{||}}~~',
    'Sync' => '\x1b[?2026%?%p1%{1}%-%tl%eh%;',
    'BD' => '\x1b[?2004l',
    'BE' => '\x1b[?2004h',
    'PS' => '\x1b[200~',
    'PE' => '\x1b[201~',
    'XM' => '\x1b[?1006;1000%?%p1%{1}%=%th%el%;',
    'xm' => '\x1b[<%i%p3%d;%p1%d;%p2%d;%?%p4%tM%em%;',
    'RV' => '\x1b[>c',
    'rv' => '\x1b\\[[0-9]+;[0-9]+;[0-9]+c',
    'XR' => '\x1b[>0q',
    'xr' => '\x1bP>\\|[ -~]+a\x1b\\',
    'Enmg' => '\x1b[?69h',
    'Dsmg' => '\x1b[?69l',
    'Clmg' => '\x1b[s',
    'Cmg' => '\x1b[%i%p1%d;%p2%ds',
    'Ms' => '\x1b]52;%p1%s;%p2%s\x07',
    'Ss' => '\x1b[%p1%d q',
    'Se' => '\x1b[0 q',
    'Smulx' => '\x1b[4:%p1%dm',
    'Setulc' =>
      '\x1b[58:2::%p1%{65536}%/%d:%p1%{256}%/%{255}%&%d:%p1%{255}%&%d%;m',
    'sitm' => '\x1b[3m',
    'ritm' => '\x1b[23m',
    'smxx' => '\x1b[9m',
    'rmxx' => '\x1b[29m',
    'clear' => '\x1b[H\x1b[2J',
    'E3' => '\x1b[3J',
    'fe' => '\x1b[?1004h',
    'fd' => '\x1b[?1004l',
    'kxIN' => '\x1b[I',
    'kxOUT' => '\x1b[O',
    'bel' => '\x07',
    'blink' => '\x1b[5m',
    'bold' => '\x1b[1m',
    'cbt' => '\x1b[Z',
    'civis' => '\x1b[?25l',
    'cnorm' => '\x1b[?12l\x1b[?25h',
    'cr' => '\r',
    'dim' => '\x1b[2m',
    'dsl' => '\x1b]2;\x07',
    'flash' => '\x1b[?5h\$<100/>\x1b[?5l',
    'fsl' => '\x07',
    'home' => '\x1b[H',
    'invis' => '\x1b[8m',
    'rmacs' => '\x1b(B',
    'rmam' => '\x1b[?7l',
    'rmir' => '\x1b[4l',
    'rmkx' => '\x1b[?1l\x1b>',
    'rev' => '\x1b[7m',
    'smacs' => '\x1b(0',
    'smam' => '\x1b[?7h',
    'smir' => '\x1b[4h',
    'smkx' => '\x1b[?1h\x1b=',
    'smul' => '\x1b[4m',
    'rmul' => '\x1b[24m',
    'smso' => '\x1b[7m',
    'rmso' => '\x1b[27m',
    'sgr0' => '\x1b(B\x1b[m',
    'tsl' => '\x1b]2;',
    'op' => '\x1b[39;49m',
    'setaf' =>
      '\x1b[%?%p1%{8}%<%t3%p1%d%e%p1%{16}%<%t9%p1%{8}%-%d%e38;5;%p1%d%;m',
    'setab' =>
      '\x1b[%?%p1%{8}%<%t4%p1%d%e%p1%{16}%<%t10%p1%{8}%-%d%e48;5;%p1%d%;m',
    'setrgbf' => '\x1b[38:2:%p1%d:%p2%d:%p3%dm',
    'setrgbb' => '\x1b[48:2:%p1%d:%p2%d:%p3%dm',
    'cup' => '\x1b[%i%p1%d;%p2%dH',
    'hpa' => '\x1b[%i%p1%dG',
    'vpa' => '\x1b[%i%p1%dd',
    'cuu' => '\x1b[%p1%dA',
    'cuu1' => '\x1b[A',
    'cud' => '\x1b[%p1%dB',
    'cud1' => '\n',
    'cuf' => '\x1b[%p1%dC',
    'cuf1' => '\x1b[C',
    'cub' => '\x1b[%p1%dD',
    'cub1' => '\b',
    'ed' => '\x1b[J',
    'el' => '\x1b[K',
    'el1' => '\x1b[1K',
    'ech' => '\x1b[%p1%dX',
    'ich' => '\x1b[%p1%d@',
    'ich1' => '\x1b[@',
    'dch' => '\x1b[%p1%dP',
    'dch1' => '\x1b[P',
    'il' => '\x1b[%p1%dL',
    'il1' => '\x1b[L',
    'dl' => '\x1b[%p1%dM',
    'dl1' => '\x1b[M',
    'indn' => '\x1b[%p1%dS',
    'rin' => '\x1b[%p1%dT',
    'csr' => '\x1b[%i%p1%d;%p2%dr',
    'tbc' => '\x1b[3g',
    'hts' => '\x1bH',
    'rep' => '%p1%c\x1b[%p2%{1}%-%db',
    'smcup' => '\x1b[?1049h',
    'rmcup' => '\x1b[?1049l',
    'kbs' => '\x7f',
    'kcbt' => '\x1b[Z',
    'kent' => '\x1bOM',
    'khome' => '\x1b[H',
    'kend' => '\x1b[F',
    'kich1' => '\x1b[2~',
    'kdch1' => '\x1b[3~',
    'kpp' => '\x1b[5~',
    'knp' => '\x1b[6~',
    'kcuu1' => '\x1b[A',
    'kcud1' => '\x1b[B',
    'kcuf1' => '\x1b[C',
    'kcub1' => '\x1b[D',
    'kf1' => '\x1bOP',
    'kf2' => '\x1bOQ',
    'kf3' => '\x1bOR',
    'kf4' => '\x1bOS',
    'kf5' => '\x1b[15~',
    'kf6' => '\x1b[17~',
    'kf7' => '\x1b[18~',
    'kf8' => '\x1b[19~',
    'kf9' => '\x1b[20~',
    'kf10' => '\x1b[21~',
    'kf11' => '\x1b[23~',
    'kf12' => '\x1b[24~',
    'u6' => '\x1b[%i%d;%dR',
    'u7' => '\x1b[6n',
    'u8' => '\x1b[?%[;0123456789]c',
    'u9' => '\x1b[c',
    'kUP' || 'kri' => '\x1b[1;2A',
    'kUP3' => '\x1b[1;3A',
    'kUP4' => '\x1b[1;4A',
    'kUP5' => '\x1b[1;5A',
    'kUP6' => '\x1b[1;6A',
    'kUP7' => '\x1b[1;7A',
    'kDN' || 'kind' => '\x1b[1;2B',
    'kDN3' => '\x1b[1;3B',
    'kDN4' => '\x1b[1;4B',
    'kDN5' => '\x1b[1;5B',
    'kDN6' => '\x1b[1;6B',
    'kDN7' => '\x1b[1;7B',
    'kRIT' => '\x1b[1;2C',
    'kRIT3' => '\x1b[1;3C',
    'kRIT4' => '\x1b[1;4C',
    'kRIT5' => '\x1b[1;5C',
    'kRIT6' => '\x1b[1;6C',
    'kRIT7' => '\x1b[1;7C',
    'kLFT' => '\x1b[1;2D',
    'kLFT3' => '\x1b[1;3D',
    'kLFT4' => '\x1b[1;4D',
    'kLFT5' => '\x1b[1;5D',
    'kLFT6' => '\x1b[1;6D',
    'kLFT7' => '\x1b[1;7D',
    'kHOM' => '\x1b[1;2H',
    'kHOM3' => '\x1b[1;3H',
    'kHOM4' => '\x1b[1;4H',
    'kHOM5' => '\x1b[1;5H',
    'kHOM6' => '\x1b[1;6H',
    'kHOM7' => '\x1b[1;7H',
    'kEND' => '\x1b[1;2F',
    'kEND3' => '\x1b[1;3F',
    'kEND4' => '\x1b[1;4F',
    'kEND5' => '\x1b[1;5F',
    'kEND6' => '\x1b[1;6F',
    'kEND7' => '\x1b[1;7F',
    'kIC' => '\x1b[2;2~',
    'kIC3' => '\x1b[2;3~',
    'kIC4' => '\x1b[2;4~',
    'kIC5' => '\x1b[2;5~',
    'kIC6' => '\x1b[2;6~',
    'kIC7' => '\x1b[2;7~',
    'kDC' => '\x1b[3;2~',
    'kDC3' => '\x1b[3;3~',
    'kDC4' => '\x1b[3;4~',
    'kDC5' => '\x1b[3;5~',
    'kDC6' => '\x1b[3;6~',
    'kDC7' => '\x1b[3;7~',
    'kPRV' => '\x1b[5;2~',
    'kPRV3' => '\x1b[5;3~',
    'kPRV4' => '\x1b[5;4~',
    'kPRV5' => '\x1b[5;5~',
    'kPRV6' => '\x1b[5;6~',
    'kPRV7' => '\x1b[5;7~',
    'kNXT' => '\x1b[6;2~',
    'kNXT3' => '\x1b[6;3~',
    'kNXT4' => '\x1b[6;4~',
    'kNXT5' => '\x1b[6;5~',
    'kNXT6' => '\x1b[6;6~',
    'kNXT7' => '\x1b[6;7~',
    _ => null,
  };
}

String? _modifiedFunctionKeyCapability(String key) {
  if (!key.startsWith('kf')) return null;

  final number = int.tryParse(key.substring(2));
  if (number == null) return null;
  if (number < 13 || number > 63) return null;

  final group = switch (number) {
    >= 13 && <= 24 => (offset: number - 13, modifier: 2),
    >= 25 && <= 36 => (offset: number - 25, modifier: 5),
    >= 37 && <= 48 => (offset: number - 37, modifier: 6),
    >= 49 && <= 60 => (offset: number - 49, modifier: 3),
    >= 61 && <= 63 => (offset: number - 61, modifier: 4),
    _ => null,
  };
  if (group == null) return null;

  if (group.offset < 4) {
    final finalByte = switch (group.offset) {
      0 => 'P',
      1 => 'Q',
      2 => 'R',
      3 => 'S',
      _ => null,
    };
    if (finalByte == null) return null;
    return '\x1b[1;${group.modifier}$finalByte';
  }

  final base = switch (group.offset) {
    4 => 15,
    5 => 17,
    6 => 18,
    7 => 19,
    8 => 20,
    9 => 21,
    10 => 23,
    11 => 24,
    _ => null,
  };
  if (base == null) return null;
  return '\x1b[$base;${group.modifier}~';
}
