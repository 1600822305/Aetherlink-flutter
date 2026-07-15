/// App-level composition seam（import-boundary Rule 3）：聊天里的终端工具块
/// 「在终端中查看」要写入 workspace 的终端聚焦会话 ID，经由这里取，
/// 不直接 import workspace 的 application。
library;

export 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart'
    show TerminalFocusSession, terminalFocusSessionProvider;
