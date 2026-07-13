// 回合后处理相关的会话操作，从 chat_controller.dart 主体拆出的 part 文件：
// 话题预览刷新、标题生成、后续问题建议生成、自动记忆提取。
// 这些操作在每轮回复流结束后以 unawaited 方式调用，均为 best-effort（失败静默吞掉）。
// 以 part + mixin 的形式与 ChatController 同库拆分（mixin 里声明所依赖的
// 私有成员抽象签名，由 ChatController 本体提供实现）。

part of 'chat_controller.dart';

mixin _ChatPostTurn on _$ChatController {
  // --- 由 ChatController 本体提供的成员 ---

  String? get _topicId;
  String get _assistantId;
  ChatRepository get _repo;

  // --- 搬出的方法 ---

  /// Recomputes and persists the topic's `lastMessagePreview`, `lastMessageTime`
  /// and `messageCount` from the DB — the port of the web's
  /// `TopicPreviewService.refreshTopicPreview`. Failure is logged but never
  /// rethrown (preview is a display enhancement, must not disrupt the message
  /// flow).
  Future<void> _refreshTopicPreview([String? forTopicId]) async {
    final topicId = forTopicId ?? _topicId;
    if (topicId == null) return;
    try {
      final topic = await _repo.getTopic(topicId);
      if (topic == null) return;
      final messages = await _repo.getMessagesByTopicId(topicId);
      final count = messages.length;
      String preview = '';
      String? lastTime;
      if (messages.isNotEmpty) {
        messages.sort(compareMessagesChronologically);
        final last = messages.last;
        lastTime = (last.updatedAt ?? last.createdAt).toIso8601String();
        final blocks = await _repo.getMessageBlocksByMessageId(last.id);
        for (final block in blocks) {
          if (block is MainTextBlock && block.content.trim().isNotEmpty) {
            preview = _formatPreview(block.content);
            break;
          }
        }
      }
      if (topic.lastMessagePreview == preview &&
          topic.messageCount == count &&
          topic.lastMessageTime == lastTime) {
        return;
      }
      await _repo.saveTopic(
        topic.copyWith(
          lastMessagePreview: preview,
          messageCount: count,
          lastMessageTime: lastTime,
          updatedAt: DateTime.now(),
        ),
      );
      ref.invalidate(topicsProvider);
    } on Object catch (_) {
      // Preview refresh is non-critical; swallow errors.
    }
  }

  /// Collapse whitespace and truncate to 50 chars (mirrors the web's
  /// `formatPreviewText`).
  static String _formatPreview(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 50) return normalized;
    return '${normalized.substring(0, 50)}…';
  }

  /// Generates a conversation title using the configured title model + prompt.
  ///
  /// Mirrors rikkahub's `ChatService.generateTitle`: takes the last 4 messages,
  /// builds a summary, sends the title prompt to the title model (falling back
  /// to the current chat model), and saves the result as the topic name.
  /// Non-critical: failures are silently swallowed.
  Future<void> _generateTitle([String? forTopicId]) async {
    final topicId = forTopicId ?? _topicId;
    if (topicId == null) return;
    try {
      final topic = await _repo.getTopic(topicId);
      if (topic == null) return;

      // Skip if the name was manually edited or is already non-default.
      if (topic.isNameManuallyEdited) return;
      final name = topic.name;
      if (name != '新对话' &&
          name != '新的对话' &&
          name != '新话题' &&
          name.trim().isNotEmpty) {
        return;
      }

      // Gather the last 4 messages' text for context.
      final messages = await _repo.getMessagesByTopicId(topicId)
        ..sort(compareMessagesChronologically);
      if (messages.isEmpty) return;

      final recent = messages.length > 4
          ? messages.sublist(messages.length - 4)
          : messages;
      final summaryParts = <String>[];
      for (final msg in recent) {
        final blocks = await _repo.getMessageBlocksByMessageId(msg.id);
        final text = blocks
            .whereType<MainTextBlock>()
            .map((b) => b.content)
            .join('\n');
        if (text.trim().isEmpty) continue;
        final truncated = text.length > 500
            ? '${text.substring(0, 500)}…'
            : text;
        final role = msg.role == MessageRole.user ? '用户' : 'AI';
        summaryParts.add('$role: $truncated');
      }
      if (summaryParts.isEmpty) return;
      final contentSummary = summaryParts.join('\n\n');

      // Resolve the title model; fall back to the current chat model.
      final auxState = ref.read(auxiliaryModelControllerProvider);
      final providers = await ref.read(appModelProvidersProvider.future);
      var resolved = resolveAuxiliaryModel(auxState.titleModelKey, providers);
      resolved ??= findCurrentModel(providers);
      if (resolved == null) return;

      final effective = effectiveModelFor(resolved);
      final titlePrompt = auxState.titlePrompt;

      // Build the prompt by replacing {{messages}} / {content} / {locale}.
      final locale = 'Chinese';
      var prompt = titlePrompt
          .replaceAll('{{messages}}', contentSummary)
          .replaceAll('{content}', contentSummary)
          .replaceAll('{locale}', locale);
      // If the template didn't contain any placeholder, append the content.
      if (prompt == titlePrompt) {
        prompt = '$titlePrompt\n\n$contentSummary';
      }

      final request = LlmChatRequest(
        model: effective,
        messages: [LlmMessage(role: MessageRole.user, content: prompt)],
        extraHeaders: effective.providerExtraHeaders,
        extraBody: effective.providerExtraBody,
      );

      final gateway = ref.read(llmGatewayFactoryProvider).forModel(effective);
      final buffer = StringBuffer();
      await for (final chunk in gateway.streamChat(request)) {
        switch (chunk) {
          case LlmTextDelta(:final text):
            buffer.write(text);
          case LlmReasoningDelta():
          case LlmToolCallDelta():
          case LlmToolCallChunk():
          case LlmDone():
            break;
        }
      }

      var newTitle = buffer.toString().trim();
      if (newTitle.isEmpty) return;

      // Strip surrounding quotes if the model wrapped the title.
      if (newTitle.startsWith('"') && newTitle.endsWith('"')) {
        newTitle = newTitle.substring(1, newTitle.length - 1).trim();
      }
      if (newTitle.startsWith('「') && newTitle.endsWith('」')) {
        newTitle = newTitle.substring(1, newTitle.length - 1).trim();
      }
      if (newTitle.isEmpty || newTitle == name) return;

      // Re-fetch topic (may have changed during generation).
      final latest = await _repo.getTopic(topicId);
      if (latest == null || latest.isNameManuallyEdited) return;

      await _repo.saveTopic(
        latest.copyWith(name: newTitle, updatedAt: DateTime.now()),
      );
      ref.invalidate(topicsProvider);
    } on Object catch (_) {
      // Title generation is non-critical; swallow errors.
    }
  }

  /// Generates follow-up suggestions (建议模型) for the just-finished reply on
  /// [turnTopicId], then pushes them into state if that topic is still the one
  /// being viewed. A no-op unless the 建议 feature is enabled and a suggestion
  /// model is configured (footnote: "未设置时不生成后续问题建议"). Best-effort:
  /// any failure is swallowed, like title generation.
  Future<void> _maybeGenerateSuggestions(
    String turnTopicId,
    List<ChatMessageView> views,
  ) async {
    try {
      final auxState = ref.read(auxiliaryModelControllerProvider);
      if (!auxState.enableSuggestion) return;
      final providers = await ref.read(appModelProvidersProvider.future);
      final resolved = resolveAuxiliaryModel(
        auxState.suggestionModelKey,
        providers,
      );
      if (resolved == null) return;

      final content = SuggestionService.buildContent(views);
      if (content.isEmpty) return;

      final effective = effectiveModelFor(resolved);
      const locale = 'Chinese';
      var prompt = auxState.suggestionPrompt
          .replaceAll('{{messages}}', content)
          .replaceAll('{content}', content)
          .replaceAll('{locale}', locale);
      // If the template carried no placeholder, append the content.
      if (prompt == auxState.suggestionPrompt) {
        prompt = '${auxState.suggestionPrompt}\n\n$content';
      }

      final request = LlmChatRequest(
        model: effective,
        messages: [LlmMessage(role: MessageRole.user, content: prompt)],
        extraHeaders: effective.providerExtraHeaders,
        extraBody: effective.providerExtraBody,
      );

      final gateway = ref.read(llmGatewayFactoryProvider).forModel(effective);
      final buffer = StringBuffer();
      await for (final chunk in gateway.streamChat(request)) {
        if (chunk is LlmTextDelta) buffer.write(chunk.text);
      }

      final suggestions = SuggestionService.parseSuggestions(buffer.toString());
      if (suggestions.isEmpty) return;
      _emitSuggestions(turnTopicId, suggestions);
    } on Object catch (_) {
      // Suggestion generation is non-critical; swallow errors.
    }
  }

  /// Auto-extracts long-term memories (autoAnalyze) from the just-finished turn
  /// on [turnTopicId] and writes them to the 普通聊天 memory store. A no-op
  /// unless 记忆 is enabled and at least one 自动写入 toggle is on. The extraction
  /// itself runs on the 快速/标题 auxiliary model (falling back to the current
  /// chat model). Best-effort: any failure is swallowed, like title generation.
  Future<void> _maybeExtractMemory(String turnTopicId) async {
    try {
      final flags = readMemoryAutoWriteFlags(ref);
      if (!flags.enabled) return;
      if (!flags.autoWritePrivate && !flags.autoWriteGlobal) return;

      final assistantId = _assistantId;

      // Gather the last 6 messages' text as the extraction context.
      final messages = await _repo.getMessagesByTopicId(turnTopicId)
        ..sort(compareMessagesChronologically);
      if (messages.isEmpty) return;
      final recent = messages.length > 6
          ? messages.sublist(messages.length - 6)
          : messages;
      final lines = <String>[];
      for (final msg in recent) {
        final blocks = await _repo.getMessageBlocksByMessageId(msg.id);
        final text = blocks
            .whereType<MainTextBlock>()
            .map((b) => b.content)
            .join('\n')
            .trim();
        if (text.isEmpty) continue;
        final truncated = text.length > 800 ? '${text.substring(0, 800)}…' : text;
        final role = msg.role == MessageRole.user ? '用户' : 'AI';
        lines.add('$role: $truncated');
      }
      if (lines.isEmpty) return;
      final conversation = lines.join('\n\n');

      // Resolve the extraction model: 快速模型 → 标题模型 → current chat model.
      final auxState = ref.read(auxiliaryModelControllerProvider);
      final providers = await ref.read(appModelProvidersProvider.future);
      var resolved = resolveAuxiliaryModel(auxState.fastModelKey, providers);
      resolved ??= resolveAuxiliaryModel(auxState.titleModelKey, providers);
      resolved ??= findCurrentModel(providers);
      if (resolved == null) return;
      final effective = effectiveModelFor(resolved);

      final prompt = buildMemoryExtractionPrompt(
        conversation: conversation,
        allowGlobal: flags.autoWriteGlobal,
        allowPrivate: flags.autoWritePrivate,
      );

      final request = LlmChatRequest(
        model: effective,
        messages: [LlmMessage(role: MessageRole.user, content: prompt)],
        extraHeaders: effective.providerExtraHeaders,
        extraBody: effective.providerExtraBody,
      );

      final gateway = ref.read(llmGatewayFactoryProvider).forModel(effective);
      final buffer = StringBuffer();
      await for (final chunk in gateway.streamChat(request)) {
        if (chunk is LlmTextDelta) buffer.write(chunk.text);
      }

      final candidates = parseMemoryExtractionResponse(buffer.toString())
          .where(
            (c) => c.level == MemoryLevel.global
                ? flags.autoWriteGlobal
                : flags.autoWritePrivate,
          )
          .toList();
      if (candidates.isEmpty) return;

      await storeExtractedChatMemories(
        ref,
        assistantId: assistantId,
        candidates: candidates,
      );
    } on Object catch (_) {
      // Memory extraction is non-critical; swallow errors.
    }
  }

  /// Pushes [suggestions] into the live state, but only when [turnTopicId] is
  /// still the topic on screen and a new reply hasn't started streaming (which
  /// would have cleared them). Leaves [messages] untouched.
  void _emitSuggestions(String turnTopicId, List<String> suggestions) {
    if (turnTopicId != _topicId) return;
    final current = state.value;
    if (current == null || current.isStreaming) return;
    state = AsyncData(current.copyWith(suggestions: suggestions));
  }
}
