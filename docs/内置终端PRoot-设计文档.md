# 内置终端（PRoot Linux 环境）— 设计文档

> 状态：设计稿 v2（初稿 + 可行性评审修订）
> 目标读者：Aetherlink 开发者
> 结论先行：**以 PRoot + 云端拉取 rootfs 的方式为 App 内置一个零依赖的本地 Linux 终端，作为 `WorkspaceBackend` 家族的新成员（`ProotLocalBackend`），与已有的 SAF / SSH / Termux-SSH 后端并列。APK 体积增量 ≈ 2MB，环境按需下载，模式与 PDFium 引擎一致。**

---

## 0. 背景与动机

### 0.1 现状

- 工作区已有三类后端（见《工作区与智能体模式-设计构想》§2.3）：
  - ① `LocalSafBackend` — 本地文件，`canExec = false`
  - ③ `RemoteSshBackend` — 远程 SSH，`canExec = true`
  - ② Termux 联动 — 通过 `TermuxSetup` 一键脚本把 Termux 变成 localhost SSH 目标，复用 ③，零新后端代码
- 但「能跑命令」的两条路都有前置门槛：
  - Termux 路线：用户必须自己安装 Termux（Play 上没有）、跑一次接入脚本
  - SSH 路线：用户必须有自己的服务器 / 电脑

### 0.2 目标

给所有用户一个**开箱即用、零外部依赖**的本地命令执行环境：

1. 不要求安装 Termux 或任何外部 App
2. 不显著增加 APK 体积（对标 PDFium：引擎云端拉取，按需下载）
3. 兼容 Google Play（不降 targetSdk）
4. 上层（终端 UI、聊天工具调用、未来的 Agent）通过现有 `WorkspaceBackend` 抽象使用，零改动

### 0.3 非目标

- 不做全功能 TUI 兼容（vim/tmux 级别的复杂 TUI 优化不在 P0 范围；但**最简 PTY 是 P0 必需**，见 §2.5 —— 现有终端页是交互式 xterm，无 PTY 则 shell 无提示符、无行编辑，页面不可用）
- 不替代 Termux / SSH 后端 —— 三者并存，用户可选
- iOS 不做本地终端（系统限制，iOS 只走 SSH 远程，见 §7）

---

## 1. 技术选型

### 1.1 为什么是 PRoot

Android 10+（targetSdk ≥ 29）SELinux 禁止执行/加载应用数据目录中下载的二进制（`execve` / `dlopen` 均被拦截）。只有 APK `jniLibs` 解出的原生库允许执行。因此：

| 方案 | APK 增量 | 性能 | Play 兼容 | 结论 |
|---|---|---|---|---|
| A. targetSdk 28 直接 exec | ~0 | 100% 原生 | ❌ | 弃（全 App 降级代价太大） |
| B. 终端插件 APK（targetSdk 28） | 0（独立分发） | 100% 原生 | 主 App ✅ | 后续可选增强，非 P0 |
| **C. PRoot 打进 jniLibs** | **~2MB** | 计算 ≈ 原生；syscall 密集 -20~50% | ✅ | **✅ 采用** |

PRoot 原理：代码指令直接在 CPU 原生执行，仅通过 `ptrace` 拦截系统调用做路径改写 —— 不是模拟器。对 AI 执行脚本 / 跑 Python / 装包等场景体感接近原生。UserLAnd、Andronix 均为此路线且已上架 Play。

### 1.2 rootfs 选型：Alpine Linux

| 候选 | 大小 | 包管理 | libc | 结论 |
|---|---|---|---|---|
| **Alpine** | **~8MB** | apk（~5 万包） | musl | **✅ P0 采用**（最小、下载快） |
| Ubuntu Base | ~30MB | apt | glibc | 备选（兼容性最好，后续可作为可选环境） |
| Termux bootstrap | ~30MB | pkg/apt | bionic | 弃（其路径布局依赖 Termux 前缀，且授权协议需评估） |

rootfs 托管：优先 GitHub Releases 官方镜像直链 + UI 支持自定义直链（国内云盘），与 `PdfiumEngineManager.defaultDownloadUrl` 的做法一致。

### 1.3 打包与下载清单

