# DEX 引擎重构设计（可移植核心 · 高性能 · 高能力）

> 目标：把现在「C++ + JNI + Java(dexlib2) + Dart」缝在一起、每次搜索都重解析的实现，
> 重构为**一个平台无关的可移植 C++ 核心（dexcore）** + **各端薄适配层**。
> 既能单独拉出来当独立项目 / 命令行 / 桌面用，也能嵌进本 Flutter 项目在移动端用。
>
> 本文只做设计与分阶段规划，不含实现。评审通过后再动代码。

> **重要更正（基于对 MT 的实测逆向）**：早前「MT 靠纯 .so 所以秒搜」的假设是**错的**。
> 用户逆向 MT 后确认：MT 的**核心逆向引擎（DEX 解析 / smali 反汇编·汇编 / ELF / ARSC / AXML）
> 全部是纯 Java 实现，不走 .so**；.so 只做辅助（ELF 分析、底层文件 IO、应用保护、Hook、压缩、音视频等第三方）。
> **结论：MT「秒搜」跟 native 无关，靠的是「Workspace Manager」——打开时解析一次、常驻内存、预建索引、加锁缓存。**
> 因此本重构的**性能收益与语言无关**：无论 C++ 还是 Java，只要做「常驻会话 + 预建索引」就能达到 MT 级速度。
> → 走 C ABI / dexcore 只为**多端复用 + 云端可测 + 契约干净**，**不是**为了性能。若不需要多端，性能问题可在现有架构上直接解决（见 §7 的「快车道」）。

---

## 0. 为什么要重构（现状痛点）

三批优化后功能已基本对齐 MT，但有三个**结构性**问题，靠继续打补丁解决不了：

### 0.1 性能：每次搜索都重新解析整个 DEX
- `jni_bridge.cpp::searchInDex` 顶部每次都 `parser.parse(data)`；
- 多 dex 会话在 `MultiDexSessionOps` 里**逐个 dex 再 parse 一遍**（`for (entry : session.dexBytes) CppDex.searchInDex(...)`）；
- 字符串搜索的 `build_string_class_map` 会把**全部方法反汇编一遍**来建 string→class 映射，**每次 string 查询都重跑**。

5.8w 类的包，每查一次都从零解析 + 可能全量反汇编 → 这就是「有延迟」的根因。
MT「秒搜」是因为**打开时解析一次、常驻内存、预建索引**（其 Workspace Manager，纯 Java），之后只查索引。
**注意：这是语言无关的——我们只要在现有引擎上做同样的「常驻 + 索引」，就能同样快，不必为性能而重写成 native。**

### 0.2 契约：C++ / Java / Dart 三层字段名各写各的
反复出现的 bug 都是同一类：层间键名对不齐。
- manifest 空：C++ 出 `elementName/attributeName/attributeValue`，Java 读 `element/attribute/value`；
- class 搜 className 空：C++ 出 `name`，Java 读 `className`；
- minSdk 恒 0：C++ 出 `minSdk`，Java 读 `minSdkVersion`。

每加一个字段都要在三个地方对齐，极易漏 → 应由**单一契约**约束。

### 0.3 边界：引擎与平台耦合，无法脱离 Android 验证
- 现在 `dex_cpp` 这个 SHARED 库把**纯引擎**（parser/smali/arsc/axml）和 **JNI 绑定**（`jni_bridge.cpp`）编在一起；
- 结果：引擎逻辑离不开 Android，**这台开发机无法编译/跑**，每个 native 改动都要用户本地重编一轮才能验；
- 也无法「单独拉出来在别的端用」。

---

## 1. 总体架构：核心 + 适配层

