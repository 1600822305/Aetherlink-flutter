import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';

import 'branch_flow_graph.dart';
import 'branch_flow_layout.dart';

const Color kBranchUserColor = Color(0xFF22C55E); // green-500 — 用户
const Color kBranchAssistantColor = Color(0xFF3B82F6); // blue-500 — 助手

/// The 分支管理 canvas — the full node-graph form of Cherry Studio's
/// `TopicMessageFlowCanvas`: pan/zoom over message-tree node cards joined by
/// state-colored edges (绿=当前路径 / 灰虚线=已禁用 / 兄弟分支), with a minimap,
/// zoom controls and a legend. Tapping a node selects that branch.
class BranchFlowCanvas extends StatefulWidget {
  const BranchFlowCanvas({
    super.key,
    required this.layout,
    required this.previews,
    required this.onNodeTap,
  });

  final BranchFlowLayout layout;
  final Map<String, String> previews;
  final void Function(BranchFlowNode node) onNodeTap;

  @override
  State<BranchFlowCanvas> createState() => _BranchFlowCanvasState();
}

class _BranchFlowCanvasState extends State<BranchFlowCanvas> {
  final TransformationController _tc = TransformationController();
  Size _viewport = Size.zero;
  String? _focusedSignature;

  static const double _minScale = 0.2;
  static const double _maxScale = 1.4;
  static const double _initialScale = 0.85;

  @override
  void initState() {
    super.initState();
    _tc.addListener(_onTransform);
  }

  @override
  void dispose() {
    _tc.removeListener(_onTransform);
    _tc.dispose();
    super.dispose();
  }

  void _onTransform() {
    // Repaint the minimap viewport rectangle as the user pans/zooms.
    if (mounted) setState(() {});
  }

  double get _scale => _tc.value.getMaxScaleOnAxis();

  /// The portion of the canvas (content coords) currently visible.
  Rect get _visibleRect {
    if (_viewport == Size.zero) return Offset.zero & widget.layout.size;
    final inverse = Matrix4.tryInvert(_tc.value);
    if (inverse == null) return Offset.zero & widget.layout.size;
    return MatrixUtils.transformRect(inverse, Offset.zero & _viewport);
  }

