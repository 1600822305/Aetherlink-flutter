# DEX 引擎重构设计（可移植核心 · 高性能 · 高能力）

> 目标：把现在「C++ + JNI + Java(dexlib2) + Dart」缝在一起、每次搜索都重解析的实现，
> 重构为**一个平台无关的可移植 C++ 核心（dexcore）** + **各端薄适配层**。
> 既能单独拉出来当独立项目 / 命令行 / 桌面用，也能嵌进本 Flutter 项目在移动端用。
>
> 本文只做设计与分阶段规划，不含实现。评审通过后再动代码。

---

## 0. 为什么要重构（现状痛点）

三批优化后功能已基本对齐 MT，但有三个**结构性**问题，靠继续打补丁解决不了：

### 0.1 性能：每次搜索都重新解析整个 DEX
- `jni_bridge.cpp::searchInDex` 顶部每次都 `parser.parse(data)`；
- 多 dex 会话在 `MultiDexSessionOps` 里**逐个 dex 再 parse 一遍**（`for (entry : session.dexBytes) CppDex.searchInDex(...)`）；
- 字符串搜索的 `build_string_class_map` 会把**全部方法反汇编一遍**来建 string→class 映射，**每次 string 查询都重跑**。

5.8w 类的包，每查一次都从零解析 + 可能全量反汇编 → 这就是「有延迟」的根因。
MT「秒搜」是因为**打开时解析一次、常驻内存、预建索引**，之后只查索引。

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
