# SSH 工作区后端（RemoteSshBackend）设计文档

> 状态：**实施中** —— SSH-0（接缝，commit `3f67b50`）、SSH-1（只读浏览，commit
> `1eabec4`）、SSH-2（写/编辑）、SSH-3（AI exec / `run_command`）、SSH-3b（人类
> PTY 终端，`xterm`）已落地并入主干；SSH-4（外部监听）与 Termux 一键接入未开始。
> 详见 §13 进度标注。
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

## 10.5 Termux 一键接入（已决策：两条路并存，用户自选）

Termux 工作区 = SSH 后端连 Termux 里的 `sshd`（§1 白嫖）。问题只剩"怎么把 Termux 的 sshd 配好"。**100% 零操作做不到**（Termux 安全模型所限），但可做到"装好 Termux + 一步"。**决策：两种自动化方式都提供，让用户按自己情况选。**

打开菜单的「Termux」入口点开后，先检测是否已装 Termux（package 查询），再让用户在两种方式间选：

### 方式 A：粘一行命令（推荐小白，无需任何权限）
- app 生成 SSH 密钥对（私钥留本地，按 §5.2 存），把**公钥**嵌进一段一次性 setup 脚本；
- 引导用户复制一行命令在 Termux 里执行（脚本可内置/分享到共享存储，离线可用）：
  ```bash
  bash <(下载或读取 aetherlink-termux-setup.sh)
  ```
- 脚本自动完成：`pkg install -y openssh` → 写 `~/.ssh/authorized_keys`（**免密码**）→ 配置并启动 `sshd`（默认 `127.0.0.1:8022`）→ `termux-services` + Termux:Boot 设自启/保活 → `termux-wake-lock`；必要时 `termux-change-repo` 换镜像。
- **不需要 `allow-external-apps`**（是用户自己跑脚本，不是外部 app 遥控）。

### 方式 B：全自动 RUN_COMMAND（高级，省去粘命令）
- 需用户先开一次 `allow-external-apps=true`（app 给引导 + 复制命令）；app manifest 声明 `com.termux.permission.RUN_COMMAND`。
- 之后 app 用 `RUN_COMMAND` intent 依次代跑上面那串步骤（装包/写公钥/起 sshd/设自启），全程无需用户敲命令。

### 两方式共同收尾
- 配好后 app **自动新建** `host=127.0.0.1 / port=8022 / 密钥认证` 的 `SshConnection` + 指向它的 Termux 工作区，立即可用；`backendType` 记 `termux`（与纯 SSH 区分展示），但底层复用 `RemoteSshBackend`。

### 坑（影响成功率，UI 要提示）
- **Termux 必须 F-Droid/GitHub 版**（Play 版已废弃，RUN_COMMAND/包管理跑不通）。
- **保活**：Android 杀后台会断 sshd → 依赖 Termux:Boot + wake-lock + 让用户关 Termux 电池优化。
- **首次联网装包**：`pkg install` 需网络，国内可能要换镜像源。

> 实现优先级：方式 A 先做（限制最少、对小白最稳）；方式 B 作为「高级」选项随后补。原生零配置 `TermuxBackend`（intent 直接做文件/exec、完全不用 sshd）仍是另一条重活，按需再议。

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

- **SSH-0 依赖与接缝** ✅（commit `3f67b50`）：加 `dartssh2 ^2.18.0`；`SshConnection` 实体 + `SshConnectionStore` + `Workspace.connectionId` 字段（含 fromJson/toJson 迁移）；`workspace_text_ops.dart` 纯函数 + 单测；`workspaceBackendProvider` ssh 分支不再抛错（返回未连接的 `RemoteSshBackend`）；新增 dartssh2 import 白名单守护测试。
- **SSH-1 只读浏览** ✅（commit `1eabec4`）：连接配置表单（填写新连接 → 测试连接 → host key TOFU 指纹确认 → 建工作区并切换）+ 凭据明文 KV（独立键 `workspace_ssh_credentials`，按 `credentialKeyId` 引用，已排除备份导出）；`SshBackendPool` 按 `connectionId` 池化复用一条 transport；SFTP `listDir/readFile/readFileBytes/getFileInfo/verifyAccess`（`readFileRange/getLineCount` 复用 `workspace_text_ops`）；文件树/查看器走真连接，SSH 文件自动只读。
  - 实现注记：① ~~复用已有 `SshConnection`（同服务器开多工作区）尚未在表单暴露，目前每次新建连接~~ → **已补**：连接表单顶部列出已有连接，点选 + 填路径即开工作区（不新建连接/凭据）；② ~~管理页对 SSH 的健康检查徽标 / 「重新授权」(=编辑连接) 未接，列为后续打磨~~ → **已补**：健康检查对 SSH/Termux 走 SFTP `stat(root)`（连接池复用），「重新授权」对 SSH = 弹编辑连接表单（预填 host/凭据 → 测试并保存 → 失效连接池重连）；③ dartssh2 host key 回调给的是 OpenSSH `SHA256:<base64>` 指纹（已据 2.18.0 源码确认），TOFU 直接存该串；④ 顺手修了 `openRecent`/`rebind` 丢 `connectionId` 的隐患（SSH 工作区重开/重绑后能正确解析连接）。
