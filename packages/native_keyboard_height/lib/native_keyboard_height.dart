/// Native keyboard height events that fire BEFORE the OS keyboard animation
/// starts, with the final keyboard height.
///
/// This is the Flutter equivalent of Capacitor's `keyboardWillShow` /
/// `keyboardWillHide` events, ported 1:1 from `capacitor-edge-to-edge`.
library native_keyboard_height;

import 'dart:async';
import 'package:flutter/services.dart';

/// The phase of a keyboard visibility change.
enum KeyboardEventType {
  /// Fires **before** the keyboard animation starts (≈ keyboardWillShow).
  /// [KeyboardEvent.height] is the **final** keyboard height.
  willShow,

  /// Fires **after** the keyboard animation completes (≈ keyboardDidShow).
  didShow,

  /// Fires **before** the keyboard hide animation starts (≈ keyboardWillHide).
  willHide,

  /// Fires **after** the keyboard hide animation completes (≈ keyboardDidHide).
  didHide,
}

/// A keyboard visibility event from the native layer.
class KeyboardEvent {
  const KeyboardEvent({
    required this.type,
    required this.height,
  });

  /// The event phase.
  final KeyboardEventType type;

  /// The keyboard height in logical pixels (dp on Android, pt on iOS).
  /// Non-zero for [KeyboardEventType.willShow] and [KeyboardEventType.didShow],
  /// always 0 for hide events.
  final double height;

  /// Whether the keyboard is becoming visible (willShow or didShow).
  bool get visible =>
      type == KeyboardEventType.willShow || type == KeyboardEventType.didShow;

  @override
  String toString() => 'KeyboardEvent($type, height: $height)';
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
///   if (e.type == KeyboardEventType.willShow) {
///     // keyboard about to show, e.height is the final height
///   } else if (e.type == KeyboardEventType.willHide) {
///     // keyboard about to hide
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
        final height = (event['height'] as num?)?.toDouble() ?? 0.0;
        switch (type) {
          case 'willShow':
            return KeyboardEvent(
                type: KeyboardEventType.willShow, height: height);
          case 'didShow':
            return KeyboardEvent(
                type: KeyboardEventType.didShow, height: height);
          case 'willHide':
            return KeyboardEvent(
                type: KeyboardEventType.willHide, height: 0);
          case 'didHide':
            return KeyboardEvent(
                type: KeyboardEventType.didHide, height: 0);
        }
      }
      return KeyboardEvent(type: KeyboardEventType.didHide, height: 0);
    }).asBroadcastStream();
    return _stream!;
  }
}
