# DEX 工具改造记录（对齐 MT）

> 目的：记录 dex_editor 工具三批优化的**改造内容、架构边界、踩坑与经验**，
> 便于下一批（即使切换会话）快速接续，不必重新摸索。

## 0. 快速上手（下一批必读）

- **测试 APK**：`/storage/emulated/0/MT2/mcp/问小白_4.8.5.apk`，包名 `com.yuanshi.wenxiaobai`
  （注意不是 `com.yj.assistant`；真实类前缀如 `com.yuanshi.wanyu.*`）。
- **本机限制**：这台机器**没有 Android NDK/SDK**，native（C++/JNI/Java）**只能写、不能编译/运行**。
  Dart 层能用 `flutter analyze` + 单测验证；native 改动一律需**用户本地 Android Studio 构建 APK**，
  再在真机用上面的 APK 复测。
- **每次改完 native 都要提醒用户**：`.so`（C++）和 Java 都需**重新编译**才生效；
  若复测「没变化」，第一嫌疑是 **没重编**。
- **验证命令**：`flutter analyze <改动文件>`；单测在 `test/shared/mcp_tools/builtin_tools_test.dart`。
- **提交规范**（见 AGENTS.md）：Conventional Commits，正文中文，结尾附 Devin 署名 trailer；
  显式 `git add <文件>`（勿 `git add .`）；默认 `git push`。

## 1. 架构与分层（关键心智模型）

dex_editor 是 **C++ 引擎 + Java(dexlib2) 混合**，不是随意混入，而是分工：

| 层 | 位置 | 职责 |
|---|---|---|
| C++ 引擎 | `packages/dex_editor/android/src/main/cpp/` | DEX 解析/枚举/搜索/反汇编/smali、arsc、axml。主力 |
| JNI 桥 | `cpp/jni_bridge.cpp` | `Java_com_aetherlink_dexeditor_CppDex_*`，C++↔Java |
| Java 分发 | `.../java/com/aetherlink/dexeditor/` | 会话管理、结果整形、C++ 未覆盖时回退 dexlib2 |
| Dart 工具 | `lib/shared/mcp_tools/tools/dex_editor_tool.dart` | MCP 工具入口、参数解析、结果**装饰**（补 locator 等）、分页 |
| 目录/schema | `lib/shared/mcp_tools/builtin_tool_catalog.dart` | 工具描述、参数 schema、字段文档 |
| 卡片渲染 | `lib/features/chat/presentation/widgets/blocks/dex_editor_block_view.dart` | 结果的特殊 UI 渲染 |

**关键文件锚点**：
- C++ 搜索入口：`jni_bridge.cpp` → `Java_..._searchInDex`（DEX 内搜索，分支 string/class/method/field/code）
- C++ manifest 搜索：`jni_bridge.cpp` → `searchXml`（返回键 `elementName/attributeName/attributeValue/elementPath/elementIndex`）
- Java 多会话搜索：`MultiDexSessionOps.java` → `searchInMultiSession`
- Java APK 辅助：`CppApkHelper.java`（manifest/arsc 结果整形，`searchManifest`/`searchArscStrings`）
- Dart 搜索分发：`dex_editor_tool.dart` → `_search`（target=dex/strings/files/arsc/manifest/overview）
- Dart 结果装饰：`_decorateDexResult` / `_decorateArscResource` / `_decorateArscString`

**关于「纯 native 化」（用户曾提议）**：不建议现在推倒重写。dexlib2 仍是 **DEX 写回/汇编**（`DexPool`、`ApkDexWriter`、`DexFileOps`）的核心价值，移植到 C++ 风险最高（writer 正确性难）。读侧（解析/搜索/outline）已基本 C++ 化。渐进补齐、用 `CppDex.isAvailable()` 对拍，覆盖 100% 后再删 dexlib2。Rust 不建议（无实质收益）。

## 2. 三批改造内容

### 第一批：list/outline/read 结构化 + 统一 locator（PR #611–#619）

- **locator 统一**：类=`dex_class:a.b`，方法=`dex_method:La/b;->m()V`，字段=`dex_field:La/b;->f:Z`。
- **targetVersion**：类级与方法级各自独立（正常）。
- `dex_open_apk`：补 `packageName/versionName/versionCode/classCount/totalMethods` + 每 DEX 统计。
- `dex_list_classes`：每类补 `superclass/interfaces/fieldsCount/methodsCount/locator`
  （native `get_class_brief`，只读计数头，不拖慢 5.8w 类）。
- `dex_outline_class`：补 `instructionsCount`、方法/字段 `locator`、`accessFlagsText`（可读修饰符）。
- `dex_read_class`/`dex_read_method`：补 `locator`+`targetVersion`+分页；方法读取未给签名时**从 smali 还原方法级 locator**（不再退回类 locator）。
- **outline 去 dexlib2**：新增 C++ `get_class_outline` + JNI `CppDex.outlineClass`，`MultiDexSessionOps` 改走 C++。
- **`.super` 修复**：`dex_smali_to_java` 从 `.super` 解析真实父类（原恒 `java.lang.Object`）。

### 第二批：SDK 版本 + 方法分析（PR #620）

- P0 `minSdkVersion/targetSdkVersion`：native axml 解析 `uses-sdk`（原返回 0）。
- P1 方法分析字段：`stringRefCount/resourceRefCount/invokeCount/interestingStrings/interestingInvokes`。
- P2 `classHeader`、方法**绝对行号**。

### 第三批：搜索能力对齐 MT（PR #621–#625）

