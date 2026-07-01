import 'package:flutter/material.dart';

/// Wraps [child] with the draggable developer-tools entry button when [enabled].
///
/// Drop this in `MaterialApp.builder` (alongside `PerfOverlayHost`) so the button
/// floats above every route. When disabled it returns [child] untouched (zero
/// overhead). [onPressed] is supplied by the host (it navigates to / away from
/// the DevTools page) so the package stays free of any router dependency.
///
/// [active] flips the button to its green "on the DevTools page" state, and
/// [initialPosition] / [onPositionChanged] let the host persist the dragged
/// position (the package stays free of any storage dependency).
class DevToolsFloatingButtonHost extends StatelessWidget {
  const DevToolsFloatingButtonHost({
    super.key,
    required this.child,
    required this.enabled,
    required this.onPressed,
    this.active = false,
    this.initialPosition,
    this.onPositionChanged,
  });

  final Widget child;
  final bool enabled;
  final VoidCallback onPressed;
  final bool active;
  final Offset? initialPosition;
  final ValueChanged<Offset>? onPositionChanged;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.expand,
      children: [
        child,
        DevToolsFloatingButton(
          onPressed: onPressed,
          active: active,
          initialPosition: initialPosition,
          onPositionChanged: onPositionChanged,
        ),
      ],
    );
  }
}

/// A 48px round, draggable button (Terminal glyph) that opens the DevTools page.
/// Visual language mirrors the original web `DevToolsFloatingButton`: a blue
/// translucent circle that turns green while the DevTools page is open
/// ([active]). Drag to move; tap to open/close.
///
/// The dragged offset is kept in local state for smooth panning and reported to
/// the host via [onPositionChanged] on release; [initialPosition] seeds it (e.g.
/// from a persisted value that hydrates asynchronously), matching the web's
/// `localStorage` position.
class DevToolsFloatingButton extends StatefulWidget {
  const DevToolsFloatingButton({
    super.key,
    required this.onPressed,
    this.active = false,
    this.initialPosition,
    this.onPositionChanged,
  });

  final VoidCallback onPressed;
  final bool active;
  final Offset? initialPosition;
  final ValueChanged<Offset>? onPositionChanged;

  @override
  State<DevToolsFloatingButton> createState() => _DevToolsFloatingButtonState();
}

class _DevToolsFloatingButtonState extends State<DevToolsFloatingButton> {
  // Defaults just below the perf overlay's start (12, 80) so they don't overlap.
  static const Offset _defaultPosition = Offset(12, 140);

  static const double _size = 48;

  late Offset _position;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition ?? _defaultPosition;
  }

  @override
  void didUpdateWidget(covariant DevToolsFloatingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Adopt a newly-hydrated persisted position (only when idle and it actually
    // changed) so the async-loaded value lands without fighting a live drag.
    final incoming = widget.initialPosition;
    if (!_dragging && incoming != null && incoming != oldWidget.initialPosition) {
      _position = incoming;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxX = media.size.width - _size;
    final maxY = media.size.height - _size;
    final left = _position.dx.clamp(0.0, maxX > 0 ? maxX : 0.0);
    final top = _position.dy.clamp(media.padding.top, maxY > 0 ? maxY : 0.0);

    // Blue normally, green while the DevTools page is open (mirrors the web).
    final color = widget.active
        ? const Color(0xE64CAF50) // green, ~0.9 alpha
        : const Color(0xE62196F3); // blue, ~0.9 alpha

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _dragging = true,
        onPanUpdate: (d) => setState(() => _position += d.delta),
        onPanEnd: (_) {
          _dragging = false;
          widget.onPositionChanged?.call(_position);
        },
        onTap: widget.onPressed,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x33FFFFFF)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.terminal, size: 24, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
