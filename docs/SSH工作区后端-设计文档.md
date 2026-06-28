# SSH 工作区后端（RemoteSshBackend）设计文档

> 状态：设计草案（未实现）。
> 目标读者：Aetherlink 开发者。
> 结论先行：**先做 `RemoteSshBackend`（`dartssh2` 的 SFTP + PTY），Termux 用户在 Termux 里跑 `sshd` 连 `127.0.0.1:8022` 即可零额外后端代码复用同一实现。** SSH 比 Termux intent 方案更简单、更干净，且与既有 `WorkspaceBackend` 抽象天然契合。

本文承接：
- 《工作区与智能体模式-设计构想》§2.3 ②③ / §2.4（②③ 协议层一致，远端协议做一次两端共用）；
- 《本地SAF工作区插件-方法规格》（SAF 后端的方法契约，本文逐条对照差异）。

---

## 1. 为什么先做 SSH（而非 Termux）

| 维度 | SSH（`dartssh2`） | Termux（intent 方案） |
|---|---|---|
| 文件 API | **SFTPv3 结构化 API**，`listdir/open/read/write/stat/rename/remove/mkdir` 与 `WorkspaceBackend` 近 1:1 | 无结构化 API，每个文件操作拼 shell + 解析输出 |
| 路径 | 普通 posix path（比 SAF 的 opaque `content://` 还好处理） | posix path，但要靠 `ls -la` 解析 |
| 终端 | PTY shell channel，库原生支持 | `RUN_COMMAND` intent，输出靠重定向文件，异步别扭 |
| 沙箱 | 无关（走 TCP） | App **读不到** `/data/data/com.termux`（不同 UID） |
| 用户配置 | 填主机/端口/账号/密钥 | 需在 Termux 改 `allow-external-apps=true` + 授权 |
| 依赖 | 一个纯 Dart 包 | Android intent 管线 + manifest 权限 |

**Termux 白嫖结论**：做完 SSH 后端后，Termux 用户执行 `pkg install openssh; sshd`（默认监听 `127.0.0.1:8022`），在本 App 里新建一个 host=`127.0.0.1` port=`8022` 的 SSH 工作区即可——**Termux = 一个本地 SSH 目标，零额外后端代码**。若以后要真正零配置的 Termux（不让用户开 sshd），再单独做 intent 版 `TermuxBackend` 不迟。

---

## 2. 依赖选型：`dartssh2`

- 版本：`dartssh2: ^2.18.0`（发布于约 2 周前，verified publisher `terminal.studio`）。
- 能力：纯 Dart；SSH 会话（exec / shell / PTY / env）；认证（**password / private key / interactive**）；**SFTP**（完整 SFTPv3：list/read/write/stat/rename/remove/mkdir/symlink…）；端口转发。
- 平台：Android / iOS / Linux / macOS / Windows（纯 Dart，无原生插件依赖）。
- 传输：默认 `SSHSocket.connect()` 走 `dart:io` 原生 TCP（移动端 OK；Web 需自定义 transport，本期不考虑）。
- 风险：纯 Dart 实现的加解密在超大文件传输上不如原生 OpenSSH 快；host key 校验需自己接（见 §9）。

> 隔离纪律（沿用 SAF 规格 §1）：**只有 `lib/features/workspace/data/remote_ssh_backend.dart` 允许 `import 'package:dartssh2/dartssh2.dart'`。** 其余 UI / chat / agent 代码只依赖 `WorkspaceBackend` 抽象。新增一条 import 白名单守护（见 §11）。

---

## 3. 现有接口盘点与映射总表

`WorkspaceBackend`（`lib/features/workspace/domain/workspace_backend.dart`）现有方法 → SSH 实现策略：

