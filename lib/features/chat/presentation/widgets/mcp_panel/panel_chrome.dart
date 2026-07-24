part of 'mcp_quick_panel_dialog.dart';

/// The compact pill switch — a local copy of the settings `CustomSwitch`
/// (the import-boundary rule forbids the chat feature from importing the
/// settings feature's presentation). Renders its [value] at full fidelity when
/// [onChanged] is null (used for the 即将支持 placeholders).
class _McpSwitch extends StatelessWidget {
  const _McpSwitch({required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const double _trackWidth = 32;
  static const double _trackHeight = 16;
  static const double _thumbSize = 12;
  static const Duration _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final enabled = onChanged != null;
    final trackColor = value
        ? theme.colorScheme.primary
        : (isDark ? const Color(0xFF8796A5) : const Color(0xFFAAB4BE));

    final pill = AnimatedContainer(
      duration: _duration,
      width: _trackWidth,
      height: _trackHeight,
      decoration: BoxDecoration(
        color: enabled ? trackColor : trackColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: _duration,
            curve: Curves.easeInOut,
            left: value ? 18 : 2,
            top: (_trackHeight - _thumbSize) / 2,
            child: Container(
              width: _thumbSize,
              height: _thumbSize,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: enabled ? 1 : 0.7),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (!enabled) return pill;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Haptics.instance.onSwitch();
        onChanged!(!value);
      },
      child: pill,
    );
  }
}

/// Pill-style tab pill matching the 语音功能 settings page `_TabHeader` (and the
/// MCP server settings page) — the white "card" that slides under the active
/// tab, with onSurface text and a soft 1px shadow. Rendered inside a [Container]
/// "track" (see [_mainTabs] / [_subTabs]).
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final _Tokens tokens;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? tokens.textPrimary : tokens.textSecondary;
    // Pill segmented controls swap state instantly (iOS UISegmentedControl
    // behaviour). An AnimatedContainer here would cross-fade the white
    // "card" + shadow on both buttons for 200ms, producing a visible flicker
    // — Flutter's built-in TabBar avoids that by sliding a single shared
    // indicator between tabs, but we're hand-rolling the strip here, so the
    // safest equivalent is just a static [Container].
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? tokens.bgPaper : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.tokens, required this.onTap});
  final _Tokens tokens;
  final VoidCallback onTap;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hover ? widget.tokens.hover : Colors.transparent,
          ),
          child: Icon(
            Icons.close,
            size: 22,
            color: widget.tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
