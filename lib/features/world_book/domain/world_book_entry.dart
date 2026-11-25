import 'package:freezed_annotation/freezed_annotation.dart';

part 'world_book_entry.freezed.dart';

/// 世界书条目的注入位置。JSON 值沿用 kelivo / RikkaHub 的大写串，保证导入导出
/// 与原格式双向兼容；未知值回退到 [afterSystemPrompt]。
enum WorldBookInjectionPosition {
  beforeSystemPrompt('BEFORE_SYSTEM_PROMPT'),
  afterSystemPrompt('AFTER_SYSTEM_PROMPT'),
  topOfChat('TOP_OF_CHAT'),
  bottomOfChat('BOTTOM_OF_CHAT'),
  atDepth('AT_DEPTH');

  const WorldBookInjectionPosition(this.wireName);

  final String wireName;

  static WorldBookInjectionPosition fromJson(Object? value) {
    final normalized = (value ?? '').toString().trim().toUpperCase();
    for (final position in values) {
      if (position.wireName == normalized) return position;
    }
    return afterSystemPrompt;
  }

  String toJson() => wireName;
}

/// 聊天位注入使用的消息角色。刻意不提供 system：部分供应商适配器会丢弃
/// 聊天中段的 system 消息。
enum WorldBookInjectionRole {
  user('USER'),
  assistant('ASSISTANT');

  const WorldBookInjectionRole(this.wireName);

  final String wireName;

  static WorldBookInjectionRole fromJson(Object? value) {
    final normalized = (value ?? '').toString().trim().toUpperCase();
    return normalized == assistant.wireName ? assistant : user;
  }

  String toJson() => wireName;
}

/// 一个世界书条目。JSON 编解码手写而非 json_serializable 生成：要保留 kelivo
/// 的容错语义（关键词去空、计时器截断到 0..10000、字段缺省值），且导出格式必须
/// 与 kelivo / RikkaHub 逐字段一致。
@freezed
abstract class WorldBookEntry with _$WorldBookEntry {
  const factory WorldBookEntry({
    required String id,
    @Default('') String name,
    @Default(true) bool enabled,
    @Default(0) int priority,
    @Default(WorldBookInjectionPosition.afterSystemPrompt)
    WorldBookInjectionPosition position,
    @Default('') String content,
    @Default(4) int injectDepth,
    @Default(WorldBookInjectionRole.user) WorldBookInjectionRole role,
    @Default(<String>[]) List<String> keywords,
    @Default(false) bool useRegex,
    @Default(false) bool caseSensitive,
    @Default(4) int scanDepth,
    @Default(false) bool constantActive,
    @Default(0) int sticky,
    @Default(0) int cooldown,
    @Default(0) int delay,
  }) = _WorldBookEntry;

  const WorldBookEntry._();

  static const int kMaxTimerValue = 10000;
  static const int kMaxDepth = 200;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'enabled': enabled,
    'priority': priority,
    'position': position.toJson(),
    'content': content,
    'injectDepth': injectDepth,
    'role': role.toJson(),
    'keywords': keywords,
    'useRegex': useRegex,
    'caseSensitive': caseSensitive,
    'scanDepth': scanDepth,
    'constantActive': constantActive,
    'sticky': sticky,
    'cooldown': cooldown,
    'delay': delay,
  };

  static WorldBookEntry fromJson(Map<String, dynamic> json) {
    final rawKeywords = json['keywords'];
    final keywords = rawKeywords is List<dynamic>
        ? rawKeywords
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    return WorldBookEntry(
      id: _string(json['id']),
      name: _string(json['name']),
      enabled: _bool(json['enabled'], true),
      priority: _int(json['priority'], 0),
      position: WorldBookInjectionPosition.fromJson(json['position']),
      content: _string(json['content']),
      injectDepth: _int(json['injectDepth'], 4),
      role: WorldBookInjectionRole.fromJson(json['role']),
      keywords: keywords,
      useRegex: _bool(json['useRegex'], false),
      caseSensitive: _bool(json['caseSensitive'], false),
      scanDepth: _int(json['scanDepth'], 4),
      constantActive: _bool(json['constantActive'], false),
      sticky: _int(json['sticky'], 0).clamp(0, kMaxTimerValue),
      cooldown: _int(json['cooldown'], 0).clamp(0, kMaxTimerValue),
      delay: _int(json['delay'], 0).clamp(0, kMaxTimerValue),
    );
  }

  static String _string(Object? value) => value is String ? value : '';

  static bool _bool(Object? value, bool fallback) =>
      value is bool ? value : fallback;

  static int _int(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;
}
