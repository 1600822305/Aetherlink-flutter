/// Native keyboard height events that fire BEFORE the OS keyboard animation
/// starts, with the final keyboard height.
///
/// This is the Flutter equivalent of Capacitor's `keyboardWillShow` /
/// `keyboardWillHide` events, ported 1:1 from `capacitor-edge-to-edge`.
library;

import 'dart:async';
import 'package:flutter/services.dart';

/// The phase of a keyboard visibility change.
enum KeyboardEventType {
  /// Fires **before** the keyboard animation starts (≈ keyboardWillShow).
  /// [KeyboardEvent.height] is the **final** keyboard height.
  willShow,

  /// Fires every animation frame with the interpolated IME height —
  /// frame-synced with the OS keyboard animation, so layout can track the
  /// IME's top edge exactly (WeChat/QQ-style pan).
  progress,

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
    this.imeDp,
    this.navDp,
  });

  /// The event phase.
  final KeyboardEventType type;

  /// Diagnostics: the raw IME inset in dp as read natively (before the
  /// nav-bar subtraction), when the native layer attached it.
  final double? imeDp;

  /// Diagnostics: the navigation-bar inset in dp as read natively.
  final double? navDp;

  /// The keyboard height in logical pixels (dp on Android, pt on iOS).
  /// The final height for [KeyboardEventType.willShow] / [KeyboardEventType.didShow],
  /// the current interpolated height for [KeyboardEventType.progress],
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
/// The native [EventChannel] subscription is established once and kept alive
/// for the entire app lifetime — subscriber count on the Dart side does not
/// affect the native connection. This prevents missed events during widget
/// dispose/rebuild cycles.
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
  NativeKeyboardHeight._() {
    _startListening();
  }

  static final NativeKeyboardHeight instance = NativeKeyboardHeight._();

  static const EventChannel _channel =
      EventChannel('com.example.native_keyboard_height/events');

  final StreamController<KeyboardEvent> _controller =
      StreamController<KeyboardEvent>.broadcast();

  /// The last keyboard height reported by the native layer (logical pixels).
  /// Useful for reading the current state without waiting for an event.
  double currentHeight = 0;

  /// A broadcast stream of keyboard events. Multiple listeners can subscribe
  /// and unsubscribe freely — the native connection is never interrupted.
  Stream<KeyboardEvent> get events => _controller.stream;

  /// Establishes the persistent native connection. Called once from the
  /// constructor — never cancelled.
  void _startListening() {
    _channel.receiveBroadcastStream().listen(
      (dynamic raw) {
        final event = _parse(raw);
        if (event.type == KeyboardEventType.progress) {
          currentHeight = event.height;
        } else if (event.visible) {
          currentHeight = event.height;
        } else {
          currentHeight = 0;
        }
        _controller.add(event);
      },
      onError: (Object error) {
        // Platform channel errors should not kill the subscription.
        // ignore and keep listening.
      },
      cancelOnError: false,
    );
  }

  static KeyboardEvent _parse(dynamic raw) {
    if (raw is Map) {
      final type = raw['type'] as String?;
      final height = (raw['height'] as num?)?.toDouble() ?? 0.0;
      final imeDp = (raw['imeDp'] as num?)?.toDouble();
      final navDp = (raw['navDp'] as num?)?.toDouble();
      switch (type) {
        case 'willShow':
          return KeyboardEvent(
            type: KeyboardEventType.willShow,
            height: height,
            imeDp: imeDp,
            navDp: navDp,
          );
        case 'progress':
          return KeyboardEvent(
            type: KeyboardEventType.progress,
            height: height,
            imeDp: imeDp,
            navDp: navDp,
          );
        case 'didShow':
          return KeyboardEvent(
            type: KeyboardEventType.didShow,
            height: height,
            imeDp: imeDp,
            navDp: navDp,
          );
        case 'willHide':
          return const KeyboardEvent(
            type: KeyboardEventType.willHide,
            height: 0,
          );
        case 'didHide':
          return const KeyboardEvent(
            type: KeyboardEventType.didHide,
            height: 0,
          );
      }
    }
    return const KeyboardEvent(type: KeyboardEventType.didHide, height: 0);
  }
}
