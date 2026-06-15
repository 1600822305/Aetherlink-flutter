# ADR-0007：平台能力层——买成熟插件、按能力拆接口、范围裁剪

- **状态**：Accepted（**Refines `ARCHITECTURE.md` §6**：把其中「一个胖 `UnifiedPlatformApi` facade 聚合子 API」细化为「按能力拆成独立接口、各自注入、不要聚合 god-facade」。与 **ADR-0006** 形成对照：LLM 层全自写，平台层反过来买插件——同一套判据，结论相反。）
- **日期**：2026-06-15
- **决策者**：Kenneth + 架构师会话

## 背景（Context）
M3 要落 `ARCHITECTURE.md` §6 的「平台能力层」：让上层（聊天发图、复制消息、导出会话、通知…）只依赖抽象，平台差异收口在一处。动工前要把三件事拍死：**自写还是买插件、接口是一个胖 facade 还是按能力拆、M3 到底做哪几样**。

原项目实测（`1600822305/Aetherlink`）：

- 平台能力**全靠 Capacitor 插件**，`package.json` 里 ≈ 19 个：`@capacitor/filesystem`(15 处引用)、`/clipboard`(8)、`/camera`(6)、`/share`(4)、`/toast`(4)、`/local-notifications`、`/device`(3)、`/haptics`(2)、`/browser`(2)、`@capacitor-community/speech-recognition`、`/text-to-speech`、`@capawesome/capacitor-file-picker`、`/status-bar`、`/preferences`、`/network` 等。**没有一行自写的原生 channel**——这恰恰是它做对的地方。
- `src/shared/services/platform/` 那几个文件（`SafeAreaService` 372 行、`StatusBarService` 328 行、`MobilePasteService` 94 行、`harmonyos/*`）**几乎全是 webview/Capacitor 的框架税**：边到边/状态栏/安全区/大文本粘贴都是「网页套壳」才有的坑。Flutter 原生有 `SafeArea` 组件、`SystemChrome`、原生 `TextField`，**这些坑根本不存在**——属补丁三分类的 ①，**扔**，不迁。
- 真正值得保留的，是它那套**能力分类法**（filesystem / notifications / clipboard / device / camera…）和「上层不碰具体插件」的抽象意图——`ARCHITECTURE.md` §6 已经把它平移成 Dart `abstract class UnifiedPlatformApi { ... get fileSystem; get notifications; ... }`。

两个待定细节：① §6 画的是**一个胖 facade**（`UnifiedPlatformApi` 持有一堆子 API getter），胖 facade 容易长成 god-interface、且强迫只用剪贴板的代码也拖着整个平台层；② §6 列了 6 类能力，但 M3 不必一次全做。

## 选项（Options）

**A. build-vs-buy：**
1. **买成熟插件**（`path_provider` / `share_plus` / `image_picker` / `flutter_local_notifications` / `device_info_plus` / `file_picker` / `flutter_tts` / `speech_to_text`…）+ Flutter SDK 自带的 `Clipboard`/`HapticFeedback`/`SystemChrome`，**全部藏在我们自己的接口后面**。
2. 自写 `MethodChannel`，逐 OS（Android/iOS/macOS/Windows/Linux）写原生 channel 代码。

**B. 接口形态：**
1. **按能力拆**成独立接口（`FileSystemApi` / `ClipboardApi` / `ShareApi` / …），各自一个 Riverpod provider，上层只依赖它要的那一个；**不要聚合 facade**。
2. 胖 `UnifiedPlatformApi` facade 聚合所有子 API（§6 原图、对齐原项目）。

**C. M3 范围：**
1. **只做聊天黄金路径要用的子集**，其余延后。
2. §6 列的 6 类一次做全。

## 决策（Decision）
选 **A1 + B1 + C1**：

- **买插件，不自写 channel。** 平台能力一律用成熟 pub.dev 插件 / Flutter SDK 自带 API 实现，藏在我们自己的接口后面。**不写 `MethodChannel`**（除非某能力在所有候选插件里都没有，且确属必需——那时单独再评，不在 M3 默认路径）。
- **按能力拆接口，不要 god-facade。** `core/platform/` 下每类能力一个纯 Dart 抽象接口；每个接口一个 Riverpod provider；上层 `ref.watch` 它真正需要的那一个。**删掉**现有骨架里那个空的聚合 `UnifiedPlatformApi`（`lib/core/platform/unified_platform_api.dart` 的 `TODO(M3)`）——它就是要被本 ADR 拆掉的胖 facade。
- **M3 只做聊天黄金路径子集**，其余延后到真正要用的里程碑。

### 划线规则一（M3 范围：做哪几样）
**M3 做（聊天主流程直接要用）：**
- `FileSystemApi`：附件读写、会话/数据导入导出（`path_provider` + `dart:io`，选文件用 `file_picker`）。
- `ClipboardApi`：复制消息 / 粘贴（Flutter SDK 自带 `Clipboard`，**零插件**；接口照样要，便于测试替身 + 不让 UI 直接耦合 `flutter/services`）。
- `ImagePickerApi`：拍照 / 相册选图（多模态发图，`image_picker`）。
- `ShareApi`：分享 / 导出消息（`share_plus`）。
- `DeviceInfoApi`（薄）：平台判定 + 基本设备信息（`device_info_plus`；平台分支统一走这里，**不许**在上层散落 `Platform.isAndroid`）。

