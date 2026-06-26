/// The kind of backend a workspace lives on. Each value maps to a future
/// `WorkspaceBackend` implementation that shares one interface but differs in
/// how it reaches files (and whether it can run a terminal):
///
/// - [localSaf]   : 手机本地目录,经 Android SAF (`content://`) 授权;无终端。
/// - [termux]     : 同机 Termux 里的路径,文件 + 终端都在 Termux。
/// - [ssh]        : 远程机器的路径,文件 + 终端都在远程 (Remote-SSH)。
///
/// P0 只点亮 [localSaf];另外两个先作为「敬请期待」入口占位。
enum WorkspaceBackendType {
  localSaf,
  termux,
  ssh;

  static WorkspaceBackendType fromName(String? name) {
    for (final type in WorkspaceBackendType.values) {
      if (type.name == name) return type;
    }
    return WorkspaceBackendType.localSaf;
  }
}

/// A single opened workspace — a pure file domain (no agent). Persisted as a
/// JSON record in the "最近打开" list so reopening lands straight back in it.
///
/// [root] is backend-specific: a `content://` tree URI for [WorkspaceBackendType.localSaf],
/// or a filesystem path for Termux / SSH. [displayPath] is the human-friendly
/// form shown in the UI (the raw `content://` URI is unreadable).
class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.backendType,
    required this.root,
    required this.lastOpenedAt,
    this.displayPath,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      backendType: WorkspaceBackendType.fromName(
        (json['backendType'] ?? '').toString(),
      ),
      root: (json['root'] ?? '').toString(),
      displayPath: (json['displayPath'] as Object?)?.toString(),
      lastOpenedAt:
          DateTime.tryParse((json['lastOpenedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  final String id;
  final String name;
  final WorkspaceBackendType backendType;
  final String root;
  final String? displayPath;
  final DateTime lastOpenedAt;

  Workspace copyWith({DateTime? lastOpenedAt}) {
    return Workspace(
      id: id,
      name: name,
      backendType: backendType,
      root: root,
      displayPath: displayPath,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'backendType': backendType.name,
    'root': root,
    if (displayPath != null) 'displayPath': displayPath,
    'lastOpenedAt': lastOpenedAt.toIso8601String(),
  };
}
