import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:xterm3/zmodem.dart';

void main() {
  test('garbage after the ZModem magic does not lock the session', () async {
    final stdout = StreamController<Uint8List>();
    final stdin = StreamController<List<int>>();
    final written = <String>[];
    stdin.stream.listen((data) => written.add(utf8.decode(data)));
    final got = <String>[];
    final mux = ZModemMux(stdin: stdin.sink, stdout: stdout.stream);
    mux.onTerminalInput = got.add;

    Future<void> feed(String text) async {
      stdout.add(Uint8List.fromList(utf8.encode(text)));
      await Future<void>.delayed(Duration.zero);
    }

    await feed('before ');
    await feed('**\x18B0100000 just some text\r\n');
    await feed('prompt\$ ');
    mux.terminalWrite('ls\r');
    await Future<void>.delayed(Duration.zero);

    expect(got.join(), 'before **\x18B0100000 just some text\r\nprompt\$ ');
    expect(written, ['ls\r']);
  });

  test('listIndexOf finds a match at the very end', () {
    expect([1, 2, 3].listIndexOf([2, 3]), 1);
    expect([1, 2, 3].listIndexOf([1, 2, 3]), 0);
    expect([1, 2, 3].listIndexOf([3, 4]), isNull);
  });
}
