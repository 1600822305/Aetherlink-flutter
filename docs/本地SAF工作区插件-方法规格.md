# 本地 SAF 工作区插件 — 方法规格

> 状态:规格 v2 / 待实现
> 目标读者:实现自研原生插件的开发者
> 关联文档:《工作区与智能体模式-设计构想》(`docs/工作区与智能体模式-设计构想.md`),本文档是其中「后端① 纯手机工作区(本地 SAF)」的落地方法契约。
> v2 变更:扩字段类型与可空说明、补「§3 通用约定」(path 编码 / 错误码 / 数值约定 / SAF 已知限制)、P0 加入 `listPersistedPermissions` 与 `releasePersistableUriPermission`、明确 iOS 差异点。

---

## 0. 背景与结论

- 原版 Web 没有使用任何现成的 SAF 库,而是自研了一个 Capacitor 原生插件 `AdvancedFileManager`(Kotlin),自己处理 `content://` URI、持久化权限、目录遍历、读写、按行范围读等。原因是现成方案在性能与能力(按行读、原子写、diff 写入)上不够用。
- 结论:Flutter 侧同样**一开始就自研一个本地 SAF 插件**(method channel + Kotlin),直接照原版 `AdvancedFileManagerPlugin` 契约移植,而不是先用第三方插件再返工。

## 1. 分工与边界

- **原生插件(Kotlin / method channel)**:本规格定义的全部方法,由插件自行实现。
- **Dart 侧**:`WorkspaceBackend` 抽象接口 + `LocalSafBackend`(调用下述 method channel)+ 上层 UI,在插件方法签名定稿后对接。
- **对接约定**:只要 method channel 的**方法名**与**入参/返回 JSON 字段**与本文档表格一致,上下层即可无缝对上。
- **隔离纪律**:自研插件只允许被 `LocalSafBackend` 一个类 import;UI、聊天 @文件、agent 一律只依赖 `WorkspaceBackend` 抽象。将来换插件 / 优化原生层,改动只发生在 `LocalSafBackend` 一处。

## 2. 数据结构

### 2.1 FileInfo

```
FileInfo {
  name:        String              // 文件名(不含路径),如 "main.dart"
  path:        String              // 见 §3.1;Android 上是完整 content:// URI
  uri:         String              // 同 path(保留字段,方便上层语义区分)
  size:        Long                // 字节;directory 时为 0
  type:        'file' | 'directory'
  mtime:       Long                // epoch ms;SAF provider 可能返回 0(表示未知)
  ctime:       Long?               // epoch ms;SAF 大量 provider 返回 null
  mimeType:    String?             // SAF 返回的 mime;directory 为 "vnd.android.document/directory"
  isHidden:    Boolean             // 名字以 "." 开头
  permissions: String?             // SAF 几乎拿不到 unix mode 位,Android 上始终 null;保留字段供 iOS 用
}
```

### 2.2 SelectedFileInfo

```
SelectedFileInfo extends FileInfo {
  displayPath: String?             // SAF treeUri 解析出的"友好路径",形如 "/storage/emulated/0/Documents/MyProject"
                                   // 仅用于 UI 展示(面包屑、最近打开),不可作为后续 API 入参
}
```

> 时间单位统一为 **epoch milliseconds**;`0` 表示 provider 未提供该值,`null` 表示在当前平台不可用。

---

## 3. 通用约定(v2 新增)

### 3.1 path / URI 规范

SAF 没有 unix-style 路径,本插件统一约定:

- **所有方法的 `path` 参数都是完整的 `content://` URI**。根目录是 `treeUri`,子节点是 `treeUri` + documentId 派生出的 `child URI`。
- **子节点 URI 必须用** `DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentDocId)` / `buildDocumentUriUsingTree(treeUri, childDocId)` 派生,**禁止字符串拼接**。
- `displayPath` 仅用于 UI 显示,**不可回传到任何 API**。
- `path` 本身自带 tree 信息,跨方法调用无需额外的 `workspaceId` 入参。

> Dart 侧 `WorkspaceBackend` 抽象层应当保留这层语义:抽象出的 `Path` 是 `(workspaceUri, childUri)` 对,不是裸字符串。原生插件这一层接收的就是 URI 字符串。

### 3.2 错误码

所有方法失败时统一抛 `PlatformException`,`code` 取以下枚举:

| code | 含义 | 触发场景 |
|---|---|---|
| `E_NO_PERMISSION` | 无权限 | 未授权,或用户事后撤销了授权 |
| `E_URI_STALE` | URI 失效 | 用户在系统文件管理器删了文件 / 移走了目录 |
| `E_NOT_FOUND` | 路径不存在 | 路径解析后找不到 DocumentFile |
| `E_INVALID_ARG` | 入参非法 | `path` 不是 content URI、`startLine > endLine` 等 |
| `E_IO` | 一般 IO 错误 | 读写失败、流被打断 |
| `E_OUT_OF_SPACE` | 磁盘满 | 写入时容量不足 |
| `E_TOO_LARGE` | 超过 size 上限 | `readFile` 全量读取超过 §3.3 限制 |
| `E_RANGE_CONFLICT` | rangeHash 不匹配 | 用于 `readFileRange` 之后乐观锁写入失败(P2 `applyDiff`) |
| `E_NOT_SUPPORTED` | 平台不支持 | 当前 OS / SDK 版本不支持该方法 |
| `E_USER_CANCELLED` | 用户取消 | `openSystemFilePicker` 用户点了取消 |