```
┌───────────────────────────────────────────────────────────┐
│  dexcore  (纯 C++17，零平台依赖，可独立成库/独立仓库)          │
│  ───────────────────────────────────────────────────────   │
│   parser   : DEX/ARSC/AXML 解析 → 内存模型                    │
│   index    : 打开时预建的索引（name / string→class / xref）   │
│   session  : 一次解析常驻，持有 parser + index（多 dex 聚合）  │
│   query    : 基于索引的搜索（class/method/field/string/code） │
│   smali    : 反汇编 / smali↔dex                              │
│   writer   : 写回/汇编（阶段 3，先可暂缺，见 §6）             │
│   abi      : 稳定 C ABI (dexcore.h) —— 唯一对外入口           │
└───────────────────────────────────────────────────────────┘
        ▲                 ▲                    ▲
        │ C ABI           │ C ABI              │ 链接静态库
   ┌─────────┐      ┌───────────┐       ┌──────────────┐
   │ JNI 适配 │      │ dart:ffi   │       │ dexcli / gtest│
   │ (Android)│      │(桌面/iOS)  │       │ (本机/CI 验证)│
   └─────────┘      └───────────┘       └──────────────┘
        │                 │
   Android .so       Flutter 各端
```

**核心原则：`dexcore` 不 `#include <jni.h>`、不依赖 Android、不 JSON 化对外协议。**
所有平台通过一个稳定的 **C ABI**（`dexcore.h`）访问它。

### 1.1 为什么用 C ABI 而不是直接 C++ / 直接 JNI
- C ABI 在所有端通用：Android(JNI 内部调它)、iOS、Windows、macOS、Linux 都能链接；
- Flutter 可用 `dart:ffi` 在**桌面/iOS 直接调**，绕开 JNI；Android 仍走 JNI（成熟）；
- 独立项目 / 命令行 / 别的 App 也能直接链接，满足「不同端复用」。

---

## 2. 目录与工程拆分（满足「独立项目 + 嵌入本项目」）

### 2.1 目标布局
```
dexcore/                        # ← 平台无关核心，可单独成 git 仓库
  CMakeLists.txt                #   只依赖标准库 + miniz + nlohmann(可选)
  include/dexcore/*.h           #   内部 C++ 头
  include/dexcore.h             #   对外稳定 C ABI（唯一公共头）
  src/dex/ src/arsc/ src/xml/ src/apk/ src/query/ src/index/
  third_party/miniz*
  cli/main.cpp                  #   dexcli：命令行工具（桌面可跑）
  test/*.cpp                    #   gtest golden 测试（本机/CI 可跑）

packages/dex_editor/android/src/main/cpp/
  CMakeLists.txt                #   add_subdirectory(dexcore) + 编 JNI 适配
  jni_adapter.cpp               #   只做 JNI<->C ABI 编组（薄）
```

### 2.2 两种消费方式
1. **独立项目**：`dexcore` 单独 clone，`cmake -B build && cmake --build build`
   → 得到 `libdexcore`（静态/动态）+ `dexcli` 命令行 + 单测；可在桌面/CI/别的工程用。
2. **嵌入本项目**：`dexcore` 作为 **git submodule**（或 CMake `FetchContent`）放到插件下，
   Android 的 `CMakeLists.txt` 里 `add_subdirectory(dexcore)` 链进 JNI `.so`；
   桌面/iOS 端由 Flutter 的 CMake/`ffiPlugin` 直接编 `dexcore` + FFI。

> 这一步顺带解决 0.3：`dexcore` 能在**这台机器上直接编 + 跑 gtest**，
> 以后引擎逻辑改动我能先本机验证，用户少踩「白编一轮」。

---

## 3. 性能设计：解析一次 + 常驻 + 预建索引

### 3.1 会话模型（核心）
```c
// C ABI 概念示意
dexcore_session* dexcore_open_apk(const char* apk_path);   // 打开=解析全部 dex + 建索引
dexcore_session* dexcore_open_dex(const uint8_t* buf, size_t n);
void             dexcore_close(dexcore_session*);
```
- 打开时**一次性**解析所有 dex，构建内存模型 + 索引，**常驻**在 `session` 里；
- 之后所有 `list/outline/read/search` 都基于常驻结构，**绝不重复 parse**；
- 会话由核心持有（不再是 Java 每次把 `byte[]` 塞回 C++ 重解析）。

### 3.2 打开时预建的索引
| 索引 | 结构 | 服务于 |
|---|---|---|
| 类名索引 | 排序数组 / 前缀 trie（dotted + 描述符两视图） | class 搜索、包过滤、locator |
| 方法/字段名索引 | `name → [ref]` 倒排 | method/field 搜索 |
| 字符串索引 | 字符串池 + 归一化小写副本 | string 搜索（免每次 tolower） |
| **string→class 映射** | 打开时**反汇编一次**建好，常驻 | string 归属（referencedBy），**不再每查重扫** |
| xref 图（懒建） | CHA / caller 映射 | find_xrefs |

