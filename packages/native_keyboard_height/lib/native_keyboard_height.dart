/// Native keyboard height events that fire BEFORE the OS keyboard animation
/// starts, with the final keyboard height.
///
/// This is the Flutter equivalent of Capacitor's `keyboardWillShow` /
/// `keyboardWillHide` events.
library native_keyboard_height;

import 'dart:async';
import 'package:flutter/services.dart';

/// A keyboard visibility event from the native layer.
class KeyboardEvent {
  const KeyboardEvent.show(this.height) : visible = true;
  const KeyboardEvent.hide()
      : visible = false,
        height = 0;

  /// Whether the keyboard is visible.
  final bool visible;

  /// The keyboard height in logical pixels (dp on Android, pt on iOS).
  /// Always 0 when [visible] is false.
  final double height;

  @override
  String toString() =>
      'KeyboardEvent(visible: $visible, height: $height)';
}

/// Singleton that streams native keyboard show/hide events.
///
/// Unlike `MediaQuery.viewInsetsOf`, these events fire once with the **final**
/// keyboard height before the OS animation begins — matching Capacitor's
/// `keyboardWillShow` / `keyboardWillHide`.
///
/// Usage:
/// ```dart
/// final sub = NativeKeyboardHeight.instance.events.listen((e) {
///   if (e.visible) {
///     // keyboard showing, e.height is the final height
///   } else {
///     // keyboard hidden
///   }
/// });
/// ```
class NativeKeyboardHeight {
  NativeKeyboardHeight._();

  static final NativeKeyboardHeight instance = NativeKeyboardHeight._();

  static const EventChannel _channel =
      EventChannel('com.example.native_keyboard_height/events');

  Stream<KeyboardEvent>? _stream;

  /// A broadcast stream of keyboard events. The stream is created lazily on
  /// first access and shared across all listeners.
  Stream<KeyboardEvent> get events {
    _stream ??= _channel.receiveBroadcastStream().map((dynamic event) {
      if (event is Map) {
        final type = event['type'] as String?;
        if (type == 'show') {
          final height = (event['height'] as num?)?.toDouble() ?? 0.0;
          return KeyboardEvent.show(height);
        }
      }
      return const KeyboardEvent.hide();
    }).asBroadcastStream();
    return _stream!;
  }
}