- **SSH-2 写与编辑** ✅：SFTP 写族（`writeFile/createFile/createDirectory(recursive)/delete(recursive)/rename/move/copy(目录递归)`）+ `workspace_text_ops` 接 `insertContent/replaceInFile/applyDiff`（读-改-写，`applyDiff` 含乐观锁 + 可选 `.bak` 备份）；每个变更 `_emit` 事件（树/编辑器实时刷新）；`WorkspaceCapabilities.canWrite` 落地，编辑器 `_writable`/`_save`、文件树 file-ops、`workspace_file_ops` 三处门槛由 `is LocalSafBackend` 解耦为 `capabilities.canWrite`（mock=false）。
  - 实现注记：`searchFiles` 本期走 **SFTP 客户端递归遍历**（name/content/both + 扩展名过滤 + `maxResults` 截断），不依赖 exec；待 SSH-3 有 exec 后可改远端 `grep -rl`/`find` 提速。
- **SSH-3 AI 命令执行（重点）** ✅：抽象新增 `exec()` + `WorkspaceExecResult`（默认 `UnsupportedError`，SAF 显式不支持）；SSH 经 exec 通道 `client.execute`（**非 PTY**，分离 stdout/stderr/exitCode，`cd <cwd> &&` 注入工作目录、`timeout` 到则 `SSHSignal.KILL`）；新内置工具 `run_command` 挂在 `@aether/file-editor` 服务下（复用其路由与 HITL），标 **high risk** 走确认网关（`fileEditorRiskLevel`），确认摘要展示命令；`workspace` 参数可选（默认当前工作区），`cwd`/`timeout_ms` 可选。**无终端 UI 依赖。**
  - 实现注记：① `run_command` 复用 file-editor 服务（而非另起 `@aether/terminal` 服务），最小化对 chat/MCP 路由与设置页的改动；语义上它是「工作区智能体」的一员。② 顺带修复了 `builtin_tools_test` 在主干上的失活（缺 `tools/tools.dart` barrel 导入导致整文件不编译，掩盖了 `runBuiltinTool` 已改 async、`kLocallyRunnableBuiltins` 已扩容两处陈旧断言）。
- **SSH-3b 人类交互式终端** ✅：抽象新增 `startShell()` + `WorkspaceShellSession`（后端中立：`output` 字节流 / `write` / `resize` / `done` / `close`，默认 `UnsupportedError`）；SSH 经 `client.shell(pty: SSHPtyConfig)` 起 PTY，`_SshShellSession` 合并 stdout+stderr 为广播字节流、映射 write/resize/close（dartssh2 不出此文件）；工作区第三页换成终端 UI（`xterm 4.0.0`，同 `terminal.studio`），**懒启动**（显式「启动终端」按钮，不在进区时偷偷开 SSH 通道），canExec=false 时显示「终端仅在 SSH/Termux 工作区可用」。
- **SSH-4（可选）外部监听**：`inotifywait` / 轮询补 `watch` 外部变更。
- **Termux-A 一键接入（粘命令）**：app 生成密钥 + setup 脚本；Termux 入口引导一行命令自动装 openssh/写公钥/起 sshd/保活 → 自动建 127.0.0.1:8022 密钥认证工作区（底层复用 `RemoteSshBackend`）。见 §10.5 方式 A。
- **Termux-B 全自动（RUN_COMMAND，可后置）**：引导开 `allow-external-apps` + manifest 权限，app 用 intent 代跑全部步骤。见 §10.5 方式 B。

---

## 14. 未决策点（请拍板）

1. ~~**凭据存储**：引入 `flutter_secure_storage` 还是沿用现明文 KV？~~ → **已决策：首期明文 KV（独立键 + 排除备份），secure storage 列为后续硬化项。**
2. ~~**连接参数落点**：内嵌子对象还是 URI？~~ → **已决策：方案 C — 独立 `SshConnection` 实体 + `Workspace.connectionId` 引用（可复用、好扩展），见 §5.1。**
3. ~~**Termux 入口**~~ → **已决策：Termux = SSH 连 Termux sshd；自动化提供两种方式让用户自选（A 粘一行命令、无需权限，先做；B RUN_COMMAND 全自动、需 allow-external-apps，随后补），app 自动生成密钥免密码登录。见 §10.5。** 原生 intent 版 `TermuxBackend` 列为按需后续。
4. ~~**终端组件**~~ → **已澄清：终端主要给 AI（一次性 exec，无 UI），人类交互式 PTY 次要、可后置；终端组件（`xterm`）仅在 SSH-3b 人类终端阶段才需要。** 见 §8。
5. ~~**首期范围**：先到 SSH-1（只读）/ SSH-2（可写）/ SSH-3（AI exec）/ 还是含人类终端的 SSH-3b？~~ → **已决策：首期做到 SSH-1（只读浏览）。** SSH-0 / SSH-1 均已落地（见 §13），SSH-2 起按需续做。

---

## 15. 一句话总结

> 用 `dartssh2` 的 **SFTP + PTY** 实现 `RemoteSshBackend`，SFTP 近 1:1 映射现有 `WorkspaceBackend`，把 SAF 原生独有的 applyDiff/replace/range 智能抽成**共享纯 Dart 文本工具**；凭据首期明文 KV（独立键 + 排除备份，后期可换 secure storage）+ host key TOFU；终端以 **AI 一次性 `exec`（新 MCP 工具 + HITL）为主**、人类交互式 PTY 为次（可后置）。做完 SSH，Termux 跑个 sshd 即白嫖。
