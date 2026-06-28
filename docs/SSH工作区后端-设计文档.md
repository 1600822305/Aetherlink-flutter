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
// 按 SshConnection.id（而非工作区）持有一个 SSHClient —— 多个指向同一连接的
// 工作区共享同一条 transport（呼应 §5.1 方案 C 的连接复用）。
@riverpod
class RemoteSshClients ... // keyed by connectionId，自管连接池
```

落地建议：
- `workspaceBackendProvider(workspace)`（现 family，ssh 分支当前抛错）改为：ssh → 返回 `RemoteSshBackend(connectionId)`，其内部惰性建立/复用 `SSHClient` + `SftpClient`。
- **连接按 `connectionId` 池化复用**：同一服务器上多个工作区共用一条 SSH 连接，不重复握手。
- 连接惰性建立（首次 IO 时 connect）；断线后下次调用自动重连；连接无引用时 `client.close()`。
- **一条 SSH 连接同时承载 SFTP（文件）与 shell（终端）**（dartssh2 支持在同一 client 上开多通道），省握手。

### 4.2 连接状态对 UI 的暴露

新增连接态（disconnected / connecting / connected / error）供：
- 文件树/编辑器 loading 与错误态；
- `verifyAccess` 走 SFTP `stat(root)`，供工作区管理页「授权已失效」徽标（复用现有健康检查机制）。

---

## 5. 数据模型变更

### 5.1 连接落点（已决策：方案 C — 独立连接实体 + 引用）

现 `Workspace`（`domain/workspace.dart`）只有 `id/name/backendType/root/displayPath/lastOpenedAt`，`root` 对 SAF 是 `content://`。SSH 还需要 host/port/username/认证方式。考虑过三种落点：

- **(A) 复用 `root` 编码为 URI**（`ssh://user@host:port/abs/path`）：不改结构，但解析脆弱、语义混乱、认证信息混入。**否决。**
- **(B) `Workspace` 内嵌 `connection` 子对象**：清晰，但同一服务器多工作区会重复连接信息，改一处要改多份。
- **(C) 独立 `SshConnection` 实体 + `Workspace.connectionId` 引用**：**采用**。借鉴企业级做法（VS Code Remote-SSH / JetBrains Gateway / Termius）——连接是可复用的一等公民，多个工作区共享一份连接；改端口/凭据一处生效。

**数据模型：**

```dart
/// 一个可复用的 SSH 连接档案。多个 Workspace 可按 id 引用同一连接。
class SshConnection {
  final String id;            // 稳定 id（generateId('ssh')）
  final String label;         // 展示名，如 "我的 VPS"
  final String host;
  final int port;             // 默认 22
  final String username;
  final SshAuthType authType; // password | privateKey
  final String credentialKeyId; // → 指向独立 KV 里的秘密（见 §5.2），非秘密本身
  final String? hostKeyFingerprint; // TOFU 记住的指纹（非秘密，普通 KV）
  // 预留（首期不做）：jumpHost / keepAliveSec / ...
}

class Workspace {
  // 现有字段不变……
  final String root;          // SSH 下 = 远端绝对路径，如 /home/alice/project
  final String? connectionId; // SSH 工作区指向一个 SshConnection；SAF 为 null
}
```

- `SshConnection` 列表与「最近打开」一样，存进 Drift KV（独立键，如 `workspace_ssh_connections`），用一个 `SshConnectionStore` 管增删改查。
- `root` 语义统一为"路径"；连接信息全在 `SshConnection` 里。
- **秘密不进 `SshConnection`**：只存 `credentialKeyId`，秘密本体在独立 KV 键（§5.2）。

> 判重：`WorkspaceStore.open()` 现以 `(backendType, root)` 判重；SSH 工作区改为 `(backendType, connectionId, root)`。
>
> 暂不做的企业级特性（列为后续）：读 `~/.ssh/config`、系统 `known_hosts`、ssh-agent、跳板机 ProxyJump、SSH 证书、连接池多路复用工程化。首期 `SshConnection` 结构已为它们预留扩展位。

### 5.2 凭据存储（已决策：先明文，后期按需加密）

