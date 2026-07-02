import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mounted_knowledge_bases_controller.g.dart';

/// 当前聊天会话挂载的知识库 id（功能缺口⑫ / 设计文档 §7 轨道 B）。
///
/// 输入框的「知识库」按钮打开多选面板写入这里；之后每次发送都会先对这些库跑
/// 一次检索，把命中注入系统提示（见组合根的 `collectChatKnowledgeInjection`）。
///
/// 与 [MultiModelMentions] 同款：纯内存（会话级），不落库。
@Riverpod(keepAlive: true)
class MountedKnowledgeBases extends _$MountedKnowledgeBases {
  @override
  List<String> build() => const <String>[];

  /// 替换整组挂载（挂载面板确认后调用）。
  void set(List<String> baseIds) => state = List<String>.unmodifiable(baseIds);

  void clear() => state = const <String>[];
}
