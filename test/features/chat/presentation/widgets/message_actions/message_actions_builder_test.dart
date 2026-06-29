import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_version.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/message_action.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/message_actions_builder.dart';

/// Contract tests for the headless behaviour layer ([MessageActionsBuilder]).
///
/// These pin the *which actions exist & when* contract that both presentation
/// surfaces (toolbar 模式 + 气泡模式) consume, so the two modes can never drift
/// apart — the exact failure mode of the old web `MessageActions` (one feature
/// re-implemented per `renderMode`).
void main() {
  ChatMessageView view({
    required MessageRole role,
    List<MessageVersion> versions = const [],
  }) {
    return ChatMessageView(
      id: 'm1',
      role: role,
      status: MessageStatus.success,
      text: 'hello',
      versions: versions,
    );
  }

  MessageVersion version(String id) => MessageVersion(
    id: id,
    messageId: 'm1',
    createdAt: DateTime(2024),
  );

  /// Builds the action list through a real [WidgetRef]/[BuildContext] (the
  /// builder takes both), without invoking any handler.
  Future<List<MessageAction>> buildActions(
    WidgetTester tester,
    ChatMessageView v, {
    bool showTtsButton = true,
  }) async {
    late List<MessageAction> actions;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              actions = MessageActionsBuilder(
                ref: ref,
                context: context,
                view: v,
                showTtsButton: showTtsButton,
                isMounted: () => true,
              ).build();
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return actions;
  }

  List<MessageActionId> idsOf(List<MessageAction> actions) =>
      actions.map((a) => a.id).toList();

  testWidgets('user message: 复制/编辑/导出/重新发送/创建分支/删除, no AI-only actions',
      (tester) async {
    final actions = await buildActions(tester, view(role: MessageRole.user));
    expect(
      idsOf(actions),
      [
        MessageActionId.copy,
        MessageActionId.edit,
        MessageActionId.export,
        MessageActionId.resend,
        MessageActionId.branch,
        MessageActionId.delete,
      ],
    );
    expect(idsOf(actions), isNot(contains(MessageActionId.regenerate)));
    expect(idsOf(actions), isNot(contains(MessageActionId.tts)));
    expect(idsOf(actions), isNot(contains(MessageActionId.translate)));
    expect(idsOf(actions), isNot(contains(MessageActionId.versionHistory)));
  });

  testWidgets('assistant message (no versions): 重新生成/语音播放/翻译, no 版本历史',
      (tester) async {
    final actions =
        await buildActions(tester, view(role: MessageRole.assistant));
    expect(
      idsOf(actions),
      [
        MessageActionId.copy,
        MessageActionId.edit,
        MessageActionId.export,
        MessageActionId.regenerate,
        MessageActionId.tts,
        MessageActionId.translate,
        MessageActionId.branch,
        MessageActionId.delete,
      ],
    );
    expect(idsOf(actions), isNot(contains(MessageActionId.resend)));
    expect(idsOf(actions), isNot(contains(MessageActionId.versionHistory)));
  });

  testWidgets('assistant message with versions: 版本历史 appears', (tester) async {
    final actions = await buildActions(
      tester,
      view(role: MessageRole.assistant, versions: [version('v1')]),
    );
    expect(idsOf(actions), contains(MessageActionId.versionHistory));
  });

  testWidgets('showTtsButton=false hides 语音播放 (and drops it from primary)',
      (tester) async {
    final actions = await buildActions(
      tester,
      view(role: MessageRole.assistant),
      showTtsButton: false,
    );
    expect(idsOf(actions), isNot(contains(MessageActionId.tts)));
    expect(actions.where((a) => a.isPrimary), isEmpty);
  });

  testWidgets('语音播放 is the only primary action (the 功能气泡 micro-bubble)',
      (tester) async {
    final actions =
        await buildActions(tester, view(role: MessageRole.assistant));
    final primary = actions.where((a) => a.isPrimary).map((a) => a.id).toList();
    expect(primary, [MessageActionId.tts]);
  });

  testWidgets('删除 is the only destructive action', (tester) async {
    final actions =
        await buildActions(tester, view(role: MessageRole.assistant));
    final destructive =
        actions.where((a) => a.isDestructive).map((a) => a.id).toList();
    expect(destructive, [MessageActionId.delete]);
  });
}