**结论**：首期**不引入加密**，SSH 秘密与现有 LLM API key 保持一致走明文 Drift KV；
secure storage 作为可选的后续硬化项，有需求时再统一上（API key + SSH 一起迁）。

理由：
- 这是开源个人客户端——用户把自己机器的凭据存在自己手机上，威胁面有限；Android 已按 UID 沙箱隔离，别的 app 读不到 app 数据。
- 项目现状 LLM API key 即明文存；只给 SSH 单独加密反而不一致。
- 零新依赖、零包体增量、实现更快。
- "代码开源"与加密无关（secure storage 的安全来自系统 Keystore，非算法保密）。

首期必须做到的**最低防护**（成本几乎为零）：
- SSH 秘密（password / private key / passphrase）虽明文存，但**必须排除出 backup / 导出功能**（这是明文方案下最大的真实泄露面：`adb backup`/云备份带出 DB）。检查 `features/backup/` 不导出 SSH 凭据键。
- 秘密单独存（独立 KV 键，按 `credentialKeyId` 引用），不混进 `SshConnection` / 「最近打开」JSON——将来迁 secure storage 时只换存取实现，`SshConnection` 结构不动。
- 私钥优先支持带 passphrase。

后续硬化（非首期）：引入 `flutter_secure_storage`（Android Keystore / iOS Keychain），把 `keyId → 秘密` 的存取换成它即可，上层无感。

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

## 8. 命令执行：AI 一次性 exec（主）+ 人类交互式 PTY（次）

> **定位**：移动端"终端"**主要给 AI 用，用户也能用**——这是两种执行模型，优先级不同。
>
> **接口缺口**：当前 `WorkspaceBackend` 抽象**没有任何执行方法**，只有 `capabilities.canExec`。需补两个能力。

### 8.1 AI 一次性 exec（重点、先做）

AI agent 的需求是「跑一条命令 → 拿干净可解析的输出」，**不要 PTY**（PTY 会混入 ANSI 转义/交互提示，难解析）。

```dart
/// 一次性执行一条命令并收集结果。canExec=false 的后端抛 UnsupportedError。
Future<WorkspaceExecResult> exec(
  String command, {
  String? cwd,        // 默认工作区 root
  Duration? timeout,  // 防止挂死
});
// WorkspaceExecResult: { stdout, stderr, exitCode }
```

- SSH 实现：`client.runWithResult()` / `execute()`（**非 PTY**），分离 stdout/stderr + exitCode；`cwd` 用 `cd <cwd> && <command>` 或 session 起始目录；超时到则 `kill`。
- **接入方式 = 新内置 MCP 工具**（如 `@aether/terminal` 的 `run_command`），路由到 `WorkspaceBackend.exec()`，输出回灌给模型。
- **HITL**：exec 比写文件更高危，**必须走确认网关**（复用现有 `fileEditorNeedsConfirmation` 那套 HITL 机制），标 high risk。
- 不需要任何终端 UI 组件 —— 这条路径最简单、价值最高。

### 8.2 人类交互式 PTY（次、可后置）

```dart
/// 起一个交互式 shell（PTY），给人类终端 UI 用。
WorkspaceShellSession startShell({String? cwd, int cols, int rows});
// session: stdout/stderr 流 + write(stdin) + resize(cols,rows) + kill + done/exitCode
```

- SSH：`client.shell(pty: SSHPtyConfig(...))`，`resize` → `session.resizeTerminal`。
- UI：工作区**第三页（现「终端占位」）**接终端 widget（输入框 + 等宽输出 + ANSI 解析），调研 `xterm`（Dart 终端组件，dartssh2 同生态常配套）。
- 这部分依赖 xterm + ANSI 渲染，工程量大于 8.1，**排在 AI exec 之后**。

### 8.3 复用同一连接

8.1 与 8.2 都在同一条 `SSHClient` 上开通道（§4.1 池化），不额外握手。

---

## 9. 安全

