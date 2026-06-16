import 'package:freezed_annotation/freezed_annotation.dart';

part 'group.freezed.dart';
part 'group.g.dart';

/// Whether a [Group] organizes assistants or an assistant's topics. Wire values
/// mirror `Group['type']` (`src/shared/types/index.ts`).
enum GroupType {
  @JsonValue('assistant')
  assistant,
  @JsonValue('topic')
  topic,
}

/// A user-created folder that organizes assistants or topics in the sidebar.
/// Translation of `Group` (`src/shared/types/index.ts`).
///
/// [items] holds the member ids (assistant ids for [GroupType.assistant]
/// groups, topic ids for [GroupType.topic] groups). [assistantId] scopes a
/// topic group to its owning assistant (unset for assistant groups). [order]
/// is the display position and [expanded] the collapsed/expanded state.
@freezed
abstract class Group with _$Group {
  const factory Group({
    required String id,
    required String name,
    required GroupType type,
    String? assistantId,
    @Default(<String>[]) List<String> items,
    @Default(0) int order,
    @Default(true) bool expanded,
  }) = _Group;

  factory Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);
}