  /// Centers the view on the graph root near the top, at the initial zoom —
  /// Cherry's `getRootFocusNode` + `getRootFocusViewport`.
  void _focusRoot() {
    final placed = widget.layout.placed;
    if (placed.isEmpty || _viewport == Size.zero) return;
    BranchFlowPlacedNode root = placed.first;
    for (final p in placed) {
      if (p.offset.dy != root.offset.dy) {
        if (p.offset.dy < root.offset.dy) root = p;
        continue;
      }
      if (p.node.isOnActivePath != root.node.isOnActivePath) {
        if (p.node.isOnActivePath) root = p;
        continue;
      }
      if (p.offset.dx < root.offset.dx) root = p;
    }
    const scale = _initialScale;
    final tx = _viewport.width / 2 - root.center.dx * scale;
    final ty = 56 - root.offset.dy * scale;
    _tc.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  void _zoomBy(double factor) {
    final newScale = (_scale * factor).clamp(_minScale, _maxScale);
    final center = Offset(_viewport.width / 2, _viewport.height / 2);
    final inverse = Matrix4.tryInvert(_tc.value);
    if (inverse == null) return;
    final contentCenter = MatrixUtils.transformPoint(inverse, center);
    final tx = center.dx - newScale * contentCenter.dx;
    final ty = center.dy - newScale * contentCenter.dy;
    _tc.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(newScale, newScale, newScale, 1);
  }

  void _centerOnContentPoint(Offset contentPoint) {
    final scale = _scale;
    final tx = _viewport.width / 2 - contentPoint.dx * scale;
    final ty = _viewport.height / 2 - contentPoint.dy * scale;
    _tc.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        // Re-focus once whenever the layout identity changes.
        final signature =
            '${widget.layout.placed.length}:${widget.layout.size.width.toStringAsFixed(0)}:${widget.layout.activeNodeId}';
        if (signature != _focusedSignature) {
          _focusedSignature = signature;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _focusRoot();
          });
        }

        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _tc,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(800),
                  minScale: _minScale,
                  maxScale: _maxScale,
                  child: SizedBox.fromSize(
                    size: widget.layout.size,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _EdgePainter(
                              layout: widget.layout,
                              theme: theme,
                            ),
                          ),
                        ),
                        for (final p in widget.layout.placed)
                          Positioned(
                            left: p.offset.dx,
                            top: p.offset.dy,
                            width: kBranchNodeWidth,
                            height: kBranchNodeHeight,
                            child: _NodeCard(
                              placed: p,
                              preview: widget.previews[p.node.id] ?? '',
                              onTap: () => widget.onNodeTap(p.node),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(top: 12, right: 14, child: _Legend(theme: theme)),
              Positioned(
                left: 12,
                bottom: 12,
                child: _ZoomControls(
                  onZoomIn: () => _zoomBy(1.25),
                  onZoomOut: () => _zoomBy(0.8),
                  onFit: _focusRoot,
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: _MiniMap(
                  layout: widget.layout,
                  visibleRect: _visibleRect,
                  theme: theme,
                  onTapContent: _centerOnContentPoint,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Paints the edges between node cards: a vertical smooth-step-ish curve per
/// edge, colored & dashed by [BranchFlowEdgeState].
class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.layout, required this.theme});

  final BranchFlowLayout layout;
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in layout.edges) {
      final from = layout.byId(edge.source);
      final to = layout.byId(edge.target);
      if (from == null || to == null) continue;

      final color = _edgeColor(edge.state, theme);
      final width = edge.state == BranchFlowEdgeState.active ? 2.25 : 1.5;
      final dashed = edge.state != BranchFlowEdgeState.normal;

      final start = from.bottomCenter;
      final end = to.topCenter;
      final midY = (start.dy + end.dy) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(start.dx, midY, end.dx, midY, end.dx, end.dy);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      if (dashed) {
        _drawDashedPath(canvas, path, paint, dash: 6, gap: 4);
      } else {
        canvas.drawPath(path, paint);
      }
      _drawArrowHead(canvas, end, color);
    }
  }

  void _drawArrowHead(Canvas canvas, Offset tip, Color color) {
    const double s = 5;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - s, tip.dy - s * 1.6)
      ..lineTo(tip.dx + s, tip.dy - s * 1.6)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter oldDelegate) =>
      oldDelegate.layout != layout || oldDelegate.theme != theme;
}

Color _edgeColor(BranchFlowEdgeState state, ThemeData theme) {
  switch (state) {
    case BranchFlowEdgeState.active:
      return kBranchUserColor; // success green
    case BranchFlowEdgeState.inactive:
      return theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    case BranchFlowEdgeState.sibling:
      return theme.colorScheme.outlineVariant;
    case BranchFlowEdgeState.normal:
      return theme.colorScheme.outlineVariant;
  }
}

