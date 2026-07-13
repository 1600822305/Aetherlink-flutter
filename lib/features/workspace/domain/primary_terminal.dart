import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';

/// 默认主终端：新入口（打开文件夹 / 新建绑定）的默认后端选择。
///
/// 只是「默认值」而非全局唯一——各智能体档案 / 工作区仍各自绑定
/// 自己的后端 + 目录，可同时并行使用内置 / Termux / SSH；切换默认
/// 不影响已打开的会话与既有工作区。
class PrimaryTerminal {
  const PrimaryTerminal({required this.type, this.connectionId});

  /// prootLocal（内置）/ termux / ssh；SAF 无 shell，不能作主终端。
  final WorkspaceBackendType type;

  /// termux / ssh 指向 SshConnection 档案；内置终端为 null。
  final String? connectionId;

  static PrimaryTerminal? fromJson(Map<String, dynamic> json) {
    final typeName = (json['type'] ?? '').toString();
    WorkspaceBackendType? type;
    for (final t in WorkspaceBackendType.values) {
      if (t.name == typeName) type = t;
    }
    if (type == null || type == WorkspaceBackendType.localSaf) return null;
    final connectionId = (json['connectionId'] as Object?)?.toString();
    if (type != WorkspaceBackendType.prootLocal &&
        (connectionId == null || connectionId.isEmpty)) {
      return null;
    }
    return PrimaryTerminal(type: type, connectionId: connectionId);
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    if (connectionId != null) 'connectionId': connectionId,
  };
}
