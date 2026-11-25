part of 'terminal.dart';

enum TerminalContextSignalAction {
  start,
  end,
}

enum TerminalContextType {
  boot,
  container,
  vm,
  elevate,
  chpriv,
  subcontext,
  remote,
  shell,
  command,
  app,
  service,
  session,
}

enum TerminalContextExitStatus {
  success,
  failure,
  crash,
  interrupt,
}

/// A hierarchical context update reported through OSC 3008.
final class TerminalContextSignal {
  TerminalContextSignal._({
    required this.action,
    required this.id,
    required Iterable<String> metadataFields,
  }) : _metadataFields = List.unmodifiable(metadataFields);

  final TerminalContextSignalAction action;

  /// The printable ASCII context identifier.
  final String id;

  /// All well-formed metadata fields, including fields unknown to xterm3.
  Map<String, String> get metadata {
    final existing = _metadata;
    if (existing != null) return existing;

    final result = <String, String>{};
    for (final field in _metadataFields) {
      final separator = field.indexOf('=');
      if (separator <= 0) continue;
      final key = field.substring(0, separator);
      if (result.containsKey(key)) continue;
      result[key] = field.substring(separator + 1);
    }
    return _metadata = Map.unmodifiable(result);
  }

  final List<String> _metadataFields;
  Map<String, String>? _metadata;

  TerminalContextType? get type => switch (_value('type')) {
        'boot' => TerminalContextType.boot,
        'container' => TerminalContextType.container,
        'vm' => TerminalContextType.vm,
        'elevate' => TerminalContextType.elevate,
        'chpriv' => TerminalContextType.chpriv,
        'subcontext' => TerminalContextType.subcontext,
        'remote' => TerminalContextType.remote,
        'shell' => TerminalContextType.shell,
        'command' => TerminalContextType.command,
        'app' => TerminalContextType.app,
        'service' => TerminalContextType.service,
        'session' => TerminalContextType.session,
        _ => null,
      };

  String? get user => _value('user');

  String? get hostname => _value('hostname');

  String? get machineId => _value('machineid');

  String? get bootId => _value('bootid');

  int? get pid => _unsignedValue('pid');

  int? get pidfdId => _unsignedValue('pidfdid');

  String? get command => _value('comm');

  String? get currentDirectory => _value('cwd');

  String? get commandLine => _value('cmdline');

  String? get virtualMachine => _value('vm');

  String? get container => _value('container');

  String? get targetUser => _value('targetuser');

  String? get targetHost => _value('targethost');

  String? get sessionId => _value('sessionid');

  TerminalContextExitStatus? get exitStatus => switch (_value('exit')) {
        'success' => TerminalContextExitStatus.success,
        'failure' => TerminalContextExitStatus.failure,
        'crash' => TerminalContextExitStatus.crash,
        'interrupt' => TerminalContextExitStatus.interrupt,
        _ => null,
      };

  int? get status => _unsignedValue('status');

  String? get signal => _value('signal');

  String? _value(String key) {
    for (final field in _metadataFields) {
      if (!field.startsWith(key)) continue;
      if (field.length <= key.length || field.codeUnitAt(key.length) != 0x3d) {
        continue;
      }
      final value = field.substring(key.length + 1);
      if (value.isEmpty) return null;
      return value;
    }
    return null;
  }

  int? _unsignedValue(String key) {
    final value = _value(key);
    if (value == null) return null;
    for (final codeUnit in value.codeUnits) {
      if (codeUnit < 0x30 || codeUnit > 0x39) return null;
    }
    return int.tryParse(value);
  }
}

/// Decodes the OSC 3008 context-signal family into [TerminalContextSignal]s.
///
/// This is a mixin rather than a standalone class because the decoder has no
/// state of its own: it reads the consumer-supplied [onContextSignal] callback
/// and feeds the `cwd` field back through [setCurrentDirectory], both of which
/// are inherently [Terminal]-scoped. The two members below are declared
/// abstract here and satisfied structurally by [Terminal]'s own field/method
/// of the same name, which is what lets this mixin be typechecked on its own
/// without an `on` clause pointing back at Terminal.
mixin _ContextSignalHandlers {
  void Function(TerminalContextSignal signal)? get onContextSignal;

  void setCurrentDirectory(String uri);

  void _handleContextSignalOsc(String ps, List<String> pt) {
    if (ps != '3008' || pt.isEmpty) return;
    final actionField = pt.first;
    final action = switch (actionField) {
      final value when value.startsWith('start=') =>
        TerminalContextSignalAction.start,
      final value when value.startsWith('end=') =>
        TerminalContextSignalAction.end,
      _ => null,
    };
    if (action == null) return;

    final contextId = actionField.substring(
      switch (action) {
        TerminalContextSignalAction.start => 6,
        TerminalContextSignalAction.end => 4,
      },
    );
    if (!_isValidContextSignalId(contextId)) return;

    final callback = onContextSignal;
    if (callback == null) {
      if (action != TerminalContextSignalAction.start) return;
      final currentDirectory = _contextSignalValue(pt, 'cwd');
      if (currentDirectory != null) {
        setCurrentDirectory(currentDirectory);
      }
      return;
    }

    final signal = TerminalContextSignal._(
      action: action,
      id: contextId,
      metadataFields: pt.skip(1),
    );
    if (action == TerminalContextSignalAction.start) {
      final currentDirectory = signal.currentDirectory;
      if (currentDirectory != null) {
        setCurrentDirectory(currentDirectory);
      }
    }

    callback(signal);
  }
}

bool _isValidContextSignalId(String value) {
  if (value.isEmpty || value.length > 64) return false;
  for (final codeUnit in value.codeUnits) {
    if (codeUnit < 0x20 || codeUnit > 0x7e) return false;
  }
  return true;
}

String? _contextSignalValue(List<String> pt, String key) {
  for (var index = 1; index < pt.length; index++) {
    final part = pt[index];
    if (!part.startsWith(key)) continue;
    if (part.length <= key.length || part.codeUnitAt(key.length) != 0x3d) {
      continue;
    }
    final value = part.substring(key.length + 1);
    if (value.isEmpty) return null;
    return value;
  }
  return null;
}
