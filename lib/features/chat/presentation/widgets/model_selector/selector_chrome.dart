part of 'model_selector_dialog.dart';

/// Lays out header / tabs / scrollable content as a flex column, sizing to
/// content (card) or filling the screen (fullscreen) like the CSS flex column.
class _DialogBody extends StatelessWidget {
  const _DialogBody({
    required this.tokens,
    required this.fullScreen,
    required this.mediaQuery,
    required this.header,
    required this.tabs,
    required this.content,
  });

  final _Tokens tokens;
  final bool fullScreen;
  final MediaQueryData mediaQuery;
  final Widget header;
  final Widget tabs;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    // Header padding: base 16x24; mobile media query 12x16; fullscreen top is
    // max(16, safe-area-top). Left/right get safe-area insets in fullscreen.
    final hPad = fullScreen ? 16.0 : 24.0;
    final vPad = fullScreen ? 12.0 : 16.0;
    final topPad = fullScreen
        ? (mediaQuery.padding.top > 16 ? mediaQuery.padding.top : 16.0)
        : vPad;
    final safeLeft = fullScreen ? mediaQuery.padding.left : 0.0;
    final safeRight = fullScreen ? mediaQuery.padding.right : 0.0;

    final column = Column(
      mainAxisSize: fullScreen ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, vPad),
          child: header,
        ),
        tabs,
        if (fullScreen) Expanded(child: content) else Flexible(child: content),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(left: safeLeft, right: safeRight),
      child: column,
    );
  }
}

/// .solid-dialog-close-btn : 8px padding, 50% radius, text-secondary — shared
/// by the search toggle and the close button.
class _HeaderIconButton extends StatefulWidget {
  const _HeaderIconButton({
    required this.tokens,
    required this.icon,
    required this.onTap,
  });
  final _Tokens tokens;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
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
            widget.icon,
            size: 24,
            color: widget.tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatefulWidget {
  const _TabButton({
    required this.tokens,
    required this.compact,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final _Tokens tokens;
  final bool compact;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final color = widget.active ? t.primary : t.textSecondary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          // .solid-tab padding: 12px 16px (base); 10px 12px (<=600px). The
          // border-bottom 2px is part of the box, so bottom padding loses 2px.
          padding: widget.compact
              ? const EdgeInsets.fromLTRB(12, 10, 12, 8)
              : const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: BoxDecoration(
            color: _hover && !widget.active ? t.hover : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                width: 2,
                color: widget.active ? t.primary : Colors.transparent,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              // 0.875rem (14px) base; 0.8125rem (13px) at <=600px.
              fontSize: widget.compact ? 13 : 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrollArrow extends StatelessWidget {
  const _ScrollArrow({
    required this.tokens,
    required this.isLeft,
    required this.onTap,
  });

  final _Tokens tokens;
  final bool isLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.bgPaper,
      // box-shadow: 0 2px 8px rgba(0,0,0,0.15)
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.bgPaper,
          border: Border(
            left: isLeft ? BorderSide.none : BorderSide(color: tokens.border),
            right: isLeft ? BorderSide(color: tokens.border) : BorderSide.none,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              offset: Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            // .solid-tab-scroll-button padding: 8px 4px
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Icon(
              isLeft ? Icons.chevron_left : Icons.chevron_right,
              size: 24,
              color: tokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