> 关键：`build_string_class_map` 从「每次 string 查询全量反汇编」改成「**打开时建一次、常驻复用**」。
> 这是 string 搜索延迟的最大来源。

### 3.3 搜索与分页下沉到核心
- 搜索匹配、大小写、offset/limit/cursor 分页**全部在核心做**，直接返回该页；
- 不再「Java 把所有 dex 结果拼起来 → Dart 再切片」；
- 跨多 dex 的聚合在核心的 `session` 层完成（session 本就聚合多 dex）。

---

## 4. 统一契约：一套字段名贯穿三层

### 4.1 单一数据契约（core 定义，各端只搬运不改名）
核心对外返回的结构用**唯一字段名**，Java/Dart **原样透传**，禁止层间改名。
以搜索命中为例（统一后）：
```jsonc
{
  "type": "class|method|field|string|code|...",
  "className": "com.x.Foo",          // 统一：点分类名（不再 name/class 混用）
  "methodName": "...", "fieldName": "...",
  "prototype": "()V", "fieldType": "Ljava/...;",
  "value": "命中的字符串",            // string 命中值
  "referencedBy": ["com.x.A", ...],  // string 归属（全部引用类）
  "line": 12, "snippet": "...",       // code 命中
  "dexFile": "classes3.dex",
  "locator": "dex_class:...|dex_method:...|dex_field:...|arsc_string:...",
  "targetVersion": "..."
}
```
- **locator 也由核心直接产出**（核心最清楚类型/签名），Dart 不再拼；
- Java 层退化为**纯搬运**（JNI 编组），删掉所有 `optString("A", optString("B"))` 兜底改名逻辑。

### 4.2 契约来源单一化
- 字段名清单集中在 `dexcore.h` 附近的一份 schema 注释 / 常量；
- Dart 侧的模型类按同名字段解析；改字段只改一处，三层同步。

---

## 5. 能力对齐/超越 MT 的清单（重构后保持不丢）
沿用三批已实现的能力，迁移到新核心时逐条 golden 测试兜底：
- open/list/outline/read（类/方法）+ locator + targetVersion + 计数/父类/接口；
- 方法分析字段（stringRef/resourceRef/invoke/interestingStrings/invokes）、classHeader、绝对行号；
- 搜索六面 class/method/field/string/code + overview（DEX 四面 + 整包 file/resource/manifest）；
- 分页（offset/limit/cursor）；
- 字符串按引用类归属（referencedBy）；
- arsc variant / type / name；manifest 属性/值；
- smali↔java、smali↔dex。

---

## 6. 写回/汇编（dexlib2）怎么处理

- 读侧（解析/搜索/outline/smali/axml/arsc）**全部进 `dexcore`**，读/搜彻底不依赖 dexlib2；
- **写回/汇编**（`DexPool`/`ApkDexWriter`/`DexFileOps`/`smaliToDex`）：dexlib2 是久经验证的 DEX writer，
  移植到 C++ 正确性风险最高（写坏会产出装不上/崩溃的 APK）。
  → **阶段性保留**：先让读/搜纯 native 且高性能；写回等核心稳定后再评估是否值得移植；
  → 若坚持纯 so：写回需要一个 DEX writer（可评估基于现有 `dex_builder.cpp` 扩展或引入成熟 C++ 库），
     单列为最后阶段，独立验证（往返：dex→模型→dex 字节级对拍）。

---

## 7. 分阶段实施（每阶段可独立验证、可回退）

