import 'package:aetherlink_flutter/core/utils/iso_date_time_converter.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_error.freezed.dart';
part 'chat_error.g.dart';

/// Where in a turn the failure happened.
enum ChatErrorPhase {
  /// Before anything streamed: request building, key selection, connect.
  request,

  /// While consuming the provider's stream.
  stream,

  /// Inside a tool call the model requested.
  tool,

  /// Image / video generation.
  media,

  /// The reply was cut off by the app exiting (no exception, reconstructed
  /// on next load).
  interrupted,
}

/// One failed key-failover attempt preceding the terminal error.
@freezed
abstract class ChatErrorAttempt with _$ChatErrorAttempt {
  const factory ChatErrorAttempt({
    required int attempt,
    required String type,
    required String message,
    String? keyId,
  }) = _ChatErrorAttempt;

  factory ChatErrorAttempt.fromJson(Map<String, dynamic> json) =>
      _$ChatErrorAttemptFromJson(json);
}

/// Structured diagnostics for a failed assistant turn: what was thrown, where
/// (phase / tool / round), against which provider + model, and the stack trace
/// captured at the catch site. Persisted on [ErrorBlock.error] so the 错误详情
/// sheet can show and copy the full picture long after the turn ended.
///
/// Every string is already redacted (API keys / bearer tokens) and truncated
/// by the capture layer; this type is pure data.
@freezed
abstract class ChatError with _$ChatError {
  const ChatError._();

  const factory ChatError({
    required ChatErrorPhase phase,
    required String type,
    required String message,
    @IsoDateTimeConverter() required DateTime occurredAt,
    int? statusCode,
    String? stackTrace,
    String? providerId,
    String? providerName,
    String? modelId,
    String? modelName,
    int? round,
    String? toolName,
    String? toolArguments,
    @Default(<ChatErrorAttempt>[]) List<ChatErrorAttempt> attempts,
    String? appVersion,
    String? platform,
  }) = _ChatError;

  factory ChatError.fromJson(Map<String, dynamic> json) =>
      _$ChatErrorFromJson(json);

  /// Reads the diagnostics off an [ErrorBlock], synthesising a minimal one from
  /// the legacy `message` / `code` / `content` fields for blocks persisted
  /// before structured errors existed. Never throws.
  static ChatError fromBlock(ErrorBlock block) {
    final raw = block.error;
    if (raw != null) {
      try {
        return ChatError.fromJson(raw);
      } on Object catch (_) {}
    }
    final message = block.message ?? block.details ?? block.content;
    return ChatError(
      phase: ChatErrorPhase.stream,
      type: 'unknown',
      message: message.isEmpty ? '发生错误' : message,
      occurredAt: block.updatedAt ?? block.createdAt,
      statusCode: int.tryParse(block.code ?? ''),
    );
  }

  /// `name (id)` for display; `null` when neither is known.
  String? get providerLabel => _labelled(providerName, providerId);
  String? get modelLabel => _labelled(modelName, modelId);

  /// The plain-text report the user copies out of the 错误详情 sheet — headed
  /// sections so it reads in chat, stack / arguments fenced so they survive
  /// Markdown rendering.
  String toReport() {
    final b = StringBuffer()
      ..writeln('## AetherLink 错误报告')
      ..writeln()
      ..writeln('- 时间: ${occurredAt.toIso8601String()}')
      ..writeln('- 阶段: ${phase.name}')
      ..writeln('- 异常类型: $type');
    if (statusCode != null) b.writeln('- HTTP 状态: $statusCode');
    if (appVersion != null) b.writeln('- 应用版本: $appVersion');
    if (platform != null) b.writeln('- 平台: $platform');
    if (providerLabel != null) b.writeln('- 提供商: $providerLabel');
    if (modelLabel != null) b.writeln('- 模型: $modelLabel');
    if (round != null) b.writeln('- 轮次: $round');
    if (toolName != null) b.writeln('- 工具: $toolName');
    b
      ..writeln()
      ..writeln('### 错误信息')
      ..writeln()
      ..writeln(message);
    if (toolArguments != null) {
      b
        ..writeln()
        ..writeln('### 工具参数')
        ..writeln()
        ..writeln('```json')
        ..writeln(toolArguments)
        ..writeln('```');
    }
    if (attempts.isNotEmpty) {
      b
        ..writeln()
        ..writeln('### 之前的重试');
      for (final a in attempts) {
        b.writeln(
          '- #${a.attempt}${a.keyId != null ? ' (key ${a.keyId})' : ''} '
          '${a.type}: ${a.message}',
        );
      }
    }
    if (stackTrace != null) {
      b
        ..writeln()
        ..writeln('### 堆栈')
        ..writeln()
        ..writeln('```')
        ..writeln(stackTrace)
        ..writeln('```');
    }
    return b.toString().trimRight();
  }

  static String? _labelled(String? name, String? id) {
    if (name == null) return id;
    if (id == null || id == name) return name;
    return '$name ($id)';
  }
}