/// One message node card (role chip + model + 2-line preview + status + time),
/// with current-branch highlight and 已禁用 dimming — Cherry's
/// `TopicMessageFlowNode`.
class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.placed,
    required this.preview,
    required this.onTap,
  });

  final BranchFlowPlacedNode placed;
  final String preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final node = placed.node;
    final m = node.message;
    final isUser = m.role == MessageRole.user;
    final roleColor = isUser ? kBranchUserColor : kBranchAssistantColor;
    final tint = m.role == MessageRole.user || m.role == MessageRole.assistant
        ? roleColor.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    return Opacity(
      opacity: node.isInactiveBranch ? 0.55 : 1,
      child: Material(
        color: node.isActive
            ? Color.alphaBlend(
                theme.colorScheme.primary.withValues(alpha: 0.10),
                theme.colorScheme.surface,
              )
            : Color.alphaBlend(tint, theme.colorScheme.surface),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: node.isActive
                    ? theme.colorScheme.primary
                    : roleColor.withValues(alpha: 0.35),
                width: node.isActive ? 1.8 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _roleLabel(m.role),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (_modelLabel(m.modelId ?? m.model?.id) case final s
                        when s.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          s,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontFamily: 'monospace',
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (node.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '当前',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    preview.isEmpty ? '-' : preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _statusColor(m.status, theme),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _statusLabel(m.status),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _fmtTime(m.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.add, onZoomIn, '放大'),
          Divider(height: 1, color: theme.dividerColor),
          _btn(Icons.remove, onZoomOut, '缩小'),
          Divider(height: 1, color: theme.dividerColor),
          _btn(Icons.center_focus_strong, onFit, '复位'),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, String tooltip) => IconButton(
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
      );
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({
    required this.layout,
    required this.visibleRect,
    required this.theme,
    required this.onTapContent,
  });

  final BranchFlowLayout layout;
  final Rect visibleRect;
  final ThemeData theme;
  final void Function(Offset contentPoint) onTapContent;

  static const double _w = 132;
  static const double _h = 96;

  @override
  Widget build(BuildContext context) {
    if (layout.placed.isEmpty || layout.size.isEmpty) {
      return const SizedBox.shrink();
    }
    final scale = math.min(_w / layout.size.width, _h / layout.size.height);

    void handle(Offset local) {
      onTapContent(Offset(local.dx / scale, local.dy / scale));
    }

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTapDown: (d) => handle(d.localPosition),
        onPanUpdate: (d) => handle(d.localPosition),
        child: Container(
          width: _w,
          height: _h,
          color: theme.colorScheme.surface,
          child: CustomPaint(
            painter: _MiniMapPainter(
              layout: layout,
              visibleRect: visibleRect,
              theme: theme,
              scale: scale,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter({
    required this.layout,
    required this.visibleRect,
    required this.theme,
    required this.scale,
  });

  final BranchFlowLayout layout;
  final Rect visibleRect;
  final ThemeData theme;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in layout.placed) {
      final r = Rect.fromLTWH(
        p.offset.dx * scale,
        p.offset.dy * scale,
        kBranchNodeWidth * scale,
        kBranchNodeHeight * scale,
      );
      final color = p.node.message.role == MessageRole.user
          ? kBranchUserColor
          : p.node.message.role == MessageRole.assistant
              ? kBranchAssistantColor
              : theme.colorScheme.outline;
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(1.5)),
        Paint()
          ..color = color.withValues(alpha: p.node.isInactiveBranch ? 0.3 : 0.7),
      );
    }
    // Viewport rectangle.
    final vr = Rect.fromLTWH(
      visibleRect.left * scale,
      visibleRect.top * scale,
      visibleRect.width * scale,
      visibleRect.height * scale,
    ).intersect(Offset.zero & size);
    canvas.drawRect(
      vr,
      Paint()
        ..color = theme.colorScheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_MiniMapPainter oldDelegate) =>
      oldDelegate.visibleRect != visibleRect ||
      oldDelegate.layout != layout ||
      oldDelegate.theme != theme;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          _swatch(kBranchUserColor, '用户'),
          _swatch(kBranchAssistantColor, '助手'),
          _line(kBranchUserColor, '当前'),
          _line(
            theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            '已禁用',
            dashed: true,
          ),
        ],
      ),
    );
  }

  Widget _swatch(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 10,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.2),
              border: Border.all(color: c.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      );

  Widget _line(Color c, String label, {bool dashed = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(dashed ? Icons.more_horiz : Icons.remove, size: 14, color: c),
          const SizedBox(width: 2),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      );
}

String _roleLabel(MessageRole role) => switch (role) {
      MessageRole.user => '用户',
      MessageRole.assistant => '助手',
      MessageRole.system => '系统',
      MessageRole.root => '根',
    };

/// Cherry's `getModelShortLabel`: keep the last `/`- then `:`-delimited segment.
String _modelLabel(String? modelId) {
  final v = modelId?.trim() ?? '';
  if (v.isEmpty) return '';
  return v.split('/').last.split(':').last;
}

String _statusLabel(MessageStatus status) => switch (status) {
      MessageStatus.success => '完成',
      MessageStatus.error => '错误',
      MessageStatus.paused => '已暂停',
      _ => '生成中',
    };

Color _statusColor(MessageStatus status, ThemeData theme) => switch (status) {
      MessageStatus.success => kBranchUserColor,
      MessageStatus.error => theme.colorScheme.error,
      MessageStatus.paused => theme.colorScheme.onSurfaceVariant,
      _ => const Color(0xFFF59E0B), // amber — in-progress
    };

String _fmtTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.month)}/${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}
