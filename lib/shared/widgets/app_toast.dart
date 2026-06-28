import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Semantic flavor of an [AppToast] message — drives the leading icon + accent.
enum AppToastType { success, error, warning, info }

/// An optional trailing action button shown inside a toast (e.g. 撤销).
class AppToastAction {
  const AppToastAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

/// A lightweight, fully custom toast — a small top-center pill rendered through
/// the root [Overlay] (so it never depends on a `Scaffold`/`ScaffoldMessenger`,
/// never pushes page content up, and never spans the full width like the stock
/// `SnackBar`).
///
/// Usage:
/// ```dart
/// AppToast.success(context, '测试成功：GPT-4o');
/// AppToast.error(context, '测试失败：超时');
/// ```
///
/// Only one toast is visible at a time; a new call replaces the current one.
abstract final class AppToast {
  static OverlayEntry? _entry;
  static _AppToastWidgetState? _current;

  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 2200),
    AppToastAction? action,
  }) => show(
    context,
    message,
    type: AppToastType.success,
    duration: duration,
    action: action,
  );

  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 2200),
    AppToastAction? action,
  }) => show(
    context,
    message,
    type: AppToastType.error,
    duration: duration,
    action: action,
  );

  static void warning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 2200),
    AppToastAction? action,
  }) => show(
    context,
    message,
    type: AppToastType.warning,
    duration: duration,
    action: action,
  );

  static void info(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 2200),
    AppToastAction? action,
  }) => show(
    context,
    message,
    type: AppToastType.info,
    duration: duration,
    action: action,
  );

  /// Shows a toast. [duration] is how long it stays fully visible before the
  /// dismiss animation runs.
  static void show(
    BuildContext context,
    String message, {
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(milliseconds: 2200),
    AppToastAction? action,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // Replace any visible toast so they never stack.
    _dismissImmediately();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _AppToastWidget(
        message: message,
        type: type,
        duration: duration,
        action: action,
        onRegister: (state) => _current = state,
        onDismissed: () {
          if (_entry == entry) {
            _entry = null;
            _current = null;
          }
          entry.remove();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// Copies [text] to the clipboard and shows a success toast.
  ///
  /// Centralizes the very common 「写剪贴板 + 提示已复制」 pattern so call sites
  /// don't each re-implement it.
  static Future<void> copy(
    BuildContext context,
    String text, {
    String message = '已复制',
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    success(context, message);
  }

  /// Dismisses the currently visible toast (if any) with its exit animation.
  static void dismiss() => _current?._dismiss();

  static void _dismissImmediately() {
    _current?._forceRemove();
    _entry?.remove();
    _entry = null;
    _current = null;
  }
}

class _AppToastWidget extends StatefulWidget {
  const _AppToastWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.action,
    required this.onRegister,
    required this.onDismissed,
  });

  final String message;
  final AppToastType type;
  final Duration duration;
  final AppToastAction? action;
  final ValueChanged<_AppToastWidgetState> onRegister;
  final VoidCallback onDismissed;

  @override
  State<_AppToastWidget> createState() => _AppToastWidgetState();
}

class _AppToastWidgetState extends State<_AppToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  Timer? _dismissTimer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    widget.onRegister(this);
    _controller.forward();
    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _dismissTimer?.cancel();
    if (!mounted) {
      widget.onDismissed();
      return;
    }
    await _controller.reverse();
    widget.onDismissed();
  }

  /// Called by [AppToast] when a new toast pre-empts this one.
  void _forceRemove() {
    _dismissTimer?.cancel();
    _dismissing = true;
  }

  ({Color accent, IconData icon}) _style(ColorScheme scheme) {
    switch (widget.type) {
      case AppToastType.success:
        return (accent: const Color(0xFF16A34A), icon: LucideIcons.circleCheck);
      case AppToastType.error:
        return (accent: const Color(0xFFDC2626), icon: LucideIcons.circleX);
      case AppToastType.warning:
        return (
          accent: const Color(0xFFD97706),
          icon: LucideIcons.triangleAlert,
        );
      case AppToastType.info:
        return (accent: scheme.primary, icon: LucideIcons.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final style = _style(scheme);
    final isDark = theme.brightness == Brightness.dark;

    return Positioned(
      top: media.padding.top + 12,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: AnimatedBuilder(
            animation: _curve,
            builder: (context, child) {
              return Opacity(
                opacity: _curve.value,
                child: Transform.translate(
                  offset: Offset(0, (1 - _curve.value) * -16),
                  child: child,
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: _dismiss,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: media.size.width - 48,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.4 : 0.12,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(style.icon, size: 18, color: style.accent),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (widget.action != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              widget.action!.onPressed();
                              _dismiss();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Text(
                                widget.action!.label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: style.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
