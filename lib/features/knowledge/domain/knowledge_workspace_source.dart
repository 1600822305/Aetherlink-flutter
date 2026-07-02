/// 工作区目录源（设计文档 §8「workspace 目录源」+ §8.1 staleness 检测）。
///
/// 知识核心不直接依赖 workspace 特性（导入边界），只持有这个抽象：具体实现由组合根
/// 注入，负责经 `WorkspaceBackend` 遍历目录、读文本、取文件元数据。与
/// [KnowledgeUrlFetcher] 一样保持可测（单测传一个假实现即可，不碰真实后端）。
abstract class KnowledgeWorkspaceSource {
  /// 递归列出 [workspaceId] 工作区根目录下所有可摄取的文本文件（实现负责跳过目录、
  /// 隐藏项、二进制与超限文件）。工作区不存在或授权失效时抛异常。
  Future<List<KnowledgeWorkspaceFile>> listTextFiles(String workspaceId);

  /// 取 [path] 当前的 `(mtime, size)`，供 staleness 比对（设计文档 §8.1）。文件失联
  /// （删除 / 授权失效）返回 null；比对逻辑据此判定「可能已过期」。
  Future<KnowledgeWorkspaceStat?> statFile(String workspaceId, String path);
}

/// 工作区里一个已读好正文的文本文件：`path` 是后端不透明标识（SAF `content://`
/// / posix 路径，勿解析），`mtime`/`size` 记入来源指纹供 staleness 比对。
class KnowledgeWorkspaceFile {
  const KnowledgeWorkspaceFile({
    required this.path,
    required this.name,
    required this.text,
    required this.mtime,
    required this.size,
  });

  final String path;
  final String name;
  final String text;
  final int mtime;
  final int size;
}

/// 文件元数据快照（mtime 毫秒 + 字节数），staleness 比对的最小单位。
class KnowledgeWorkspaceStat {
  const KnowledgeWorkspaceStat({required this.mtime, required this.size});

  final int mtime;
  final int size;
}