**M3 不做（延后，到对应里程碑再开）：**
- `NotificationApi`（`flutter_local_notifications`）、`HapticsApi`（SDK 自带 `HapticFeedback`）、`TtsApi`/`SttApi`（`flutter_tts`/`speech_to_text`）——增强项，等语音/通知功能落地再做。
- 状态栏 / 安全区 / 边到边：**不是平台能力层的事**，是 UI 外壳关注点，归 M4/M5 的 presentation（Flutter 用 `SafeArea`/`SystemChrome` 内建解决，原项目那两个大 Service 是框架税，不迁）。
- HarmonyOS 专属那套：超出当前目标平台，不做。

### 划线规则二（接口与实现怎么摆）
- **接口纯 Dart**：`core/platform/<capability>_api.dart` 只声明抽象方法，**不许 import 任何插件包**（让它待在 domain 能依赖的干净侧；同 `domain` 一样过边界测试）。
- **实现挨着接口放**：`core/platform/impl/`（如需按平台分叉，再 `_mobile`/`_desktop` 或用条件导入），**只有实现文件 import 插件**。
- **注入靠 Riverpod**：每个能力一个 provider，按平台给不同实现；上层只认接口。
- **测试**：因为上层只依赖接口，单测用 fake 实现即可，不碰真实平台通道。

### 边界（与 ADR-0005 的区别）
`core/platform` 是**纯叶子基础设施**：features 依赖它，它**绝不反向 import features**。所以它**不需要**像 `core/database` 那样开 narrow 例外（ADR-0005）——边界规则 4（`core/shared ✗→ features`）对它**原样成立**，交接时盯死，别让任何平台实现去 import feature。

### 抽象判据（沿用 ADR-0006 那条，换个场景）
> 这个能力的「难点」是不是**我们的差异化**，且第三方抽象**跟不上它的变化**？是 → 自写（如 LLM 的流式/线协议）。否，是标准化、稳定、各家都在用的 OS 能力 → 买（平台层）。

平台能力的难点是**逐 OS 的原生 channel 样板代码**，纯属无差异化的脏活累活，且 OS API 稳定、插件成熟联邦化——所以买。这跟 ADR-0006 结论相反，但用的是同一把尺子。

## 理由（Rationale）
- **原项目自己就是这么干的**（19 个 Capacitor 插件、零自写 channel），且这部分没烂——烂的是 webview 框架税（SafeArea/StatusBar/HarmonyOS），那些 Flutter 根本不需要。照搬「买 + 抽象」的对的部分，扔掉框架税。
- **自写 channel = 烧钱无收益**：5 个 OS × N 个能力的原生样板，社区插件已经维护得好好的，自己写只会多一堆要跟 OS 升级的债。
- **按能力拆 > 胖 facade**：只用剪贴板的代码不该被迫拖着相机/通知；拆开后每个能力可独立换插件、独立测、独立加平台分叉，不会长成下一个 god-interface（正是迁移要根治的病）。
- **范围裁剪**：M3 只铺 M4 真要用的能力，避免为「以后可能用」的 TTS/STT 提前空铺一层——和 §M2「先做流式聊天、Responses/工具后续追加」一个节奏。

## 后果（Consequences）
- 正面：平台差异收口在 `core/platform`；上层零 `Platform.isXxx` 散落；换插件不影响上层；每能力可独立测（fake 接口）；M3 体量可控。
- 负面 / 代价：引入若干第三方插件依赖（每个都是一份维护面 + 潜在 OS 升级跟进），用插件成熟度 + 维护活跃度筛选来对冲；按能力拆 → 接口文件数变多（可接受，每个都小而清晰）。
- **护栏（加新东西时照这个走，别破）：**
  1. 上层**不许**直接 import 平台插件或写 `Platform.isAndroid`——一律走 `core/platform` 的能力接口。
  2. 新增能力先判：黄金路径现在要用吗？要 → 加一个**能力接口 + provider**；不要 → 延后，别提前空铺。
  3. 平台实现**只能**待在 `core/platform/impl`，且**绝不** import features（边界规则 4，无例外）。
  4. 某能力没有合适插件时，才考虑自写 `MethodChannel`——**单独评估、单独记**，不是默认路径。
  5. UI 外壳关注点（安全区/状态栏/窗口/快捷键）**不进**平台能力层，归 presentation（M4/M5）。
- **对既有文档的影响**：本 ADR refine 了 `ARCHITECTURE.md` §6 的「胖 facade」画法（改为按能力拆）。§6 是设计示意、非 ADR，以本 ADR 为准；骨架文件 `lib/core/platform/unified_platform_api.dart` 的空聚合接口在 M3 实现时删除/替换为各能力接口。
- 未来若要推翻的触发条件：出现一个成熟、活跃、跨全平台覆盖我们所有能力的统一 Dart 平台库（则可收敛回单依赖）；或某能力的插件生态长期失修、被迫转自写（则那一项单独立 ADR）。
