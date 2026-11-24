/// App-level composition seam（智能体架构稿 §决策记录 13：agent 与 chat
/// 互不引用）：智能体事件流的消息长按选中/复制复用聊天页同一套
/// [MessageSelectionArea]（含自定义复制面板与「消息可选中复制」开关），
/// 「引用到输入框」经 [ChatInputBar.insertTextHook] 接到智能体输入框。
library;

export 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/message_selection_area.dart'
    show MessageSelectionArea, SettingAwareMessageSelectionArea;
export 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_input_bar/chat_input_bar.dart'
    show ChatInputBar;