| 方法 | SSH 实现 | 备注 |
|---|---|---|
| `echo` | `client.run('echo ...')` 或连通性自检 | 验证通道 |
| `verifyAccess(path)` | SFTP `stat(root)` 成功即 true | 连接失效/被拒 → false |
| `listDir(path)` | SFTP `openDir` / `readdir` | 直映射 |
| `readFile(path)` | SFTP `open(read)` 全量读 + utf8 decode；>cap 抛错 | 与 SAF 同 10MB 上限语义 |
| `readFileBytes(offset,length)` | SFTP 随机读（`read(offset,length)`） | 二进制嗅探用 |
| `getFileInfo(path)` | SFTP `stat` → `WorkspaceEntry` | mtime/size/isDir |
| `getLineCount(path)` | 小文件客户端读计数；大文件 `wc -l`（exec） | 见 §6 |
| `readFileRange(s,e)` | 客户端读 + 行切片 + `rangeHash`（sha256） | **Dart 侧实现**，见 §6 |
| `writeFile(append?)` | SFTP `open(write/append)` | 直映射 |
| `createFile` | SFTP `open(create|excl)` + 写 content | 返回新 path |
| `createDirectory(recursive?)` | SFTP `mkdir`；recursive 逐级建 | |
| `delete(isDir,recursive?)` | SFTP `remove` / `rmdir`；recursive 需递归删 | |
| `rename` | SFTP `rename` | 同目录改名 |
| `move` | SFTP `rename`（跨目录） | 同分区直接 rename |
| `copy` | SFTP 无原生 copy → 读写流式复制（目录递归） | 见 §6 |
| `insertContent(line)` | **Dart 侧**读-改-写 | 见 §6 |
| `replaceInFile` | **Dart 侧**搜索替换（regex/字面） | 见 §6 |
| `applyDiff` | **Dart 侧** search/replace + unified，含 `expectedRangeHash` 乐观锁 | 见 §6 |
| `searchFiles` | 远端 `grep -rl` / `find`（exec），或客户端遍历 | 见 §6 |
| `watch()` | 应用内事件总线（同 SAF）；外部变更可选轮询/`inotifywait` | 见 §7 |
| `capabilities` | `canExec=true, canWatch=true, isRemote=true` | |

**关键洞察**：SAF 把 `applyDiff/replaceInFile/insertContent/readFileRange/rangeHash` 做在**原生插件**里；SSH 没有插件。这些"文件文本智能"必须有 Dart 实现。

> **建议**：抽一个**后端中立的共享文本工具** `lib/features/workspace/domain/workspace_text_ops.dart`（纯 Dart，零 IO，输入旧文本+参数 → 输出新文本/结果），承载 `applyDiff / replaceInFile / insertContent / readFileRange / rangeHash / countLines`。SSH 后端用它做读-改-写；未来其它非插件后端也能复用；且纯函数**好单测**。SAF 仍走原生（性能/大文件优势），保持不变。

---

## 4. 连接模型与生命周期

### 4.1 后端实例的形态

现状：`localSafBackendProvider` 是 **keepAlive 单例**（SAF 插件 Dart 侧无状态）。SSH 不同——**每个连接是有状态的 `SSHClient`**，必须按"连接"维度持有，且要管理建立/断开/重连。

```dart
// 设想：按工作区(host+port+user+root 唯一)持有一个连接
@riverpod
class RemoteSshBackends ... // family or 自管池
```

落地建议：
- `workspaceBackendProvider(workspace)`（现 family，ssh 分支当前抛错）改为：ssh → 返回 `RemoteSshBackend`，其内部持有/惰性建立 `SSHClient` + `SftpClient`。
- 连接惰性建立（首次 IO 时 connect）；断线后下次调用自动重连；`dispose` 时 `client.close()`。
- 一个工作区一个连接；多个 SSH 工作区各自独立连接。
- **复用一条 SSH 连接同时承载 SFTP（文件）与 shell（终端）**（dartssh2 支持在同一 client 上开多通道），省一次握手。

### 4.2 连接状态对 UI 的暴露

新增连接态（disconnected / connecting / connected / error）供：
- 文件树/编辑器 loading 与错误态；
- `verifyAccess` 走 SFTP `stat(root)`，供工作区管理页「授权已失效」徽标（复用现有健康检查机制）。

---

## 5. 数据模型变更

### 5.1 `Workspace` 扩展连接参数

现 `Workspace`（`domain/workspace.dart`）只有 `id/name/backendType/root/displayPath/lastOpenedAt`，`root` 对 SAF 是 `content://`。SSH 需要 host/port/username/认证方式。两条路线：

- **(A) 复用 `root` 编码为 URI**：`ssh://user@host:port/abs/path`。优点：不改 `Workspace` 结构。缺点：解析脆弱，认证信息混入。
- **(B) `Workspace` 增加可选 `connection` 子对象**（host/port/username/authType/keyId…），`root` 仅存远端绝对路径。**推荐 (B)**：结构清晰，凭据与连接解耦。

> 注意 `WorkspaceStore.open()` 现以 `(backendType, root)` 判重；引入 connection 后判重键要含 host/port/user。

### 5.2 凭据安全存储（必须决策）

