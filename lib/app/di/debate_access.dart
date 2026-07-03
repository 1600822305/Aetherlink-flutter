import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/di/tts_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_send_hooks.dart';
import 'package:aetherlink_flutter/features/debate/domain/debate_chat_port.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';

part 'debate_access.g.dart';

/// App-level composition seam for AI 辩论（same pattern as `notion_access.dart`）:
/// the debate engine must not import chat's `application`, so its
/// [DebateChatPort] is implemented here on top of [ChatController].
@Riverpod(keepAlive: true)
DebateChatPort debateChatPort(Ref ref) => _ChatDebatePort(ref);

class _ChatDebatePort implements DebateChatPort {
  _ChatDebatePort(this._ref);

  final Ref _ref;

  ChatController get _chat => _ref.read(chatControllerProvider.notifier);

  @override
  Future<DebateSpeakResult> speak(DebateSpeakRequest request) async {
    final current = await _resolveModel(request.role.modelKey);
    if (current == null) return DebateSpeakResult.noModel;
    final turn = await _chat.sendDebateTurn(
      current: current,
      system: request.system,
      prompt: request.prompt,
      header: request.header,
      metadata: request.metadata,
      toolsEnabled: request.toolsEnabled,
    );
    if (turn == null || turn.text.trim().isEmpty) {
      return const DebateSpeakResult(failed: true);
    }
    return DebateSpeakResult(text: turn.text, messageId: turn.messageId);
  }

  @override
  Future<DebateSpeakResult> generate(DebateSpeakRequest request) async {
    final current = await _resolveModel(request.role.modelKey);
    if (current == null) return DebateSpeakResult.noModel;
    final text = await _chat.generateDebateText(
      current: current,
      system: request.system,
      prompt: request.prompt,
    );
    if (text == null || text.trim().isEmpty) {
      return const DebateSpeakResult(failed: true);
    }
    return DebateSpeakResult(text: text);
  }

  @override
  Future<void> announce(String markdown, {Map<String, dynamic>? metadata}) =>
      _chat.sendDebateNotice(
        markdown,
        // 默认标记为流程通告（notice），导出时可被过滤；裁决卡片等
        // 自带 metadata 的通告保留原标记。
        metadata:
            metadata ??
            const {
              'debate': {'phase': 'notice'},
            },
      );

  @override
  void setInterjectionListener(void Function(String text)? listener) {
    _ref
        .read(chatSendInterceptorHolderProvider.notifier)
        .set(
          listener == null
              ? null
              : (text) async {
                  await _chat.sendDebateInterjection(text);
                  listener(text);
                  return true;
                },
        );
  }

  @override
  void readAloud(String text, {required String messageId}) => unawaited(
    _ref.read(ttsActionsProvider).speak(text, messageId: messageId),
  );

  @override
  void cancelActiveStream() => _chat.stopStreaming();

  /// Resolves a `providerId/modelId` key to the live provider + model pair.
  Future<CurrentModel?> _resolveModel(String modelKey) async {
    final key = modelKey.trim();
    if (key.isEmpty) return null;
    final slash = key.indexOf('/');
    if (slash <= 0) return null;
    final providerId = key.substring(0, slash);
    final modelId = key.substring(slash + 1);
    final providers = await _ref.read(appModelProvidersProvider.future);
    for (final provider in providers) {
      if (provider.id != providerId) continue;
      for (final model in provider.models) {
        if (model.id == modelId) {
          return CurrentModel(provider: provider, model: model);
        }
      }
    }
    return null;
  }
}