| 阶段 | 内容 | 产出 / 验证 | 风险 |
|---|---|---|---|
| **P0 工程拆分** | 把纯引擎从 `jni_bridge` 剥离成 `dexcore`，加 C ABI 头、CLI、gtest。JNI 改为链接 dexcore 的薄适配 | 本机能编 `dexcore` + 跑 golden 测试；Android .so 行为不变 | 低（纯搬移，不改逻辑） |
| **P1 常驻会话 + 索引** | 打开=解析一次+建索引并常驻；list/outline/read/search 走常驻结构；string→class 打开时建一次 | 用真实 APK 在 CLI 跑：搜索延迟应从「每次重解析」降到「查索引」 | 中（会话生命周期/内存） |
| **P2 统一契约** | 核心直接产出统一字段名 + locator；Java/Dart 退化为纯搬运，删改名兜底 | golden 对拍字段名；修掉当前 class/method/field 搜 0、string 归属显示等 | 中（面广但机械） |
| **P3 搜索/分页下沉** | 匹配/大小写/分页/多 dex 聚合全部在核心；overview 也在核心聚合 | 分页/overview golden；跨 dex 命中正确 | 中 |
| **P4（可选）写回移植** | DEX writer 进核心，去 dexlib2 | 往返字节级对拍 + 真机装包 | 高 |

> P0–P3 完成即达到「读/搜纯 native + 高性能 + 多端可用 + 契约统一」；P4 视需要再启。

### 7.1 快车道（若只要「秒搜」、暂不要多端）
既然性能与语言无关，如果短期只想消除延迟、不追求多端/纯 native：
**只做 P1 的「常驻会话 + 预建索引」即可**——在现有 C++ 引擎上，让会话解析一次常驻、
string→class 打开时建一次、搜索查索引。这一步就能拿到 MT 级速度，**不需要工程拆分/契约重写/写回移植**。
工程拆分（P0）、契约统一（P2）、多端（C ABI/FFI）是「干净 + 多端 + 云端可测」的收益，可按需再排。

---

## 8. 多端可用性矩阵（重构后）

| 端 | 接入方式 | 说明 |
|---|---|---|
| Android | JNI 适配 `.so`（链接 dexcore） | 现有路径，最小改动 |
| iOS / macOS | dexcore 静态库 + `dart:ffi`（C ABI） | 无需 JNI |
| Windows / Linux 桌面 | dexcore + `dart:ffi` | Flutter 桌面直接用 |
| 命令行 / CI / 别的工程 | `dexcli` 或直接链接 `libdexcore` | 「单独拉出来」的形态 |
| Web（可选，远期） | Emscripten 编 WASM | 需评估 |

---

## 9. 待你拍板的开放问题
1. **Android 是否也统一到 C ABI + FFI**，还是保留 JNI 只做适配？（建议：先保留 JNI，其他端走 FFI，降风险）
2. **dexcore 是否单独开一个 git 仓库**（submodule 引入），还是先放本仓库 `packages/dexcore/` 内、以后再拆？
3. **写回（P4）**是否纳入本轮目标？（建议：先不纳入，读/搜纯 native 优先）
4. 是否需要我**先做 P0 工程拆分的 PoC**（把引擎剥出来、本机 gtest 跑通一个用例）来验证方案可行、再继续？

---

## 10. 结论与交接（给下一个会话/换号后接手用）

**核心事实（已由用户实测逆向确认）**：MT 的逆向引擎是**纯 Java**，不是 .so；它「秒搜」靠的是
**打开时解析一次 + 常驻内存 + 预建索引 + 加锁缓存（Workspace Manager）**。→ **性能与语言无关。**

**当前实现的真正瓶颈**：`searchInDex` 每次都 `parser.parse()` 重解析；多 dex 逐个重解析；
string 搜索每次 `build_string_class_map` 全量反汇编。→ 这是「有延迟」的唯一根因。

**最终决定（用户 2026-07 拍板）**：**做完整重构**，走「干净车道」——平台无关 `dexcore` +
C ABI + FFI 全端统一，追求「又快、又强、又全、多端」。快车道仅作为「若中途想先见效」的回退选项保留。
新架构的**完整规格见下方 §11**（这是本轮真正要照着实现的蓝图）。

**为什么完整重构仍成立（即使性能与语言无关）**：性能靠「常驻+索引」解决即可，但用户要的是
①引擎可独立/多端复用（Android/iOS/桌面/CLI/CI）②契约干净、无三层错位 ③云端可测（我能在开发机验证引擎）。
这三点必须靠工程拆分 + C ABI + 统一契约达成，不是打补丁能给的。