- 现状：项目**无 `flutter_secure_storage`**，LLM API key 走明文 Drift KV。
- SSH 密码/私钥比 API key 更敏感，**不能进明文「最近打开」JSON**。
- **建议**：引入 `flutter_secure_storage`（Android Keystore / iOS Keychain 后端），SSH 秘密（password / private key / passphrase）按 `keyId` 存其中；`Workspace.connection` 只存非秘密参数 + `keyId` 引用。
- 备选：若想零新依赖，至少把秘密单独存、不随 recent 列表导出/备份（注意 backup feature 不应导出它）。

---

## 6. 需要 Dart 侧自研的文件文本能力（重点工作量）

放进 §3 建议的 `workspace_text_ops.dart`（纯函数，单测覆盖）：

- `readFileRange`：按 `\n` 切行，取 `[start,end]`，算该段 `sha256` 作 `rangeHash`（与 SAF 语义一致：乐观锁 token）。
- `insertContent(line)`：在第 N 行前插入。
- `replaceInFile`：字面/regex、replaceAll、caseSensitive，返回替换数。
- `applyDiff`：
  - `searchReplace` 格式（与 SAF 的 SEARCH/REPLACE 块一致）；
  - `unified` 格式（标准 unified diff 应用）；
  - `expectedRangeHash` + `rangeStartLine/EndLine` 乐观锁：写前重算该段 hash，不一致抛冲突（对齐 SAF 的 `E_RANGE_CONFLICT`）。
- `copy`（目录递归）：SFTP 无原生 copy，流式读写；大目录注意并发与进度。
- `searchFiles`：
  - 内容搜索优先远端 `grep -rl`（快），名称搜索 `find`（exec）；
  - 或纯 SFTP 客户端遍历（无 exec 依赖，但慢）。本期 SSH 必有 exec，**用远端 shell**。
- `getLineCount`：小文件客户端计数；大文件 `wc -l`（exec）。

> 这些逻辑做成纯函数后，SAF 路径不受影响（继续走原生），只有 SSH（及未来后端）用它。

---

## 7. watch / canWatch

沿用刚落地的「应用内事件总线」契约（`WorkspaceBackend.watch()` 返回 `Stream<WorkspaceChangeEvent>`）：

- **应用内变更**：`RemoteSshBackend` 在自身 write/create/delete/rename/move/copy/insert/replace/applyDiff 后 `_emit` 事件（与 `LocalSafBackend` 完全一致）→ 文件树/编辑器实时刷新。`canWatch=true`。
- **外部变更**（远端他人/进程改文件）：SSH 有 exec，可选两条增强（非首期）：
  - 轮询当前打开目录（`stat`/`ls` diff）；
  - 远端 `inotifywait`（若装了 inotify-tools）经 shell channel 推流 → 真正的远端文件监听（这正是 §canWatch 注释里预留的「Termux/SSH 真 inotify」）。

---

## 8. 终端 exec（PTY）

> **接口缺口**：当前 `WorkspaceBackend` 抽象**没有 `exec`/terminal 方法**，只有 `capabilities.canExec`。要做 SSH 终端必须给抽象补 exec 能力。

建议新增（设计构想 §2.2 早有此意）：

```dart
/// 在工作区里起一个交互式 shell（PTY）。canExec=false 的后端抛 UnsupportedError。
WorkspaceShellSession startShell({String? cwd, int cols, int rows});
// session: stdout/stderr 流 + write(stdin) + resize(cols,rows) + kill + done/exitCode
```

- SSH：`client.shell(pty: SSHPtyConfig(...))` 直接映射，`resize` → `session.resizeTerminal`。
- UI：工作区**第三页（现「终端占位」）**接一个终端 widget（输入框 + 等宽输出 + ANSI 解析）。可调研 `xterm`（Dart 终端组件，与 dartssh2 同生态常配套）。
- HITL/安全：exec = 远程执行命令，UI 要明确这是真实副作用（尤其 isRemote）。

---

## 9. 安全

- **凭据存储**：见 §5.2（secure storage）。
- **Host key 校验**：dartssh2 不自动信任。采用 **TOFU（首次信任并记住指纹）**：首次连接展示指纹让用户确认 → 存指纹；后续比对，变更则告警（防中间人）。指纹同样进 secure storage / 专表。
- **连接超时 / 重试**：connect / 每次 IO 设超时，避免 UI 卡死。
- **私钥保护**：支持带 passphrase 的私钥；passphrase 也进 secure storage。
- **备份隔离**：backup feature 不得导出 SSH 秘密与 host key。

---

## 10. UI 变更