| 物料 | 大小 | 位置 |
|---|---|---|
| PRoot 二进制（arm64/armeabi-v7a） | ~2MB | APK `jniLibs`（`libproot.so`） |
| PRoot loader（`libproot-loader.so`，32 位设备另需 `libproot-loader32.so`） | ~100KB | APK `jniLibs`，随 proot 一起 |
| Alpine minirootfs | ~8MB | 首次使用时云端下载 |
| 初始化包（python3、curl、git 等） | 按需 | 首次初始化时 `apk add` |

落盘目录：`getApplicationSupportDirectory()/terminal/`（与 pdfium 同级），卸载随应用清除。

### 1.4 打包硬性前提（评审补充）

1. **`android:extractNativeLibs="true"`**：`Process.start` 需要 `libproot.so` 在
   `ApplicationInfo.nativeLibraryDir` 下是**真实文件路径**。现代 AGP 默认
   `useLegacyPackaging = false`（.so 不解压、直接从 APK mmap），该模式下拿不到
   可 exec 的文件路径。必须在 manifest / gradle 显式开启 legacy packaging，
   代价是安装后占用体积略增（jniLibs 双份），需在 release 配置里确认。
2. **运行时环境变量**：proot 需要 `PROOT_TMP_DIR` 指向应用私有可写目录
   （SELinux 禁止用 `/tmp`）；`PROOT_LOADER` 指向 jniLibs 里的 loader 路径。
3. **二进制来源按 ABI 成套**：proot 与 loader 必须同一构建产物、按
   arm64-v8a / armeabi-v7a 各放一套（复用 `platformArchSuffix` 的判断模式选
   rootfs 下载地址）。

---

## 2. 架构设计

### 2.1 分层与模块划分

沿用工作区的既有纪律：**上层只依赖抽象，具体实现收敛在单个 data 文件**。

```
lib/features/terminal/                     ← 新 feature（终端引擎与会话管理）
├── domain/
│   ├── terminal_engine.dart               ← 引擎状态、安装/初始化模型（纯 Dart，可单测）
│   ├── terminal_session.dart              ← 会话实体（id、cwd、环境变量、存活状态）
│   └── proot_command_builder.dart         ← PRoot 启动命令拼装（纯字符串，可单测）
├── application/
│   ├── terminal_engine_manager.dart       ← 引擎生命周期单例（对标 PdfiumEngineManager）
│   │     · isInstalled() / download() / installFromBytes()（支持手动导入）
│   │     · initialize()（解压 rootfs、写标记文件、首次 apk add）
│   ├── terminal_session_controller.dart   ← 会话池：创建/复用/销毁长驻 shell 进程
│   └── terminal_providers.dart            ← Riverpod 装配
├── data/
│   └── proot_process_runner.dart          ← 唯一碰 Process/平台通道的文件（隔离纪律）
└── presentation/mobile/
    └── terminal_setup_sheet.dart          ← 首次引导：下载/导入/自定义直链（对标 pdfium_engine_setup_sheet）

lib/features/workspace/
└── data/proot_local_backend.dart          ← 新增第 4 个 WorkspaceBackend 实现
      · canExec = true, isRemote = false
      · exec() / startShell() 委托给 terminal feature 的会话池
      · 文件操作直接走 dart:io（rootfs 内是普通 POSIX 路径，无需 SAF）
```

> 评审修订：终端 UI **不需要新写** —— 现有
> `workspace/presentation/mobile/workspace_terminal_page.dart` 已用 xterm 渲染
> 后端中立的 `WorkspaceShellSession`（bytes in / bytes out），`ProotLocalBackend`
> 实现 `startShell()` 后该页自动可用，初稿里的 `terminal_page.dart` 取消。

### 2.2 与现有 `WorkspaceBackend` 的关系

```
WorkspaceBackend（接口，不变）
├── LocalSafBackend      本地文件            canExec=false
├── RemoteSshBackend     远程 SSH            canExec=true, isRemote=true
│     └── Termux-SSH     （TermuxSetup 接入，复用 SSH 后端）
└── ProotLocalBackend    ★ 新增：内置 Linux   canExec=true, isRemote=false
```

