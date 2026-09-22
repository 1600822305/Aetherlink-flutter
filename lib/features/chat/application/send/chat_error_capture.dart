import 'dart:convert';
import 'dart:io';

import 'package:aetherlink_flutter/core/error/failure.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/chat_error.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_error_capture.g.dart';

@Riverpod(keepAlive: true)
Future<PackageInfo> packageInfo(Ref ref) => PackageInfo.fromPlatform();

/// Resolves to a capture without [ChatErrorCapture.appVersion] until package
/// info has loaded (well before any turn can fail).
@Riverpod(keepAlive: true)
ChatErrorCapture chatErrorCapture(Ref ref) {
  final info = ref.watch(packageInfoProvider).value;
  return ChatErrorCapture(
    appVersion: info == null ? null : '${info.version}+${info.buildNumber}',
  );
}

const int kChatErrorStackLimit = 8 * 1024;
const int kChatErrorTextLimit = 4 * 1024;
const int kChatErrorArgumentsLimit = 2 * 1024;

/// Turns a thrown `(error, stackTrace)` plus the turn's context into a
/// [ChatError]. The single place that knows how to unwrap [Failure]s, redact
/// secrets and bound sizes — every error block in chat goes through here.
class ChatErrorCapture {
  const ChatErrorCapture({this.appVersion});

  /// `version+build` shown in the report; `null` when unknown (tests).
  final String? appVersion;

  /// The one-line, user-facing message for [error] — the same text that used to
  /// be the *only* thing persisted.
  static String messageOf(Object error) {
    if (error is Failure) return error.message;
    return error.toString();
  }

  ChatError capture(
    Object error,
    StackTrace? stackTrace, {
    required ChatErrorPhase phase,
    ModelProvider? provider,
    Model? model,
    int? round,
    String? toolName,
    Map<String, Object?>? toolArguments,
    List<ChatErrorAttempt> attempts = const [],
  }) {
    final stack = stackTrace == null || stackTrace == StackTrace.empty
        ? null
        : stackTrace.toString();
    return ChatError(
      phase: phase,
      type: error.runtimeType.toString(),
      message: redact(_clip(messageOf(error), kChatErrorTextLimit)),
      occurredAt: DateTime.now(),
      statusCode: error is NetworkFailure ? error.statusCode : null,
      stackTrace: stack == null
          ? null
          : redact(_clip(stack, kChatErrorStackLimit)),
      providerId: provider?.id ?? model?.provider,
      providerName: provider?.name,
      modelId: model?.id,
      modelName: model?.name,
      round: round,
      toolName: toolName,
      toolArguments: toolArguments == null
          ? null
          : redact(
              _clip(_encodeArguments(toolArguments), kChatErrorArgumentsLimit),
            ),
      attempts: attempts,
      appVersion: appVersion,
      platform: _platform(),
    );
  }

  ChatErrorAttempt attempt(int attempt, Object error, {String? keyId}) =>
      ChatErrorAttempt(
        attempt: attempt,
        type: error.runtimeType.toString(),
        message: redact(_clip(messageOf(error), kChatErrorTextLimit)),
        keyId: keyId,
      );

  static final List<RegExp> _secretPatterns = [
    // Common vendor key shapes (OpenAI, Anthropic, Google, xAI, Groq …).
    RegExp(r'\b(sk|xai|gsk)[-_][A-Za-z0-9_\-]{12,}'),
    RegExp(r'\bAIza[A-Za-z0-9_\-]{20,}'),
    RegExp(r'\bBearer\s+[A-Za-z0-9._~+/\-]{8,}=*', caseSensitive: false),
    // key=… / "api_key": "…" / x-api-key: … in URLs, JSON and headers.
    RegExp(
      r'''((?:api[_-]?key|x-api-key|access[_-]?token|secret|authorization|token|key)["']?\s*[:=]\s*["']?)([^\s"'&,}]{8,})''',
      caseSensitive: false,
    ),
  ];

  /// Masks anything that looks like an API key or bearer token so the report
  /// is safe to paste into a chat or an issue.
  static String redact(String text) {
    var out = text;
    for (final pattern in _secretPatterns) {
      out = out.replaceAllMapped(pattern, (m) {
        if (m.groupCount >= 2 && m.group(2) != null) {
          return '${m.group(1)}***';
        }
        return '***';
      });
    }
    return out;
  }

  static String _clip(String text, int limit) {
    if (text.length <= limit) return text;
    return '${text.substring(0, limit)}\n…（已截断，共 ${text.length} 字符）';
  }

  static String _encodeArguments(Map<String, Object?> args) {
    try {
      return const JsonEncoder.withIndent('  ').convert(args);
    } on Object catch (_) {
      return args.toString();
    }
  }

  static String _platform() {
    final mode = kReleaseMode
        ? 'release'
        : kProfileMode
        ? 'profile'
        : 'debug';
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion} '
        '($mode, dart ${Platform.version.split(' ').first})';
  }
}
