import 'package:flutter/material.dart';

/// A [SelectionArea] for chat message bodies (正文 / 思考过程) that supports
/// clearing its selection when the user taps elsewhere on the chat page.
///
/// Each message block wraps its content in its own small [SelectionArea], so a
/// tap on another bubble or on blank space never reaches the area that holds
/// the selection and the highlight would otherwise linger. Every mounted
/// [MessageSelectionArea] registers itself in a static set; the chat page
/// listens for pointer-downs ([MessageSelectionArea.clearOutside]) and unfocuses
/// any area whose bounds don't contain the tap — [SelectionArea] clears its
/// selection when its focus node loses focus.
class MessageSelectionArea extends StatefulWidget {
  const MessageSelectionArea({required this.child, super.key});

  final Widget child;

  static final Set<_MessageSelectionAreaState> _mounted =
      <_MessageSelectionAreaState>{};

  /// Clears the selection of every [MessageSelectionArea] whose bounds do not
  /// contain [globalPosition] (a tap inside the area is handled by the area's
  /// own gestures and must not be interfered with).
  static void clearOutside(Offset globalPosition) {
    for (final state in _mounted) {
      state._clearIfOutside(globalPosition);
    }
  }

  @override
  State<MessageSelectionArea> createState() => _MessageSelectionAreaState();
}

class _MessageSelectionAreaState extends State<MessageSelectionArea> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'MessageSelectionArea');

  @override
  void initState() {
    super.initState();
    MessageSelectionArea._mounted.add(this);
  }

  @override
  void dispose() {
    MessageSelectionArea._mounted.remove(this);
    _focusNode.dispose();
    super.dispose();
  }

  void _clearIfOutside(Offset globalPosition) {
    // Only an area that holds a selection has focus (SelectableRegion requests
    // focus when a selection starts); skip the rest.
    if (!_focusNode.hasFocus) return;
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final local = box.globalToLocal(globalPosition);
      if ((Offset.zero & box.size).contains(local)) return;
    }
    // Losing focus makes the SelectionArea clear its selection.
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(focusNode: _focusNode, child: widget.child);
  }
}