**环境提醒**：本机无 Android NDK/SDK（一度尝试安装，用户叫停）；纯 C++ 引擎可本机 g++ 编译验证，
JNI/Java/Android .so 行为仍需用户本地构建复测。测试 APK：`问小白_4.8.5.apk`（在用户设备上，本机没有）。

---

## 11. 完整重构架构规格（定稿蓝图，照此实现）

> 本节把「又快、又强、又全、多端」逐条落成具体技术决策。已吸收用户对 MT 的两轮实测逆向结论。

### 11.0 关键认知：MT 的性能手段（用户逆向实证）与我们的对应
MT 是**纯 Java 引擎**，靠下列手段把 Java 压到接近 native：

| MT 手段（Java） | 作用 | dexcore 对应（C++） |
|---|---|---|
| `MappedByteBuffer`（`FileChannel.map`）内存映射 | 零拷贝、OS 按需分页 | **`mmap()` / `MapViewOfFile`**，C++ 原生，甚至更省 |
| `ByteBuffer`+LITTLE_ENDIAN 直接读 int/short | 无中间对象零拷贝解析 | **直接在 mmap 指针上按小端读**，`string_view`/偏移视图，不 copy |
| 多线程并行反汇编（`APK MCP Smali Cache #n`） | 打开时多核并行反编译 2.9w 类 | **线程池并行反汇编**（std::thread / 线程池） |
| 磁盘持久 smali 缓存（`DataOutputStream`+`SparseLongArray` 偏移索引+digest 校验） | 二次打开跳过反汇编 | **磁盘缓存文件**：按 dex digest 命名，紧凑二进制 + `类idx→offset` 索引 + digest 校验/损坏检测 |
| `SoftReference<byte[]>` 内存缓存 | 热数据常驻、内存紧张自动回收 | **LRU + 容量上限**（C++ 无 SoftRef，用可配额度的 LRU 淘汰） |
| `LruCache`/`EnumMap`/`SparseLongArray`/`IdentityHashMap` | 高效数据结构、无装箱 | 紧凑数组 + 排序索引 + 定长枚举表；C++ 天生无装箱 |
| `libmt3.so` native 文件 IO | 绕过 Java IO 开销 | 我们本就是 native，直接 POSIX/Win32 IO |

**结论**：MT 在 Java 里辛苦逼近 native 的那些（mmap/零拷贝/native IO），我们用 C++ **天生就有**。
真正要照搬的是它的**缓存与并行策略**：常驻会话 + 磁盘持久 smali 缓存 + 打开时并行反汇编 + 内存 LRU 淘汰。
这才是「秒搜」和「二次打开秒开」的来源。→ 见 §11.3 / §11.4。

### 11.1 量化目标（验收线）
- **快**：同一 2.9w+ 类 APK，首次打开（含索引）≤ MT；打开后任意搜索面 **单次 < 100ms**；二次打开命中磁盘缓存 **秒开**。
- **强**：读/搜/分析全部基于常驻索引，无每查重解析；string→class 只在打开时建一次。
- **全**：覆盖 §11.6 能力全景，功能不少于现状且对齐/超越 MT。
- **多端**：同一份 `dexcore` 二进制核心，Android/iOS/桌面/CLI 共用（§11.9）。

### 11.2 模块分层（dexcore，纯 C++17，零平台依赖）
```
dexcore/
  io/        mmap 文件映射、字节视图（ByteView：ptr+len，只读，小端读取）
  dex/       DexFile 解析（header/strings/types/protos/fields/methods/classes）
  arsc/      资源表解析（含 ResTable_config → variant）
  xml/       AXML(manifest) 解析/编辑
  apk/       ZIP 容器（mmap + miniz），列出/取条目
  smali/     反汇编 + smali↔dex + smali→java 伪代码
  index/     打开时构建的各类索引（§11.5）
  cache/     磁盘持久 smali 缓存 + 内存 LRU（§11.4）
  query/     搜索/分页/overview（基于 index，§11.6）
  analyze/   xref / CHA / 方法分析字段
  writer/    写回/汇编（阶段后期，§11.6 写侧）
  session/   Workspace：持有多 dex 模型 + 索引 + 缓存 + 读写锁（§11.3）
  abi/       dexcore.h —— 稳定 C ABI，唯一对外入口（§11.8）
  cli/ test/ dexcli 命令行 + gtest golden
```

