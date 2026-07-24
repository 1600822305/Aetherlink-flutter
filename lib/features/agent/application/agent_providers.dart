// 智能体应用层 providers：按聚合根拆在同目录，本文件保留原导入
// 路径的聚合出口。
//
// - agent_seed_providers.dart：一次性种子/清理
// - agent_profile_providers.dart：档案列表 + 当前选中档案
// - agent_task_providers.dart：话题列表 + 事件流 + 当前选中话题
// - agent_ui_settings.dart：界面偏好 + 侧边栏 tab

export 'package:aetherlink_flutter/features/agent/application/agent_profile_providers.dart';
export 'package:aetherlink_flutter/features/agent/application/agent_seed_providers.dart';
export 'package:aetherlink_flutter/features/agent/application/agent_task_providers.dart';
export 'package:aetherlink_flutter/features/agent/application/agent_ui_settings.dart';
