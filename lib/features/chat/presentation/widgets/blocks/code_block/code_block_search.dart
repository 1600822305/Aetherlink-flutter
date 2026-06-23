import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Search bar overlay for code blocks.
class CodeBlockSearchBar extends StatefulWidget {
  const CodeBlockSearchBar({
    required this.code,
    required this.onChanged,
    required this.onClose,
    required this.labelColor,
    super.key,
  });

  final String code;
  final void Function(String query, int matchCount, int currentIndex) onChanged;
  final VoidCallback onClose;
  final Color labelColor;

  @override
  State<CodeBlockSearchBar> createState() => CodeBlockSearchBarState();
}

class CodeBlockSearchBarState extends State<CodeBlockSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<int> _matchPositions = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _search(String query) {
    _matchPositions = [];
    _currentIndex = 0;
    if (query.isNotEmpty) {
      final lower = widget.code.toLowerCase();
      final lowerQuery = query.toLowerCase();
      var start = 0;
      while (true) {
        final idx = lower.indexOf(lowerQuery, start);
        if (idx == -1) break;
        _matchPositions.add(idx);
        start = idx + 1;
      }
    }
    setState(() {});
    widget.onChanged(
      _controller.text,
      _matchPositions.length,
      _currentIndex,
    );
  }

  void _next() {
    if (_matchPositions.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _matchPositions.length;
    });
    widget.onChanged(
      _controller.text,
      _matchPositions.length,
      _currentIndex,
    );
  }

  void _prev() {
    if (_matchPositions.isEmpty) return;
    setState(() {
      _currentIndex =
          (_currentIndex - 1 + _matchPositions.length) % _matchPositions.length;
    });
    widget.onChanged(
      _controller.text,
      _matchPositions.length,
      _currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: bg),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _search,
              style: TextStyle(fontSize: 13, color: widget.labelColor),
              decoration: InputDecoration(
                hintText: '搜索代码...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: widget.labelColor.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _matchPositions.isEmpty
                    ? '0/0'
                    : '${_currentIndex + 1}/${_matchPositions.length}',
                style: TextStyle(fontSize: 11, color: widget.labelColor),
              ),
            ),
          _SearchIconButton(
            icon: LucideIcons.chevronUp,
            onTap: _prev,
            color: widget.labelColor,
          ),
          _SearchIconButton(
            icon: LucideIcons.chevronDown,
            onTap: _next,
            color: widget.labelColor,
          ),
          _SearchIconButton(
            icon: LucideIcons.x,
            onTap: widget.onClose,
            color: widget.labelColor,
          ),
        ],
      ),
    );
  }
}

class _SearchIconButton extends StatelessWidget {
  const _SearchIconButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}