1. **打开入口**（`open_workspace_sheet.dart`）：现 Termux/SSH 是「敬请期待」占位（已加回）。SSH 改为可点 → 弹**连接配置表单**（host / port / username / 认证方式：密码或私钥 / 远端起始路径）→ 测试连接 → 存 `Workspace`(+connection,+keyId) → 设为当前。
2. **编辑器可写判断解耦**：`file_editor.dart` 现用 `ref.read(workspacePreviewBackendProvider) is LocalSafBackend` 判 `_writable`。SSH 也可写 → 改为**能力判断**（如新增 `capabilities.canWrite`，或判断非只读后端）。这是接入 SSH 的硬改点。
3. **工作区管理页**（`workspace_management_page.dart`）：`_backendLabel` 已有 `Termux/SSH` 标签；健康检查（`verifyAccess`）对 SSH = SFTP `stat(root)`；「重新授权」对 SSH = 重新填连接/换密钥（语义对齐 rebind）。
4. **路径展示**（`readable_path.dart`）：非 SAF 返回原样 posix path（已支持）。

---

## 11. 隔离纪律与架构守护

- 仅 `data/remote_ssh_backend.dart` 可 import `dartssh2`；新增一条断言（参照 SAF：可在 `import_boundaries_test.dart` 同级加一个「插件 import 白名单」测试，或扩展现有架构测试）。
- 不破坏跨 feature 边界：SSH 后端落在 `features/workspace/`，UI/chat/agent 仍只依赖 `domain/workspace_backend.dart`。
- `workspace_text_ops.dart` 放 `domain/`（纯 Dart 契约层），任何后端可用。

---

## 12. 测试策略

- **纯函数单测**（最高 ROI）：`workspace_text_ops`（applyDiff 两格式 / replace / insert / readFileRange+rangeHash / 乐观锁冲突 / countLines）。
- **后端事件总线单测**：仿 `local_saf_backend_watch_test.dart`，注入假 SFTP/transport 验证各变更方法 `_emit` 正确事件。
- **SFTP 映射单测**：用假 `SftpClient`（或 dartssh2 的可注入 socket）验证 listDir/read/write 调用与 `WorkspaceEntry` 转换。
- **集成测试（可选/手动）**：本机起 `sshd`（或 Docker `linuxserver/openssh-server`）做端到端连通、读写、终端冒烟。
- **安全单测**：host key TOFU 比对、凭据不落明文 recent。

---

## 13. 分阶段落地计划

> 每阶段独立可合并、可验证；先打通只读，逐步加写/终端。

- **SSH-0 依赖与接缝**：加 `dartssh2`；`workspace_text_ops.dart` 纯函数 + 单测；`workspaceBackendProvider` ssh 分支不再抛错（返回未连接的 `RemoteSshBackend`）。
- **SSH-1 只读浏览**：连接配置表单 + 凭据安全存储 + host key TOFU；SFTP `listDir/readFile/readFileBytes/getFileInfo/stat`；文件树/查看器走真连接。`verifyAccess`。
- **SSH-2 写与编辑**：SFTP 写族 + `workspace_text_ops` 接 `applyDiff/replace/insert/readFileRange`；编辑器 `_writable` 解耦为能力判断；事件总线 `_emit`（实时刷新）；`searchFiles`（远端 grep/find）。
- **SSH-3 终端**：抽象新增 `startShell`/`WorkspaceShellSession`；SSH PTY 接入；第三页终端 UI（`xterm` 调研）。
- **SSH-4（可选）外部监听**：`inotifywait` / 轮询补 `watch` 外部变更。
- **Termux 复用**：文档化「Termux 跑 sshd → 新建 127.0.0.1:8022 SSH 工作区」；UI 上 Termux 入口可直接走 SSH 配置（预填 localhost:8022）或保留占位。

---

## 14. 未决策点（请拍板）

1. **凭据存储**：引入 `flutter_secure_storage`（推荐）还是沿用现明文 KV？
2. **连接参数落点**：`Workspace.connection` 子对象（推荐）还是 `ssh://` URI 编码进 `root`？
3. **Termux 入口**：占位提示「请在 Termux 开 sshd」并跳 SSH 配置，还是单独做 intent 版 `TermuxBackend`？
4. **终端组件**：用 `xterm` 还是自绘最小终端？
5. **首期范围**：先到 SSH-1（只读）/ SSH-2（可写）/ 还是直奔含终端的 SSH-3？

---

## 15. 一句话总结

> 用 `dartssh2` 的 **SFTP + PTY** 实现 `RemoteSshBackend`，SFTP 近 1:1 映射现有 `WorkspaceBackend`，把 SAF 原生独有的 applyDiff/replace/range 智能抽成**共享纯 Dart 文本工具**；凭据走 secure storage + host key TOFU；终端给抽象补 `startShell`。做完 SSH，Termux 跑个 sshd 即白嫖。