- **凭据存储**：见 §5.2（首期明文 KV + 排除备份；secure storage 列为后续硬化）。
- **Host key 校验**：dartssh2 不自动信任。采用 **TOFU（首次信任并记住指纹）**：首次连接展示指纹让用户确认 → 存指纹；后续比对，变更则告警（防中间人）。指纹存普通 KV 即可（非秘密）。
- **连接超时 / 重试**：connect / 每次 IO 设超时，避免 UI 卡死。
- **私钥保护**：支持带 passphrase 的私钥。
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
- **安全单测**：host key TOFU 比对、凭据存独立 KV 键且不混进「最近打开」JSON、备份导出不含凭据键。

---

## 13. 分阶段落地计划

> 每阶段独立可合并、可验证；先打通只读，逐步加写/终端。

- **SSH-0 依赖与接缝**：加 `dartssh2`；`SshConnection` 实体 + `SshConnectionStore` + `Workspace.connectionId` 字段（含 fromJson/toJson 迁移）；`workspace_text_ops.dart` 纯函数 + 单测；`workspaceBackendProvider` ssh 分支不再抛错（返回未连接的 `RemoteSshBackend`）。
- **SSH-1 只读浏览**：连接配置表单（建/选 `SshConnection`）+ 凭据明文 KV（独立键 + 排除备份）+ host key TOFU；按 `connectionId` 池化连接；SFTP `listDir/readFile/readFileBytes/getFileInfo/stat`；文件树/查看器走真连接。`verifyAccess`。
- **SSH-2 写与编辑**：SFTP 写族 + `workspace_text_ops` 接 `applyDiff/replace/insert/readFileRange`；编辑器 `_writable` 解耦为能力判断；事件总线 `_emit`（实时刷新）；`searchFiles`（远端 grep/find）。
- **SSH-3 AI 命令执行（重点）**：抽象新增 `exec()` + `WorkspaceExecResult`；SSH 非 PTY `runWithResult`（cwd / timeout）；新内置 MCP 工具 `run_command` 路由到 backend.exec，走 HITL 确认（high risk）。**无终端 UI 依赖。**
- **SSH-3b 人类交互式终端（可后置）**：抽象新增 `startShell`/`WorkspaceShellSession`；SSH PTY；第三页终端 UI（`xterm` + ANSI 渲染）。
- **SSH-4（可选）外部监听**：`inotifywait` / 轮询补 `watch` 外部变更。
- **Termux 复用**：文档化「Termux 跑 sshd → 新建 127.0.0.1:8022 SSH 工作区」；UI 上 Termux 入口可直接走 SSH 配置（预填 localhost:8022）或保留占位。

---

## 14. 未决策点（请拍板）

1. ~~**凭据存储**：引入 `flutter_secure_storage` 还是沿用现明文 KV？~~ → **已决策：首期明文 KV（独立键 + 排除备份），secure storage 列为后续硬化项。**
2. ~~**连接参数落点**：内嵌子对象还是 URI？~~ → **已决策：方案 C — 独立 `SshConnection` 实体 + `Workspace.connectionId` 引用（可复用、好扩展），见 §5.1。**
3. **Termux 入口**：占位提示「请在 Termux 开 sshd」并跳 SSH 配置，还是单独做 intent 版 `TermuxBackend`？
4. ~~**终端组件**~~ → **已澄清：终端主要给 AI（一次性 exec，无 UI），人类交互式 PTY 次要、可后置；终端组件（`xterm`）仅在 SSH-3b 人类终端阶段才需要。** 见 §8。
5. **首期范围**：先到 SSH-1（只读）/ SSH-2（可写）/ SSH-3（AI exec）/ 还是含人类终端的 SSH-3b？

---

## 15. 一句话总结

> 用 `dartssh2` 的 **SFTP + PTY** 实现 `RemoteSshBackend`，SFTP 近 1:1 映射现有 `WorkspaceBackend`，把 SAF 原生独有的 applyDiff/replace/range 智能抽成**共享纯 Dart 文本工具**；凭据首期明文 KV（独立键 + 排除备份，后期可换 secure storage）+ host key TOFU；终端以 **AI 一次性 `exec`（新 MCP 工具 + HITL）为主**、人类交互式 PTY 为次（可后置）。做完 SSH，Termux 跑个 sshd 即白嫖。
