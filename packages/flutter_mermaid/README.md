# flutter_mermaid

A pure Dart/Flutter library for rendering Mermaid diagrams without WebView or external dependencies.

## Features

- **Flowchart**: Support for TD/TB, BT, LR, RL directions with various node shapes
- **Sequence Diagram**: Participant interactions with messages
- **Pie Chart**: Data visualization with customizable colors
- **Gantt Chart**: Project timeline visualization
- **Timeline**: Historical event visualization
- **Kanban Board**: Task management visualization
- **Radar Chart**: Multi-dimensional data visualization
- **XY Chart**: Bar and line charts

## Getting started

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_mermaid: ^0.1.0
```

## Usage

### Flowchart

```dart
import 'package:flutter_mermaid/flutter_mermaid.dart';

MermaidDiagram(
  code: '''
  graph TD
    A[Start] --> B{Decision}
    B -->|Yes| C[OK]
    B -->|No| D[Cancel]
  ''',
)
```

### Pie Chart

```dart
MermaidDiagram(
  code: '''
  pie
    title Favorite Pets
    "Dogs" : 386
    "Cats" : 85
    "Birds" : 15
  ''',
)
```

### Sequence Diagram

```dart
MermaidDiagram(
  code: '''
  sequenceDiagram
    Alice->>Bob: Hello Bob!
    Bob-->>Alice: Hi Alice!
  ''',
)
```

### Gantt Chart

```dart
MermaidDiagram(
  code: '''
  gantt
    title Project Schedule
    dateFormat YYYY-MM-DD
    section Planning
    Requirements :a1, 2024-01-01, 7d
    Design :a2, after a1, 5d
  ''',
)
```

### Timeline

```dart
MermaidDiagram(
  code: '''
  timeline
    title History of Social Media
    2002 : LinkedIn
    2004 : Facebook
    2005 : Youtube
    2006 : Twitter
  ''',
)
```

### Kanban Board

```dart
MermaidDiagram(
  code: '''
  kanban
    Backlog
      Task 1
      Task 2
    In Progress
      Task 3
    Done
      Task 4
  ''',
)
```

## Customization

### Themes

```dart
MermaidDiagram(
  code: '...',
  style: MermaidStyle.dark(), // or .forest(), .neutral()
)
```

### Responsive Layout

The widget automatically adapts to different screen sizes with responsive spacing and sizing.

### Interactive Mode

```dart
InteractiveMermaidDiagram(
  code: '...',
  minScale: 0.5,
  maxScale: 3.0,
  onNodeTap: (nodeId) {
    print('Tapped: $nodeId');
  },
)
```

## Supported Node Shapes

- Rectangle: `[text]`
- Rounded: `(text)`
- Stadium: `([text])`
- Diamond: `{text}`
- Hexagon: `{{text}}`
- Circle: `((text))`
- Cylinder: `[(text)]`
- Subroutine: `[[text]]`
- Parallelogram: `[/text/]` or `[\text\]`
- Trapezoid: `[/text\]` or `[\text/]`

## Additional Information

- Repository: https://github.com/JackCaow/flutter-mermaid
- Issue tracker: https://github.com/JackCaow/flutter-mermaid/issues