- P0 `searchType=code`：C++ 原**无 code 分支**（恒 0），新增逐方法反汇编文本搜索，返回 `snippet`+`lineNumber`。
- P0 `target=overview`：一次聚合 DEX 4 面（class/method/field/string）；有 apkPath 时**额外**聚合 file/resource/manifest 三面（`apkFacets` 标记）。
- P0 统一 locator：覆盖 dex/files/arsc 各面。
- P1 分页：dex 及非 dex 面（strings/files/arsc/manifest）均支持 `offset/limit/cursor` + `hasMore/nextCursor`。
- P1 DEX 字符串**类归属**：C++ 反扫 `const-string`(0x1a)/`const-string/jumbo`(0x1b) 取 string 索引 → 建 `string_idx→引用类` 映射。**#625 增强为「全部引用类」**：命中按引用类逐条展开，每条带 `className` + `referencedBy`（全部引用类列表）。
- P2 arsc `variant`：C++ 解析 `ResTable_config` → `default/zh-rCN/xxhdpi/v21`。
- arsc 字符串 locator：`arscTarget=strings` 命中补 `locator=arsc_string:<下标>`。

### 复测收尾修复（PR #624）

- P0 **manifest 搜索恒空**（两处独立 bug）：
  1. **键名不匹配**：C++ `searchXml` 返回 `elementName/attributeName/attributeValue`，
     而 `CppApkHelper.searchManifest` 误读 `element/attribute/value` → 字段全空。改读正确键。
  2. **搜索词丢失**：统一入口用 `query` 传词，但 `_searchManifestCpp` 只读 `args.value`
     → 直接 `target=manifest` 搜 login 恒 0。补 `value` 为空时回退 `query`。
- P1 DEX 字符串命中改补**单一 `locator`**（`#618` 已全局去 `classLocator`），不再用 `classLocator`。
- P1 arsc 字符串补 `locator=arsc_string:<下标>`。

## 3. 踩坑与经验（最重要）

1. **native 无法本机验证**：这是贯穿全程的最大摩擦。凡涉及 C++/JNI/Java 的改动，
   本机既不能编也不能跑，只能靠代码走查 + 用户设备复测。**别再尝试装 Android SDK 编 APK
   去「帮用户省事」**——用户明确表示 APK 自己编（历史上多次确认）。
2. **「Dart 默认值」会掩盖 native 是否重编**：例如 `variant` 在 Dart 侧 `_decorateArscResource`
   有 `?? 'default'` 兜底，所以即便 native 没回传真实 variant、用户也会看到 `variant:"default"`——
   这**不能**证明 native 已重编。判断 native 是否生效要看**只有 native 能产出的字段**
   （如字符串 `className`、manifest 的 `element/attribute/value` 非空）。
3. **搜索词参数不一致**：统一入口用 `query`，但部分 native 调用读 `value`/`pattern`。
   加分支时务必核对 Dart→native 的参数键映射（`_withPattern`、manifest 的 `value` 回退 `query`）。
4. **C++ 输出键 vs Java 读取键**：manifest 空 bug 的根因就是两侧键名对不上。
   改 native 输出结构时，**同步核对 Java 整形层读的键名**。
5. **字符串类归属的语义边界**（务必向用户说明）：只有被 `const-string` **在代码里引用**的字符串
   才有类归属；仅作为**类型/方法/字段名**出现的字符串（如描述符 `Lcom/x/Login;` 里的 "Login"）
   **没有 const-string 引用 → 无 className**。这与 MT 行为一致，不是 bug。复测要选真正的常量文案/URL。
6. **反汇编管线可信**：`code` 搜索已被用户确认可用，它与字符串类归属走**同一套**
   `disassemble_method` → `raw_bytes`。所以字符串归属若「空」，优先怀疑 (a) 没重编、(b) 命中的是非常量字符串，而非反汇编逻辑本身。
7. **干净版 > 兼容别名**：用户强烈偏好**单一 locator**，不要保留 `classLocator` 等兼容别名
   （`#616`/`#618` 就是把兼容字段删干净）。新字段命名要一次到位。
8. **不要自作主张加「无用测试」**：曾加 C++ 单测 harness（#613）被用户否掉并关闭。
   除非用户要，别加需要用户本机才能跑的验证。
9. **单测里的既有失败**：`dex_find_class_xrefs`/`dex_find_field_xrefs`/`dex_find_method_xrefs`
   三个 catalog 用例**在 main 上本就失败**（属 xref 工具，与本批无关），不要误判为自己引入。

## 4. PR 索引

| PR | 内容 |
|---|---|
| #611 | 第一批：统一 locator/targetVersion，outline 去 dexlib2 改纯 C++ |
| #612 | 第一批实测反馈 5 问题（search className/packageFilter/accessFlags/.super/apk 摘要） |
| #613 | （已关闭）C++ 引擎单测 harness |
| #614 | outline locator 命名统一 |
| #615 | dex_list_classes 补 superclass/接口/字段数/方法数 |
| #616 | listClasses 统一结构化摘要，移除 listClassesDetailed |
| #617 | 卡片展示字段数/方法数 |
| #618 | 去 classLocator，统一单一 locator |
| #619 | dex_read_method 未给签名时从 smali 还原方法级 locator |
| #620 | 第二批：SDK 版本、方法分析字段、classHeader、方法绝对行号 |
| #621 | 第三批：搜索对齐（locator/overview/分页/code 搜索） |
| #622 | overview 补齐整包面（file/resource/manifest） |
| #623 | 非 dex 面分页 / 字符串类归属 / arsc variant |
| #624 | 复测修复：manifest 空 / 字符串 locator / arsc 字符串 locator |
| #625 | 字符串搜索按引用类归属，返回 className + referencedBy |