- 上层（文件树、编辑器、聊天 @文件、未来 Agent）**零修改**即可用新后端：
  `exec()`（一次性命令，供 AI `run_command`）与 `startShell()`（交互式 PTY，
  供终端页）两个入口接口里都已定义
- 工作区起始屏的「终端」入口卡从「敬请期待」变为真实可用
- 用户在工作区起始屏自选后端：本地文件夹 / 内置终端 / Termux / SSH —— 有合理默认值（内置终端），高级选项不强迫选择

### 2.3 进程模型

```
App 进程
 └── ForegroundService（执行期间保活）
      └── proot 进程（libproot.so，经 forkpty 挂 PTY）
           └── /bin/sh（Alpine rootfs 内，长驻会话）
                ├── stdin  ← 命令写入
                └── stdout/stderr → 流式读出（Stream<ExecOutput>）
```

- **长驻会话池**：默认保留 1 个长驻 shell（毫秒级复用，避免重复初始化）；Agent 并发时按需扩容，上限可配
- **超时与取消**：每次 exec 带超时（默认 120s，可配）；取消 = 向进程组发 SIGKILL
- **保活**：执行期间起前台服务 + 通知；无任务 N 分钟后自动释放进程
- **前台服务合规（评审补充）**：Android 14+（targetSdk ≥ 34）要求在 manifest
  声明 `foregroundServiceType`（本场景用 `dataSync` 或 `specialUse`）及对应
  `FOREGROUND_SERVICE_*` 权限，Play 上架需填写前台服务使用声明。这部分清单 /
  Kotlin 改动计入 P1 工作量。

### 2.4 首次安装流程（对标 PDFium 引导）

```
用户首次进入终端 / AI 首次调用 exec
  → 检查 .setup_done 标记
     ├── 已就绪 → 直接启动 shell（秒开）
     └── 未就绪 → 弹 terminal_setup_sheet：
          1. 下载 rootfs（默认官方直链，可换国内直链 / 手动导入 .tar.gz）
          2. 解压到 terminal/rootfs/
          3. 首次初始化：配置 apk 源（可选国内镜像）→ 安装基础包
          4. 写 .setup_done + 版本标记
```

关键点（回应「每次连接都要重新下载」的问题）：**下载与初始化只发生一次**。rootfs 与所有已装的包永久落盘，之后每次都是标记检查 → 启动进程，秒开。

### 2.5 PTY 通道（评审补充，P0 必需）

Dart 的 `Process.start` 只给管道、**不分配 PTY**。无 PTY 时 shell 检测到
stdin 非 tty：无提示符、无行编辑、`top`/`vi` 等直接不可用，现有 xterm 终端页
形同虚设。因此 P0 需要一小段原生代码：

- Kotlin/JNI 侧提供 `forkpty()`（或 `posix_openpt` + `fork/exec`）启动 proot，
  返回 master fd；通过 MethodChannel/EventChannel 暴露 read/write/resize/kill
- Dart 侧包装成 `WorkspaceShellSession`（`output` / `write` / `resize` /
  `done` / `close`），与 SSH 后端的会话实现同构
- `exec()`（一次性命令）不需要 PTY，可继续走 `Process.start` 管道，保持
  stdout/stderr 分离、输出干净可解析（与接口注释的约定一致）

---

## 3. 聊天 / AI 工具接入

新增聊天工具（走现有 skills / MCP 同一注册通道）：

| 工具 | 说明 |
|---|---|
| `terminal_execute` | 在内置终端执行命令，流式返回 stdout/stderr + exit code |
| `terminal_session_*`（P1） | 会话管理：新建/列出/关闭 |

安全边界（沿用工作区设计文档 §4 的 HITL 原则）：

- 默认**白名单审批模式**：AI 发起的命令先在气泡中展示，用户点「运行」才执行（对标现有高危工具的 HITL 门）
- 设置里可切「自动执行」（信任模式），并支持命令黑名单（`rm -rf /` 等模式拦截）
- rootfs 天然是沙箱：AI 只能碰 rootfs 内部与显式挂载的目录，碰不到 App 数据与用户相册

---

## 4. 实施计划

### P0 — 最小闭环（先跑通再谈体验）