### 11.3 会话（Workspace）与 IO：解析一次、常驻、零拷贝
- `open_apk`/`open_dex` → 建一个 **Workspace**：`mmap` 映射 APK/DEX，**不整体读入堆**；
- DEX 结构在**映射内存上直接按小端解析**，字符串/类型等以「偏移+长度视图」表示，避免拷贝；
- Workspace 常驻，持有：各 dex 模型、索引、缓存、一把 **读写锁**（多读单写，对标 MT 的 `ReentrantLock`）；
- 后续所有 list/outline/read/search/analyze **只读 Workspace**，**绝不重复 parse**。

### 11.4 缓存策略（秒搜 + 二次秒开的核心）
两级，完全对标 MT：
1. **内存级（常驻）**：解析结果 + 索引常驻；反汇编后的方法 smali 进 **LRU**（容量可配，超限淘汰冷数据，替代 Java 的 SoftReference）。
2. **磁盘级（跨进程/跨次打开）**：
   - 打开时**线程池并行反汇编**全部方法（或按需 + 后台预热），结果写入磁盘缓存；
   - 缓存文件：按 **dex digest** 命名（内容变则失效）；紧凑二进制 + `方法/类 → 文件偏移` 索引；
   - 带 `schemaVersion`/`digest` **校验与损坏检测**；命中则**跳过反汇编**直接映射读取；
   - string→class 映射同样可随缓存持久化，二次打开免重扫。

### 11.5 索引体系（打开时构建，搜索只查索引）
| 索引 | 结构 | 服务 |
|---|---|---|
| 类名索引 | 排序数组 + hash（点分 & 描述符两视图）+ 归一化小写副本 | 精确/前缀/子串搜索、包过滤、locator |
| 方法/字段名倒排 | `name → [ref]` | method/field 搜索 |
| 字符串池 | 原串 + 归一化小写 | string 搜索（免每次 tolower） |
| string→class | const-string 反扫，**打开时建一次**，可持久化 | 字符串归属 referencedBy |
| xref/CHA | 懒建 + 会话级缓存 | 交叉引用、继承分析 |

### 11.6 能力全景（"全"——不少于现状且对齐/超越 MT）
- **读**：open(apk/dex) 摘要、list_classes、outline、read_class/read_method、smali、smali→java 伪代码、classHeader、绝对行号。
- **搜**：class/method/field/string/code/overview 六面 + 整包 file/resource/manifest；分页(offset/limit/cursor)；大小写；（可选 regex）。
- **分析**：method/field xref、CHA、方法分析字段（stringRef/resourceRef/invoke/interestingStrings/invokes）、string→class 归属。
- **资源**：ARSC 解析/搜索/variant/type/name；AXML(manifest) 解析/搜索/编辑。
- **写（后期阶段）**：modify/add/delete class、smali→dex 汇编、回写 APK。风险最高，字节级往返对拍 + 真机装包验证。
- **可选**：ELF（.so）符号/段分析（MT 有；非必需，按需）。
- **不做**：jadx 级完整 Java 反编译（保持伪代码）。

### 11.7 并发模型
- Workspace 内一把 **读写锁**：搜索/读取并发进行（共享读）；写回/失效缓存独占；
- 打开时的并行反汇编用**线程池**，数量按核数；
- C ABI 层保证 handle 线程安全（内部加锁），上层（Dart/Java）无需关心。

