# 本地 SAF 工作区插件 — 方法规格

> 状态：规格 / 待实现
> 目标读者：实现自研原生插件的开发者
> 关联文档：《工作区与智能体模式-设计构想》（`docs/工作区与智能体模式-设计构想.md`），本文档是其中「后端① 纯手机工作区（本地 SAF）」的落地方法契约。

---

## 0. 背景与结论

- 原版 Web 没有使用任何现成的 SAF 库，而是自研了一个 Capacitor 原生插件 `AdvancedFileManager`（Kotlin），自己处理 `content://` URI、持久化权限、目录遍历、读写、按行范围读取等。原因是现成方案在性能与能力（按行读、原子写、diff 写入）上不够用。
- 结论：Flutter 侧同样**一开始就自研一个本地 SAF 插件**（method channel + Kotlin），直接照原版 `AdvancedFileManagerPlugin` 契约移植，而不是先用第三方插件再返工。

## 1. 分工与边界

- **原生插件（Kotlin / method channel）**：本规格定义的全部方法，由插件自行实现。
- **Dart 侧**：`WorkspaceBackend` 抽象接口 + `LocalSafBackend`（调用下述 method channel）+ 上层 UI，在插件方法签名定稿后对接。
- **对接约定**：只要 method channel 的**方法名**与**入参/返回 JSON 字段**与本文档表格一致，上下层即可无缝对上。
- **隔离纪律**：自研插件只允许被 `LocalSafBackend` 一个类 import；UI、聊天 @文件、agent 一律只依赖 `WorkspaceBackend` 抽象。将来换插件 / 优化原生层，改动只发生在 `LocalSafBackend` 一处。

## 2. 数据结构

```
FileInfo {
  name, path, size,
  type: 'file' | 'directory',
  mtime, ctime, permissions, isHidden
}

SelectedFileInfo {            // 系统选择器返回（比 FileInfo 多 uri / mimeType / displayPath）
  name, path, uri, size, type, mimeType, mtime, ctime, displayPath?
}
```

> 安卓侧 `path` 本质是 `content://` URI；建议额外提供 `content://` → 友好显示路径（`displayPath`）的转换，原版有此设计。

---

## 3. 方法清单（按优先级分档）

### P0 —— 第一步必须（选目录 + 只读浏览，跑通工作区最小闭环）

| 方法 | 入参 | 返回 | 说明 |
|---|---|---|---|
| `requestPermissions()` | — | `{granted, message}` | 触发 SAF 选目录授权 |
| `checkPermissions()` | — | `{granted, message}` | 检查是否已有持久化权限 |
| `openSystemFilePicker(opts)` | `{type:'file'\|'directory'\|'both', multiple, accept?, startDirectory?, title?}` | `{files[], directories[], cancelled}` | 调系统选择器；选目录拿目录树 URI **并 takePersistableUriPermission 持久化** |
| `listDirectory(opts)` | `{path, showHidden, sortBy:'name'\|'size'\|'mtime'\|'type', sortOrder:'asc'\|'desc'}` | `{files: FileInfo[], totalCount}` | 列目录（文件树核心） |
| `readFile(opts)` | `{path, encoding:'utf8'\|'base64'}` | `{content, encoding}` | 读文件内容 |
| `getFileInfo(opts)` | `{path}` | `FileInfo` | 单个文件/目录元信息 |
| `exists(opts)` | `{path}` | `{exists}` | 路径是否存在 |

> P0 关键点：选目录后**必须持久化权限**（`takePersistableUriPermission`），否则重启 App 工作区失效。

### P1 —— 工作区写操作 + agent 编辑能力（做 agent 前必须补齐）

| 方法 | 入参 | 返回 | 说明 |
|---|---|---|---|
| `writeFile(opts)` | `{path, content, encoding, append}` | void | 写/追加文件 |
| `createFile(opts)` | `{path, content, encoding}` | void | 新建文件 |
| `createDirectory(opts)` | `{path, recursive}` | void | 新建目录 |
| `deleteFile(opts)` | `{path}` | void | 删文件 |
| `deleteDirectory(opts)` | `{path}` | void | 删目录 |
| `renameFile(opts)` | `{path, newName}` | void | 重命名 |
| `moveFile(opts)` | `{sourcePath, destinationPath}` | void | 移动 |
| `copyFile(opts)` | `{sourcePath, destinationPath, overwrite}` | void | 复制 |
| `readFileRange(opts)` | `{path, startLine, endLine, encoding?}` | `{content, totalLines, startLine, endLine, rangeHash}` | **按行范围读**——大文件/agent 必备 |
| `getLineCount(opts)` | `{path}` | `{lines}` | 行数 |
| `getFileHash(opts)` | `{path, algorithm:'md5'\|'sha256'}` | `{hash, algorithm}` | 改前校验/防冲突 |

> `readFileRange` 返回的 `rangeHash` 是给 agent 做乐观锁（"我读的那段有没有被改过"）的依据，建议保留该设计。

### P2 —— agent 高级编辑 + 检索（可后置，建议最终对齐原版）

| 方法 | 入参 | 返回 | 说明 |
|---|---|---|---|
| `insertContent(opts)` | `{path, line, content}` | void | 指定行前插入 |
| `replaceInFile(opts)` | `{path, search, replace, isRegex?, replaceAll?, caseSensitive?}` | `{replacements, modified}` | 查找替换 |
| `applyDiff(opts)` | `{path, diff, createBackup?}` | `{success, linesChanged, linesAdded, linesDeleted, backupPath?}` | **打 diff**——agent 改文件主力 |
| `searchFiles(opts)` | `{directory, query, searchType:'name'\|'content'\|'both', fileTypes[], maxResults, recursive}` | `{files[], totalFound}` | 全文/文件名检索 |
| `openSystemFileManager(path?)` | `path?` | void | 跳系统文件管理器 |
| `openFileWithSystemApp(filePath, mimeType?)` | — | void | 用系统 App 打开 |
| `echo({value})` | `{value}` | `{value}` | 连通性自测 |

---

## 4. 来源与平台说明

- **契约来源**：原版 Web 的 Capacitor 插件接口 `AdvancedFileManagerPlugin`（`AetherLink/src/shared/types/fileManager.ts`），共 23 个方法。原版的 agent 工具（`file-editor` MCP server 的 16 个工具：`read_file / write_to_file / insert_content / apply_diff / list_files / search_files / replace_in_file / ...`）底层调的就是这套——**实现了这套，agent 工具链将来零障碍接入**。
- **平台**：以上为安卓 SAF 契约。iOS（`UIDocumentPicker` + security-scoped bookmark）方法签名可保持一致，仅原生实现换一套；建议先做安卓。
