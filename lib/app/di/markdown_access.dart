/// App-level composition seam（智能体架构稿 §决策记录 13：agent 与 chat
/// 互不引用）：智能体事件流的助手叙述要复用聊天页同一套 Markdown 渲染
/// （定稿 [AppMarkdown] / 流式 [StreamingMarkdownBody]），经由这里取，
/// agent 侧不直接 import features/chat。
library;

export 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/app_markdown.dart'
    show AppMarkdown;
export 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/text_blocks.dart'
    show StreamingMarkdownBody;