`message` 返回人类可读说明;`details` 可携带 `{ uri, cause }` 等上下文。

### 3.3 数值约定

- **行号**:1-based,**闭区间**。`startLine=1, endLine=3` 表示 1、2、3 共 3 行。
- **`readFile` size 上限**:**10 MB**;超过抛 `E_TOO_LARGE`,调用方必须改用 `readFileRange` 或 `readFileBytes`(见 P1)。
- **`rangeHash` 算法**:`sha256`,输入 = 范围内行的原始字节(保留 LF / CRLF,不归一化),输出 = 小写 hex 字符串。
- **encoding**:`'utf8'` | `'base64'`。二进制建议走 `base64`,但**更推荐 P1 的 `readFileBytes`** 直接走 `ByteData` 通道,避免 33% 膨胀。
- **入参不做转义**:URI 内部的 `%2F` 等转义由插件内部处理,调用方原样传整个 URI。

### 3.4 SAF 已知限制(必读)

| 限制 | 说明 | 应对 |
|---|---|---|
| **无 inotify** | SAF 不支持文件变更通知 | `capabilities.canWatch = false`;Dart 抽象的 `watch()` 抛 `UnsupportedError` |
| **持久化 URI 上限 ≈128** | `takePersistableUriPermission` 在多数 ROM 是 128(部分 256/512) | P0 提供 `releasePersistableUriPermission`,切换工作区时主动释放旧的 |
| **`'both'` 不存在** | Android `ACTION_OPEN_DOCUMENT_TREE` 与 `ACTION_OPEN_DOCUMENT` 是两个 Intent,无法合并 | `openSystemFilePicker.type` **不接受 `'both'`**,要选两种就分两次调 |
| **permissions 字段无效** | SAF 拿不到 unix mode 位 | `FileInfo.permissions` 在 Android 始终 `null` |
| **ctime 大量为 null** | SAF provider 多数不返回创建时间 | `FileInfo.ctime` 可空,UI 容错显示 |
| **大目录遍历慢** | `DocumentFile.listFiles()` 每个子项都要 `ContentResolver` 查询 N 次 | `listDirectory` **必须用 `ContentResolver.query(children URI)` 一次取完**,禁用 `DocumentFile.listFiles()` |
| **跨 tree move 不支持** | 不同 treeUri 之间 `DocumentsContract.moveDocument` 行不通 | `moveFile` 跨 tree 时回退到 copy + delete |

---

## 4. 方法清单(按优先级分档)

### P0 —— 第一步必须(选目录 + 只读浏览 + 工作区权限管理)

| 方法 | 入参 | 返回 | 说明 |
|---|---|---|---|
| `echo(opts)` | `{value}` | `{value}` | 连通性自测(从 P2 提前到 P0,跑通 channel 用) |
| `requestPermissions()` | — | `{granted, message}` | 触发 SAF 选目录授权 |
| `checkPermissions(opts)` | `{uri?}` | `{granted, message}` | 检查指定 `uri` 是否有持久化权限;不传 `uri` 时检查是否至少有一个已持久化 tree |
| `openSystemFilePicker(opts)` | `{type:'file'\|'directory', multiple, accept?, startDirectory?, title?}` | `{files[], directories[], cancelled}` | 调系统选择器;选目录拿 treeUri **并 `takePersistableUriPermission` 持久化**。**`type` 不接受 `'both'`**(见 §3.4) |
| `listPersistedPermissions()` | — | `{uris: SelectedFileInfo[]}` | 列出所有已持久化的 treeUri,用于 UI 渲染"已授权工作区列表" |
| `releasePersistableUriPermission(opts)` | `{uri}` | void | 释放一个 treeUri 的持久化权限;**切换工作区时务必主动释放旧的**(避免触顶 128) |
| `listDirectory(opts)` | `{path, showHidden, sortBy:'name'\|'size'\|'mtime'\|'type', sortOrder:'asc'\|'desc'}` | `{files: FileInfo[], totalCount}` | 列目录;实现走 `ContentResolver.query(children URI)`,**禁用 `DocumentFile.listFiles()`** |
| `readFile(opts)` | `{path, encoding:'utf8'\|'base64'}` | `{content, encoding, size}` | 读文件;超过 §3.3 的 10 MB 抛 `E_TOO_LARGE` |
| `getFileInfo(opts)` | `{path}` | `FileInfo` | 单个文件/目录元信息 |
| `exists(opts)` | `{path}` | `{exists}` | 路径是否存在 |

> P0 关键点:
> 1. 选目录后**必须 `takePersistableUriPermission`**,否则重启 App 工作区失效。
> 2. `listPersistedPermissions` + `releasePersistableUriPermission` 是为了避免触顶 128 个 URI 上限。
> 3. `listDirectory` 实现细节决定整个体验:**用 `ContentResolver.query`**,不要走 `DocumentFile.listFiles()`(后者 N 个子项查 N 次,大目录会卡死)。
> 4. "当前活跃工作区"是 UI 层概念,**由 Dart 侧维护**(存 SharedPreferences),不进插件 API。

