/// The kind of backend a workspace lives on. Each value maps to a future
/// `WorkspaceBackend` implementation that shares one interface but differs in
/// how it reaches files (and whether it can run a terminal):
///
/// - [localSaf]   : 手机本地目录,经 Android SAF (`content://`) 授权;无终端。
/// - [termux]     : 同机 Termux 里的路径,文件 + 终端都在 Termux。
/// - [ssh]        : 远程机器的路径,文件 + 终端都在远程 (Remote-SSH)。
/// - [prootLocal] : 内置终端——应用私有目录里的 PRoot + Alpine rootfs，
///                  零依赖，文件 + 终端都在本机（内置终端PRoot-设计文档）。
enum WorkspaceBackendType {
  localSaf,
  termux,
  ssh,
  prootLocal;

  static WorkspaceBackendType fromName(String? name) {
    for (final type in WorkspaceBackendType.values) {
      if (type.name == name) return type;
    }
    return WorkspaceBackendType.localSaf;
  }
}

/// The scope a workspace grants over its backend（双作用域设计稿 §2.1）：
///
/// - [project] : 项目模式——root = 一个项目目录，工具/终端会话锚定在
///               root 内（IDE 式真工作区）。
/// - [full]    : 全机模式——root = 整个执行环境（rootfs / 远端 $HOME），
///               完整终端能力，全量 HITL 审批。
enum WorkspaceScope {
  project,
  full;

  static WorkspaceScope fromName(String? name) {
    for (final scope in WorkspaceScope.values) {
      if (scope.name == name) return scope;
    }
    return WorkspaceScope.project;
  }
}

/// A single opened workspace — a pure file domain (no agent). Persisted as a
/// JSON record in the "最近打开" list so reopening lands straight back in it.
///
/// [root] is backend-specific: a `content://` tree URI for [WorkspaceBackendType.localSaf],
/// or a filesystem path for Termux / SSH. [displayPath] is the human-friendly
/// form shown in the UI (the raw `content://` URI is unreadable).
///
/// [connectionId] is set only for [WorkspaceBackendType.ssh] / `termux`
/// workspaces, pointing at a reusable `SshConnection` profile (设计文档 §5.1
/// 方案 C); SAF workspaces leave it null. It is the discriminator for dedup
/// (see `WorkspaceStore.open`) so two workspaces on the same `root` but
/// different servers stay distinct.
class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.backendType,
    required this.root,
    required this.lastOpenedAt,
    this.scope = WorkspaceScope.project,
    this.isolatedHome = false,
    this.displayPath,
    this.connectionId,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      backendType: WorkspaceBackendType.fromName(
        (json['backendType'] ?? '').toString(),
      ),
      // Absent in pre-scope records → infer from backendType (back-compat):
      // 旧内置终端记录（root=/root 整机）归 full，其余均为目录即工作区 → project。
      scope: json.containsKey('scope')
          ? WorkspaceScope.fromName((json['scope'] ?? '').toString())
          : (WorkspaceBackendType.fromName(
                    (json['backendType'] ?? '').toString(),
                  ) ==
                  WorkspaceBackendType.prootLocal
              ? WorkspaceScope.full
              : WorkspaceScope.project),
      // Absent in pre-P5 records → false (back-compat).
      isolatedHome: json['isolatedHome'] == true,
      root: (json['root'] ?? '').toString(),
      displayPath: (json['displayPath'] as Object?)?.toString(),
      // Absent in pre-SSH records → null (back-compat).
      connectionId: (json['connectionId'] as Object?)?.toString(),
      lastOpenedAt:
          DateTime.tryParse((json['lastOpenedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  final String id;
  final String name;
  final WorkspaceBackendType backendType;
  final WorkspaceScope scope;

  /// L2 语言级隔离开关（双作用域设计稿 §4 P5，仅项目模式有效）：
  /// 开启后会话注入独立 `HOME`（[isolatedHomePath]），rc 文件 / 全局
  /// 配置 / 缓存按工作区隔离；默认关 = 共享环境（现状）。
  final bool isolatedHome;
  final String root;
  final String? displayPath;
  final String? connectionId;
  final DateTime lastOpenedAt;

  /// 独立 HOME 目录：`<root>/.home`；未开启时为 null。
  String? get isolatedHomePath => isolatedHome
      ? '${root.endsWith('/') ? root.substring(0, root.length - 1) : root}/.home'
      : null;

  Workspace copyWith({
    String? name,
    String? connectionId,
    DateTime? lastOpenedAt,
  }) {
    return Workspace(
      id: id,
      name: name ?? this.name,
      backendType: backendType,
      scope: scope,
      isolatedHome: isolatedHome,
      root: root,
      displayPath: displayPath,
      connectionId: connectionId ?? this.connectionId,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'backendType': backendType.name,
    'scope': scope.name,
    if (isolatedHome) 'isolatedHome': true,
    'root': root,
    if (displayPath != null) 'displayPath': displayPath,
    if (connectionId != null) 'connectionId': connectionId,
    'lastOpenedAt': lastOpenedAt.toIso8601String(),
  };
}
