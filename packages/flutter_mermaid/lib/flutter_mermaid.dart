/// Pure Dart Mermaid diagram renderer for Flutter
///
/// This library provides a complete implementation of Mermaid diagram
/// rendering using only Dart and Flutter's CustomPainter, without
/// any WebView or external API dependencies.
///
/// Supported diagram types:
/// - Flowchart (graph TD/LR/BT/RL)
/// - Sequence diagram
/// - Pie chart
/// - Gantt chart
/// - Timeline
/// - Kanban board
/// - Radar chart
/// - XY chart
/// - Class diagram (basic)
/// - State diagram (basic)
///
/// Example usage:
/// ```dart
/// MermaidDiagram(
///   code: '''
///   graph TD
///     A[Start] --> B{Decision}
///     B -->|Yes| C[OK]
///     B -->|No| D[Cancel]
///   ''',
/// )
/// ```
///
/// Pie chart example:
/// ```dart
/// MermaidDiagram(
///   code: '''
///   pie
///     title Favorite Pets
///     "Dogs" : 386
///     "Cats" : 85
///     "Birds" : 15
///   ''',
/// )
/// ```
///
/// Timeline example:
/// ```dart
/// MermaidDiagram(
///   code: '''
///   timeline
///     title History of Social Media Platform
///     2002 : LinkedIn
///     2004 : Facebook
///          : Google
///     2005 : Youtube
///     2006 : Twitter
///   ''',
/// )
/// ```
library flutter_mermaid;

export 'src/config/responsive_config.dart';
export 'src/layout/layout_engine.dart';
export 'src/layout/sugiyama_layout.dart';
export 'src/layout/dagre_layout.dart';
export 'src/models/diagram.dart';
export 'src/models/edge.dart';
export 'src/models/gantt.dart';
export 'src/models/kanban.dart';
export 'src/models/node.dart';
export 'src/models/pie_chart.dart';
export 'src/models/timeline.dart';
export 'src/models/style.dart';
export 'src/models/radar.dart';
export 'src/models/xy_chart.dart';
export 'src/painter/flowchart_painter.dart';
export 'src/painter/gantt_painter.dart';
export 'src/painter/kanban_painter.dart';
export 'src/painter/mermaid_painter.dart';
export 'src/painter/pie_chart_painter.dart';
export 'src/painter/sequence_painter.dart';
export 'src/painter/timeline_painter.dart';
export 'src/painter/radar_painter.dart';
export 'src/painter/xy_chart_painter.dart';
export 'src/parser/flowchart_parser.dart';
export 'src/parser/gantt_parser.dart';
export 'src/parser/kanban_parser.dart';
export 'src/parser/mermaid_parser.dart';
export 'src/parser/pie_chart_parser.dart';
export 'src/parser/sequence_parser.dart';
export 'src/parser/timeline_parser.dart';
export 'src/parser/radar_parser.dart';
export 'src/parser/xy_chart_parser.dart';
export 'src/widgets/mermaid_diagram.dart';