### 11.8 C ABI 设计（唯一对外入口，`dexcore.h`）
以不透明 handle + JSON 字符串出入（JSON 便于跨端 & 与现有 Dart 契约衔接；热路径可后续加二进制通道）：
```c
typedef struct dexcore_ws dexcore_ws;               // 不透明会话句柄
dexcore_ws* dexcore_open_apk(const char* path, const char* opts_json);
dexcore_ws* dexcore_open_dex(const uint8_t* buf, size_t n, const char* opts_json);
void        dexcore_close(dexcore_ws*);

// 统一查询入口：op = "list_classes"|"outline"|"read_class"|"read_method"
//                    |"search"|"overview"|"xref"|"parse_manifest"|"search_arsc"...
// args_json 传参，返回 JSON（调用方负责 free）
char*       dexcore_query(dexcore_ws*, const char* op, const char* args_json);
void        dexcore_free(char*);                     // 释放返回串

// 写侧（后期）：返回新字节，调用方保存
uint8_t*    dexcore_write(dexcore_ws*, const char* op, const char* args_json, size_t* out_len);
const char* dexcore_last_error(dexcore_ws*);
```
- Dart 通过 `dart:ffi` 直接调；Android 也走 FFI（**删掉 Java 读/搜路径与 dexlib2**）；
- 所有平台**同一条路径**，契约只在 core↔Dart 之间对齐一次。

### 11.9 多端交付矩阵
| 端 | 接入 | 说明 |
|---|---|---|
| Android | `dart:ffi` 调 `libdexcore.so`（`add_subdirectory(dexcore)` 编入） | **不再用 JNI/Java 读搜路径** |
| iOS/macOS | `dart:ffi` + 静态库/xcframework | 无 JNI |
| Windows/Linux 桌面 | `dart:ffi` + dll/so | Flutter 桌面直接用 |
| CLI/CI/别工程 | `dexcli` 或链接 `libdexcore` | 「单独拉出来」形态；本机 gtest 可验 |
| Web（远期） | Emscripten→WASM | 需评估 |

### 11.10 统一数据契约
- 字段名唯一（见 §4.1 的搜索命中示例：`className/methodName/fieldName/prototype/fieldType/value/referencedBy/line/snippet/dexFile/locator/targetVersion`）；
- **core 直接产出最终字段名 + locator**，Dart 原样解析，**无任何改名兜底**；
- schema 以 `dexcore.h` 旁一份常量/注释为单一事实源。

### 11.11 目录/构建/测试
- `dexcore` 放本仓库 `packages/dexcore/`（先内置，日后要独立再拆成 submodule）；
- 构建：独立 `CMakeLists.txt`；本机 `cmake && ctest` 跑 gtest；Flutter 端用 `ffiPlugin` 各端编译；
- **云端可测**（这台机器）：g++ 编 `dexcore` + gtest golden + `dexcli` 跑真实/生成 DEX + 一段 Dart FFI 冒烟脚本验 core↔Dart；
- 真机仅验「装进 App 点一下」的 UI 全链路。

### 11.12 分阶段落地（完整重构版）
| 阶段 | 内容 | 云端可验 | 风险 |
|---|---|---|---|
| **A 拆核心** | 引擎从 `jni_bridge` 剥成 `packages/dexcore`，加 C ABI + CLI + gtest；行为不变 | ✅ g++/gtest | 低 |
| **B mmap+常驻+索引** | mmap 零拷贝解析；Workspace 常驻；打开时建索引 + string→class 一次 | ✅ CLI 计时 | 中 |
| **C 缓存+并行** | 线程池并行反汇编；磁盘持久 smali 缓存（digest 校验）+ 内存 LRU | ✅ 二次打开计时 | 中 |
| **D 契约统一+FFI** | core 产出统一字段名+locator；Dart 走 `dart:ffi`；删 Java/JNI/dexlib2 读搜路径 | ✅ Dart FFI 冒烟 | 中高（面广） |
| **E 写回移植** | writer 进 core（modify/add/delete/汇编/回写），去 dexlib2 写侧 | 部分（往返对拍）+ 真机 | 高 |
| （F 可选） | ELF 分析 / regex / WASM | 视需要 | — |

顺带修当前 P0：class/method/field 搜 login 返 0（B/D 阶段随索引+契约一并解决）。

### 11.13 待用户确认的少量决策（有默认值，未答也能推进）
1. 写回(E) 本轮是否做？**默认：先做 A–D（读/搜/分析纯 native+多端），E 最后单独评估。**
2. ELF 分析是否要？**默认：不做，按需再加。**
3. `dexcore` 先内置本仓库还是即刻独立仓库？**默认：先内置 `packages/dexcore/`。**
4. Android 是否即刻从 JNI 全切 FFI？**默认：D 阶段一次性切，切前保留旧 JNI 路径可回退。**