### P1 —— 工作区写操作 + agent 编辑能力(做 agent 前必须补齐)

| 方法 | 入参 | 返回 | 说明 |
|---|---|---|---|
| `writeFile(opts)` | `{path, content, encoding, append}` | void | 写/追加文件 |
| `createFile(opts)` | `{parentPath, name, content?, encoding?, mimeType?}` | `{path}` | 在父目录下新建文件,返回新文件的 URI |
| `createDirectory(opts)` | `{parentPath, name, recursive}` | `{path}` | 新建目录,返回新目录 URI |
| `deleteFile(opts)` | `{path}` | void | 删文件 |
| `deleteDirectory(opts)` | `{path, recursive}` | void | 删目录;SAF 默认非递归,`recursive` 行为由插件实现 |
| `renameFile(opts)` | `{path, newName}` | `{path}` | 重命名(走 `DocumentsContract.renameDocument`),返回新 URI |
| `moveFile(opts)` | `{sourcePath, destinationParent}` | `{path}` | 移动;跨 tree 时回退 copy+delete(§3.4) |
| `copyFile(opts)` | `{sourcePath, destinationParent, newName?, overwrite}` | `{path}` | 复制 |
| `readFileRange(opts)` | `{path, startLine, endLine, encoding?}` | `{content, totalLines, startLine, endLine, rangeHash}` | **按行范围读** — 大文件/agent 必备;hash 算法见 §3.3 |
| `readFileBytes(opts)` | `{path, offset?, length?}` | `{bytes: ByteData}` | 二进制/大文件按字节读,避免 base64 膨胀 |
| `getLineCount(opts)` | `{path}` | `{lines}` | 行数 |
| `getFileHash(opts)` | `{path, algorithm:'md5'\|'sha256'}` | `{hash, algorithm}` | 全文件 hash;改前校验/防冲突 |

### P2 —— agent 高级编辑 + 检索(可后置,建议最终对齐原版)

| 方法 | 入参 | 返回 | 说明 |
|---|---|---|---|
| `insertContent(opts)` | `{path, line, content}` | void | 指定行前插入(1-based) |
| `replaceInFile(opts)` | `{path, search, replace, isRegex?, replaceAll?, caseSensitive?}` | `{replacements, modified}` | 查找替换 |
| `applyDiff(opts)` | `{path, diff, format:'unified'\|'search-replace', createBackup?, expectedRangeHash?}` | `{success, linesChanged, linesAdded, linesDeleted, backupPath?}` | **打 diff** — agent 改文件主力。`format` 决定 diff 解析方式,**原版用 `search-replace`,首选实现这个**;`expectedRangeHash` 不匹配抛 `E_RANGE_CONFLICT` |
| `searchFiles(opts)` | `{directory, query, searchType:'name'\|'content'\|'both', fileTypes[], maxResults, recursive}` | `{files[], totalFound}` | 全文/文件名检索 |
| `openSystemFileManager(opts)` | `{path?}` | void | 跳系统文件管理器 |
| `openFileWithSystemApp(opts)` | `{path, mimeType?}` | void | 用系统 App 打开 |

---

## 5. 来源与平台说明

- **契约来源**:原版 Web 的 Capacitor 插件接口 `AdvancedFileManagerPlugin`(`AetherLink/src/shared/types/fileManager.ts`),共 23 个方法。原版的 agent 工具(`file-editor` MCP server 的 16 个工具:`read_file / write_to_file / insert_content / apply_diff / list_files / search_files / replace_in_file / ...`)底层调的就是这套——**实现了这套,agent 工具链将来零障碍接入**。
- **平台**:以上为安卓 SAF 契约。**先做安卓**,iOS 后置。iOS 实现时的差异点:
  - iOS 用 `UIDocumentPicker` + security-scoped bookmark,每次访问 bookmark 路径前都要 `startAccessingSecurityScopedResource` / `stopAccessingSecurityScopedResource`(原生封装即可,不影响 channel API)。
  - iOS 没有 SAF 的 children URI 概念,需要在原生层重建目录树语义。
  - iOS 同样无 inotify,`canWatch` 也是 false。
  - iOS 持久化 bookmark 没有 128 上限问题,但要处理 bookmark 失效后的 `bookmarkDataIsStale` 重续场景。

---

## 附录 A:原版方法对照表(实现时填充)

| 本规格方法 | 原版方法(`AdvancedFileManagerPlugin`) | 入参差异 | 备注 |
|---|---|---|---|
| `echo` | `echo` | — | |
| `requestPermissions` | `requestPermissions` | — | |
| ... | ... | ... | 实现 P0 时按原版 `fileManager.ts` 逐项填充 |

---

> 实现建议:从 P0 的 `echo` + `openSystemFilePicker` + `listDirectory` 三个方法切入,跑通 method channel + SAF 授权 + 目录列举主线,再按表格逐项补全。