1. `terminal_engine_manager`：下载/解压/标记/版本管理（复制 PdfiumEngineManager 的骨架）
2. `proot_command_builder` + `proot_process_runner`：能启动 Alpine shell、执行单条命令拿到输出（含单测）
3. jniLibs 集成 PRoot（arm64 + armeabi-v7a 预编译二进制 + loader）+
   开启 `extractNativeLibs`（§1.4）
4. **PTY 原生通道**（§2.5）：forkpty 启动 proot、MethodChannel 桥接
5. `terminal_setup_sheet` 首次引导 UI
6. `ProotLocalBackend` 实现 `startShell()` 接入现有 `workspace_terminal_page`

### P1 — 会话与 AI 接入

7. 长驻会话池 + 前台服务保活（含 manifest `foregroundServiceType` 合规，§2.3）
8. `terminal_execute` 聊天工具 + HITL 审批气泡
9. `ProotLocalBackend` 补齐文件族接口（dart:io 直读 rootfs，文件树可浏览）

### P2 — 体验增强（可选）

10. apk 源选择（国内镜像）、常用环境一键装（python / node / git）
11. TermuxBackend（RUN_COMMAND intent，检测到已装 Termux 时可切换，原生性能）
12. 插件 APK 模式（targetSdk 28 独立分发，追求 100% 原生的用户可选）

---

## 5. 风险与对策

| 风险 | 对策 |
|---|---|
| PRoot 在部分 ROM 上 ptrace 被限制（如某些魔改内核） | 启动时自检（跑 `echo ok`），失败则引导用户走 Termux / SSH 后端 |
| 部分厂商 ROM 激进杀后台，连带杀掉 ptrace 子进程链 | 前台服务大幅缓解；配合启动自检与任务结果落盘兜底 |
| rootfs 下载源在国内不可达 | UI 支持自定义直链 + 手动导入（与 PDFium 一致） |
| 后台被杀导致长任务中断 | 前台服务 + 通知；任务结果落盘，重启可查看 |
| syscall 密集任务慢（如 npm install） | 文档明示预期；重活引导用户用 SSH 后端 |
| `extractNativeLibs=true` 使安装后体积增大 | 增量仅 proot+loader（~2MB 级），可接受；上架前实测确认 |
| 32 位设备（armeabi-v7a）rootfs 需单独一份 | 按 ABI 选下载地址（复用 `platformArchSuffix` 的判断模式） |
| musl 与个别 Python 轮子不兼容 | 优先 apk 源的预编译包；必要时提供 Ubuntu rootfs 作为可选环境（P2） |

---

## 6. 明确的决策点（需要拍板）

1. **rootfs 默认发行版**：Alpine（8MB，musl）还是 Ubuntu Base（30MB，glibc 兼容性好）？→ 建议 P0 用 Alpine，P2 加 Ubuntu 可选
2. **PRoot 二进制来源**：自编译（termux/proot 源码，可控）还是取现成产物（快）？→ 建议先用 termux/proot 的 release 产物验证，P1 时纳入自编译流程
3. **AI 执行默认策略**：默认审批（安全）还是默认自动（体验）？→ 建议默认审批，设置可关
4. **前台服务通知文案与常驻策略**：执行期间常驻还是任务级起停？→ 建议任务级起停

---

## 7. 跨平台说明（iOS）

iOS 无 fork/exec 权限、禁止动态下载可执行代码，本地终端不可行（iSH 的 x86 模拟方案工程量与性能都不可接受）。iOS 版终端能力 = 仅 `RemoteSshBackend`（连用户服务器 / 电脑）。本设计中所有上层代码（终端 UI、聊天工具、Agent）都面向 `WorkspaceBackend` 编程，iOS 上自动只暴露 SSH 选项，无需分叉代码。

---

## 8. 一句话总结

> 把「能跑命令」的门槛降到零：PRoot（2MB，打进 APK）+ Alpine rootfs（8MB，云端拉取、一次落盘），
> 以 `ProotLocalBackend` 的身份加入现有 `WorkspaceBackend` 家族，
> 上层与未来 Agent 零修改；Termux / SSH 继续作为进阶选项并存。
