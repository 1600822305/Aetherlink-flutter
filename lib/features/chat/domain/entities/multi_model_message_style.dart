import 'package:json_annotation/json_annotation.dart';

/// Layout style for multi-model message groups. Mirrors
/// `MultiModelMessageStyle` (`src/shared/types/newMessage.ts`).
enum MultiModelMessageStyle {
  @JsonValue('horizontal')
  horizontal,
  @JsonValue('vertical')
  vertical,
  @JsonValue('fold')
  fold,
  @JsonValue('grid')
  grid,
}
