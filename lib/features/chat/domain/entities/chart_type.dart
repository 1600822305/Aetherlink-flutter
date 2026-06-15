import 'package:json_annotation/json_annotation.dart';

/// Chart kind carried by a chart message block. Mirrors the `chartType` literal
/// union on `ChartMessageBlock` (`src/shared/types/newMessage.ts`).
enum ChartType {
  @JsonValue('bar')
  bar,
  @JsonValue('line')
  line,
  @JsonValue('pie')
  pie,
  @JsonValue('scatter')
  scatter,
}
