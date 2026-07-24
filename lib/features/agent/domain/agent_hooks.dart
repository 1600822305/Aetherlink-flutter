// 智能体 Hooks（Hooks 重构 H1，纯 Dart 可单测）：按职责拆在
// hooks/ 目录，本文件保留原导入路径的聚合出口。
//
// - agent_hook_config.dart：事件/类型/配置模型与 hooks.json 解析、匹配
// - agent_hook_protocol.dart：stdin JSON、退出/回复/HTTP 响应协议与聚合
// - agent_hook_ssrf.dart：http hook 的 SSRF 防护

export 'package:aetherlink_flutter/features/agent/domain/hooks/agent_hook_config.dart';
export 'package:aetherlink_flutter/features/agent/domain/hooks/agent_hook_protocol.dart';
export 'package:aetherlink_flutter/features/agent/domain/hooks/agent_hook_ssrf.dart';
