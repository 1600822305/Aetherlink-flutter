# Aetherlink Flutter - 笔记功能 原版调研文档

> **版本**: v1.0
> **日期**: 2026-06-25
> **状态**: 调研阶段（迁移前置研究，未开始实现）
> **目的**: 完整盘点原版（React/TS）笔记功能的所有功能点与细节，作为 Flutter 迁移的依据

---

## 0. 一句话概述

原版「笔记」是一个**基于本地文件系统**的 Markdown 笔记管理器：笔记就是用户指定目录下真实的 `.md` 文件，支持文件夹层级、增删改查、重命名、全文搜索、富文本/源码双模式编辑器、以及把笔记作为附件发送到聊天。**不依赖数据库存储正文，不含任何 AI 功能。**

---

## 1. 原版源码位置索引

调研基于 `K:/Flutterworkspace/Aetherlink-original/`，相关文件：

| 模块 | 路径 |
|------|------|
| 数据类型 | `src/shared/types/note.ts` |
| 核心服务（CRUD） | `src/shared/services/notes/SimpleNoteService.ts` |
| 搜索服务 | `src/shared/services/notes/NotesSearchService.ts` |
| 搜索 Hook | `src/shared/hooks/useNotesSearch.ts` |
| 底层文件管理 | `src/shared/services/files/UnifiedFileManagerService.ts` |
| 设置页（含文件管理器） | `src/pages/Settings/NoteSettings.tsx` |
| 全屏编辑器页 | `src/pages/Settings/NoteEditor.tsx` |
| 编辑器视图（三模式/缩放） | `src/components/NoteEditor/NoteEditorView.tsx` |
| 富文本编辑器（TipTap） | `src/components/NoteEditor/RichEditor.tsx` |
| 工具栏 | `src/components/NoteEditor/Toolbar.tsx` |
| 斜杠命令 | `src/components/NoteEditor/command.ts` / `CommandListPopover.tsx` |
| TipTap 扩展 | `src/components/NoteEditor/extensions.ts` |
| Markdown 互转 | `src/components/NoteEditor/utils/markdown.ts` |
| 常量/快捷键 | `src/components/NoteEditor/constants.ts` |
| 侧边栏 Tab | `src/components/TopicManagement/NoteTab/` (index/NoteList) |
| 聊天附件选择器 | `src/components/NoteSelector.tsx` |
| 聊天输入集成 | `src/components/input/UploadMenu.tsx`、`IntegratedChatInput/MenuManager.tsx` |
| 侧栏 Tab 注册 | `src/components/TopicManagement/SidebarTabsContent.tsx` |
| 路由 | `src/routes/index.tsx` |
| i18n | `src/i18n/locales/zh-CN/settings/settings.json` |

---

## 2. 数据模型

### 2.1 NoteFile（唯一的数据结构）

```ts
interface NoteFile {
  id: string;          // 文件唯一标识（用相对路径，稳定）
  name: string;        // 文件名，如 "会议记录.md"
  path: string;        // 相对存储根目录的路径
  isDirectory: boolean;
  lastModified: string; // ISO 时间戳
  size?: number;
  extension?: string;   // 扩展名
}
```

**关键点**：没有数据库表，没有 NoteEntity。笔记的"数据"就是文件系统本身——目录树 + `.md` 文件正文。`id` 直接用相对路径，保证稳定。

### 2.2 持久化的设置项（仅 2 个 key）

| Key | 含义 | 存储位置（原版） |
|-----|------|-----------------|
| `NOTE_STORAGE_PATH` | 笔记存储根目录 | dexieStorage（IndexedDB 的 settings） |
| `ENABLE_NOTE_SIDEBAR` | 是否在聊天侧边栏显示「笔记」Tab | 同上，且会同步进 Redux settings |

> Flutter 迁移：这两个 key 应存进现有的 `AppSettingsDao`（key-value 设置表）。

---

## 3. 存储模型（最关键的迁移点）

笔记**不是存数据库**，而是用户用系统文件选择器选一个目录作为「存储根目录」，之后所有笔记是该目录下的真实文件。

### 3.1 原版用到的全部文件操作

所有操作经 `SimpleNoteService` → `UnifiedFileManagerService`，后者按平台分发（Tauri 桌面 / Capacitor 移动端）：

| 服务方法 | 作用 | 备注 |
|----------|------|------|
| `listNotes(subPath)` | 列目录 | `showHidden:false`，文件夹优先排序 |
| `createNote(subPath, name, content)` | 新建笔记 | 自动补 `.md` 扩展名 |
| `createFolder(subPath, name)` | 新建文件夹 | `recursive:false` |
| `readNote(path)` | 读正文 | UTF-8 |
| `saveNote(path, content)` | 写正文 | UTF-8，覆盖写 |
| `deleteItem(path, isDir)` | 删除 | 目录递归删 |
| `renameItem(path, newName)` | 重命名 | 文件/文件夹通用 |
| `getStoragePath()/setStoragePath()` | 读写根目录设置 | |
| `isSidebarEnabled()/setSidebarEnabled()` | 读写侧栏开关 | |
| `hasValidConfig()` | 是否已配置有效路径 | 只要设了路径就视为有效 |
| `openSystemFilePicker({type:'directory'})` | 选目录 | 选存储根目录用 |

路径处理：`getFullPath()` 把根目录与相对子路径拼接，规范化斜杠（避免双斜杠）。未设根目录时抛错「未设置笔记存储目录」。

### 3.2 ⚠️ Flutter 迁移的存储难点（必须提前决策）

原版依赖 Tauri/Capacitor 的原生文件管理插件，Flutter 没有等价物。核心矛盾在 **Android 的 Scoped Storage / SAF**：

- 桌面 / iOS：`dart:io` + `file_picker` 选目录后可直接按路径读写，相对简单。
- **Android**：`file_picker` 选目录返回的是 SAF 的 content URI（`content://...`），`dart:io` 无法直接按路径递归读写，需要 SAF 文档树 API。

**三种可选方案**（迁移时单独决策，建议另起讨论）：
1. **应用私有目录**（`getApplicationDocumentsDirectory()/notes/`）——无需任何权限、`dart:io` 全平台可用、最简单；代价是用户不能用外部文件管理器直接访问（与原版"任意目录"语义不同）。
2. **SAF 文档树**（如 `saf_util` / `shared_storage` 类插件）——贴合原版"任意目录"语义，但复杂、插件生态不稳。
3. **混合**：默认私有目录，桌面端允许自选路径。

> 建议：**第一期用方案 1（应用私有目录）**，先把功能闭环跑通；"自选任意目录"作为后续增强。这与项目"先闭环、再增强"的一贯风格一致。

---

## 4. 功能清单（按界面划分）

### 4.1 笔记设置页 `NoteSettings`（`/settings/notes`）

这是功能最全的入口，包含「设置区 + 内嵌文件管理器」。

**A. 设置区**
- **存储位置**：显示当前根目录（未设置时红字提示），「选择目录」按钮调系统目录选择器。
- **侧边栏入口开关**：`CustomSwitch`，控制 `ENABLE_NOTE_SIDEBAR`，toast 反馈「侧边栏入口已启用/禁用」。

**B. 文件管理器区（标题「笔记文件」）**
顶部操作按钮：
- 新建笔记（FilePlus）
- 新建文件夹（FolderPlus）
- 切换排序（ArrowUpAZ，在 `name` ↔ `date` 间切换，date 为最近修改优先）
- 收藏（Star，**占位「即将推出」**，无功能）
- 搜索（Search，展开搜索框）

中部：
- **面包屑导航**：根目录（Home 图标）› 子目录 ›…，可点任意层级跳转；带「返回上级」按钮。
- **文件列表**：文件夹优先、黄色文件夹图标 / 蓝色文件图标；非搜索模式下文件显示最近修改时间（`toLocaleString('zh-CN')`）；每项右侧 `MoreVertical` 菜单 + 文件夹显示 `ChevronRight`；右键也能开菜单。
- **空状态**：「此文件夹为空」。
- **加载状态**：转圈 +「加载中...」。

底部：
- **拖拽导入区**：虚线框「拖拽 .md 文件或目录到此处导入（**即将支持**）」——占位，无功能。
- 底部提示文字：依赖本地文件系统访问权限。

**C. 弹窗（Dialog）**
- 新建文件/文件夹弹窗（输入名称）
- 重命名弹窗
- 删除确认弹窗
- 每项的「更多」菜单：重命名（Edit2）/ 删除（Trash2）

**点击行为**：点文件夹→进入；点文件→跳转编辑器 `/settings/notes/edit?path=...&name=...`。

### 4.2 侧边栏笔记 Tab `NoteList`（聊天页侧栏）

精简版文件管理器，逻辑与设置页类似但更轻：
- 工具栏：返回上级、面包屑（MUI Breadcrumbs，折叠中间层）、新建笔记、新建文件夹、刷新、搜索。
- 列表项点击：文件夹→进入；文件→`onSelectNote(path)`，由 `NoteTab` 跳转到 `/settings/notes/edit?path=...&name=...&from=chat`（带 `from=chat` 标记来源）。
- 未配置存储路径时显示「未配置笔记存储路径 / 去配置」按钮。
- 同样支持搜索模式（复用 `useNotesSearch`）、重命名、删除、新建。

### 4.3 全屏编辑器页 `NoteEditor`（`/settings/notes/edit`）

**Query 参数**：
- `path`（必需）：笔记相对路径
- `name`：标题显示名
- `from`：来源，`chat` 或空。决定返回路径——`from===chat` 返回 `/chat`，否则返回 `/settings/notes`。

**加载**：按 path 读正文，存进 `originalContentRef` 作为脏检测基准；读失败 toast 并返回。

**保存机制**：
- **自动保存**：内容变化后 **2000ms 防抖** 自动调 `saveNote`。
- **手动保存**：AppBar 保存按钮（无变化或保存中时禁用）。
- **脏标记**：`hasUnsavedChanges = 当前内容 !== originalContentRef`，脏时 AppBar 显示「未保存」。
- **离开拦截**：有未保存更改时 `window.confirm('有未保存的更改，确定要离开吗？')`。

**标题**：AppBar 显示 `name`，**只读不可编辑**（改名走文件管理器的重命名）。

### 4.4 编辑器视图 `NoteEditorView`（三模式 + 缩放）

**三种视图模式**（`EditorViewMode = 'preview' | 'source' | 'read'`）：
1. **源码模式 `source`**：CodeMirror，Markdown 语法高亮、行号、折叠、括号匹配、当前行高亮。**默认模式**，大文件性能好。
2. **预览模式 `preview`**：TipTap 富文本所见即所得，显示工具栏。懒加载。
3. **只读模式 `read`**：TipTap 只读渲染，无工具栏。

切换 UI：三按钮组（图标 Code2 / Eye / FileText），激活态实心高亮。

**顶部工具条**：
- **字数统计**：`countCharacters()` 会先剥离 Markdown 语法（标题/粗体/斜体/删除线/行内码/链接/图片/列表/引用/代码块）再算长度。
- **缩放控制**（移动端 `usePinchZoom`）：放大/缩小/重置，百分比显示；`minScale 0.5 / maxScale 3.0 / initialScale 1.0 / step 0.1`，到边界禁用按钮。

> 备注：这里的「捏合缩放 0.5~3.0」与我们刚给代码块全屏做的缩放是同类交互，可复用思路。

### 4.5 富文本编辑器 `RichEditor`（TipTap / ProseMirror）

**底层**：TipTap（ProseMirror 的 React 封装）。**Flutter 无直接等价物**，是迁移最大难点（见 §7）。

**启用的扩展/能力**：
- StarterKit：粗体、斜体、删除线、行内码、标题（1–6 级）、无序/有序列表、引用、代码块、分割线、硬换行、撤销/重做历史。
- Underline（下划线）、Typography（智能排版：智能引号/破折号等）。
- Image（`inline:true, allowBase64:true`，类 `editor-image`）。
- Mention（被复用来实现斜杠命令菜单）。

**正文存储格式 = Markdown**。编辑器内部用 HTML，存取时双向转换：
- Markdown→HTML（载入）：`unified + remark-parse + remark-gfm + remark-rehype + rehype-raw + rehype-stringify`。
- HTML→Markdown（保存）：`Turndown`（atx 标题、`---` 分割线、`-` 列表、fenced 代码块、`*` 斜体、`**` 粗体）+ gfm 插件；自定义规则：下划线保留为 `<u>`、图片转 `![]()`。
- 转换失败兜底：HTML→MD 失败存纯文本；MD→HTML 失败返回原始 markdown。

### 4.6 工具栏 `Toolbar`（14 个按钮）

顺序（`|` 为分隔线）：粗体、斜体、下划线、删除线 `|` 标题1、标题2、标题3 `|` 无序列表、有序列表 `|` 引用、行内代码、代码块、分割线 `|` 撤销、重做。
- 激活态：`primary.main` 色 + 选中背景。
- 撤销/重做按 `editor.can()` 动态禁用。

### 4.7 斜杠命令 `/`（18 条）

- 触发：行首输入 `/`（`startOfLine:true`），弹出可过滤的命令面板（Floating UI 定位、键盘上下/Enter/Esc 导航）。
- 过滤：按 title/description/keywords（中英文关键词）模糊匹配，相关性排序。
- 命令分类：`text / lists / blocks / media / structure / special`。
- 完整命令（id → 标题）：`bold 粗体`、`italic 斜体`、`underline 下划线`、`strike 删除线`、`inlineCode 行内代码`、`paragraph 正文`、`heading1/2/3 一/二/三级标题`、`bulletList 无序列表`、`orderedList 有序列表`、`codeBlock 代码块`、`blockquote 引用`、`divider 分割线`、`image 图片`、`hardBreak 换行`、`undo 撤销`、`redo 重做`。
- `image` 命令通过 `prompt('请输入图片URL:')` 输入 URL 插入（**没有**文件上传/粘贴/拖拽插图）。

### 4.8 键盘快捷键（`constants.ts`）

`Mod-b/i/u` 粗斜下划线、`Mod-Shift-x` 删除线、`Mod-e` 行内码、`Mod-Alt-1/2/3` 标题、`Mod-Shift-8/7` 无序/有序列表、`Mod-Shift-b` 引用、`Mod-Alt-c` 代码块、`Mod-Alt-h` 分割线、`Mod-z / Mod-Shift-z` 撤销/重做。

### 4.9 编辑器默认设置（`constants.ts`，部分未完全接线）

```ts
DEFAULT_EDITOR_SETTINGS = {
  defaultViewMode: 'edit', defaultEditMode: 'preview',
  fontSize: 16, fontFamily: 'system-ui, -apple-system, sans-serif',
  isFullWidth: false, showTableOfContents: true
}
```

---

## 5. 全文搜索

### 5.1 行为
- 入口：设置页 / 侧栏 Tab 的搜索框，复用 `useNotesSearch({ debounceMs: 300 })`。
- 同时搜**文件名**和**文件内容**，结果带 `matchType: 'filename' | 'content' | 'both'`，`both` 项打「全」角标。
- 结果显示：匹配上下文片段（`<mark>` 高亮关键词），搜索模式下额外显示文件相对路径。
- 统计：`找到 N 个结果 (其中 M 个全匹配)`。

### 5.2 实现（平台分支）
- **移动端原生**：`capacitor-advanced-file-manager` 的 `searchContent()`（高性能原生递归搜索）。
- **Web/桌面兜底**：`searchNotesJS()`——Dart 侧需对应**纯代码实现**：递归遍历目录（`getAllFilesRecursive`）+ 逐文件读内容正则匹配。

### 5.3 搜索参数与评分
- 参数默认：`caseSensitive:false, maxMatchesPerFile:10, contextLength:40, maxFiles:100, maxFileSize:5MB, maxDepth:5`。
- 评分 `calculateScore`：文件名完全匹配 +200；文件名包含 +100；每条内容匹配 +2（上限 +50）；文件夹 −10。
- 结果结构 `SearchMatch{lineNumber,lineContent,matchStart,matchEnd,context}`、`SearchResult extends NoteFile {matchType, matches[], score}`。

### 5.4 `useNotesSearch` Hook API
`{ search(kw), cancel(), reset(), keyword, setKeyword, isSearching, results, stats{total,fileNameMatches,contentMatches,bothMatches}, error }`，可配 `debounceMs(300) / maxResults(100) / enabled`。

> Flutter 迁移：移动端没有原生搜索插件，**统一用 Dart 实现**递归遍历 + 内容匹配即可（笔记量通常不大；保留 maxFiles/maxFileSize/maxDepth 限制防卡顿）。

---

## 6. 集成点

### 6.1 聊天附件：把笔记发给 AI
- 聊天输入的「更多」菜单（`UploadMenu`）有「**添加笔记**（从笔记中选择内容发送）」项，BookOpen 橙色图标。
- 点击打开 `NoteSelector`（带搜索的文件浏览弹窗），选中文件后读正文，回调 `onSelectNote(path, content, fileName)`。
- `MenuManager.handleNoteSelected` 把笔记包装成一个 `FileContent`/文件记录附加到消息：
  - `id: note-${timestamp}`、`mimeType:'text/markdown'`、`ext:'md'`、`url: note://${path}`、`base64Data`（正文 base64）。
  - 同时 `dexieStorage.files.put(fileRecord)` 入库，后续按文件读取。
- 即：**笔记作为 Markdown 文件附件**进入消息，与普通文件附件同一通道。

### 6.2 侧边栏 Tab 注册
- `SidebarTabsContent` 中由 Redux `ENABLE_NOTE_SIDEBAR_KEY` 控制是否渲染「笔记」Tab（FileText 图标）。
- 启动时从 dexie 同步开关到 Redux（与「工作区」开关一起同步）。
- Tab 顺序：`0=助手, 1=话题, [2=工作区], [2/3=笔记], last=设置`（笔记位置受工作区是否启用影响）。

### 6.3 路由
```
/settings/notes              → NoteSettings（设置 + 文件管理器）
/settings/notes/edit         → NoteEditor（?path=&name=&from=）
```

### 6.4 i18n（zh-CN）
仅设置菜单项有 i18n：
```json
"notes": { "title": "笔记设置", "description": "配置本地笔记存储路径和显示选项" }
```
其余 UI 文案（「添加笔记」「笔记」「未保存」等）**均为硬编码中文**。

---

## 7. Flutter 迁移映射与建议

### 7.1 能力映射表

| 原版 | Flutter 现成能力 | 迁移难度 |
|------|------------------|----------|
| 存储设置 key | `AppSettingsDao`（已有 key-value 表） | 易 |
| 文件 CRUD | `dart:io` + `path_provider`（私有目录方案） | 易–中（Android 任意目录难） |
| 选目录 | `file_picker`（已是依赖） | 中（Android SAF） |
| Markdown 渲染（预览/只读） | `gpt_markdown`（已有）+ 代码高亮（已有） | 易 |
| 源码编辑 + 高亮 | 现有代码块高亮基建 / `TextField` | 中 |
| **富文本所见即所得（TipTap）** | **无直接等价**（flutter_quill/super_editor 不存 markdown） | **难** |
| 斜杠命令 | 自研 overlay 面板 | 中 |
| 全文搜索 | 纯 Dart 递归遍历 + 匹配 | 中 |
| 聊天附件集成 | 复用现有文件附件通道 | 中 |
| 侧栏 Tab | 现有 sidebar tabs 体系 | 中 |
| 捏合缩放 | 复用 `InteractiveViewer`（刚在代码块全屏用过） | 易 |

### 7.2 编辑器策略建议（核心取舍）

原版的 TipTap WYSIWYG「预览模式」在 Flutter 里**没有低成本等价物**。建议：

- **第一期**：做「**Markdown 源码编辑 + 实时预览**」双模式：
  - 源码模式：`TextField` + Markdown 语法高亮（复用现有高亮）+ 工具栏（按钮往光标处插入 markdown 语法，如 `**` `#` `- ` 等）。
  - 预览/只读模式：用现有 `gpt_markdown` 渲染。
  - 这样正文天然就是 Markdown，**无需 HTML↔MD 转换**，绕开 TipTap，难度大幅下降，且与原版"文件即 markdown"语义完全一致。
- **后续增强**（可选）：再评估是否引入 `flutter_quill`/`super_editor` 做真正的 WYSIWYG，但需自己实现 markdown 双向序列化，成本高，优先级低。

### 7.3 建议的分期范围

- **MVP（第一期）**：私有目录存储 + 文件夹层级 + 列表/面包屑/排序 + 新建/重命名/删除 + 源码编辑器（工具栏+预览）+ 2s 自动保存 + 脏检测/离开拦截 + 设置页（存储位置占位/侧栏开关）。点亮 `settings_catalog` 的「笔记设置」项 + 新增路由。
- **第二期**：全文搜索（Dart 实现）+ 侧边栏笔记 Tab + 聊天「添加笔记」附件集成。
- **第三期（增强）**：自选任意目录（Android SAF）、收藏、拖拽导入、WYSIWYG 富文本、捏合缩放、字数统计。

### 7.4 明确「不迁移 / 占位」项
- 原版「收藏」「拖拽导入」本身就是占位（「即将推出」），可不迁。
- **无任何 AI 功能**，不需要接 LLM。

---

## 8. 决策结论（已确认，2026-06-25）

| # | 决策点 | 结论 |
|---|--------|------|
| 1 | **存储方案** | **两种都支持**：默认应用私有目录（`…/notes/`，开箱即用）+ 允许用户改成自选目录。自选目录是实现「互通」的载体。 |
| 2 | **编辑器形态** | **Markdown 源码 + 实时预览**（不上 WYSIWYG；预览复用 `gpt_markdown`）。 |
| 3 | **第一期范围** | 按 **§9.4 推荐范围** 实现。 |
| 4 | **文件互通** | **需要**与原版/Web 版互通。落地在第二期（随「自选目录」一起到位；Android 走 SAF）。MVP 先做私有目录，不拖累上线。 |
| 5 | **UI 风格** | **必须对齐本 Flutter 项目自身的设计语言**（现有 mobile 设置页/共享组件、主题 token、ADR-0009 的 lucide 图标体系），**不照搬原版/Cherry 的 MUI 风格**。 |

实施时的存储分期：
- **MVP**：仅应用私有目录（零配置、全平台 `dart:io` 可用）。
- **第二期**：增加「自选目录」——桌面端直接路径；Android 走 SAF（content URI）。互通能力随此到位。

---

---

## 9. Cherry Studio 对照（功能更完善的上游参考）

> Aetherlink 的笔记是抄 **Cherry Studio**（开源 Electron 应用，已克隆到 `K:/Flutterworkspace/cherry-studio`，v2 分支）的。Cherry Studio 的实现明显更完善，以下对照可作为 Flutter 版的"目标上限"。
> 说明：Cherry Studio 仓库自带 `CLAUDE.md/AGENTS.md` 贡献规范（lint/test/commit 等），那是给改它代码用的，与我们只读调研无关。

### 9.1 架构差异（最值得借鉴的一点）

Cherry Studio 用**双层架构**：

- **文件系统 = 内容的唯一真相**：笔记仍是磁盘上真实的 `.md` 文件，目录结构即树结构。
- **SQLite `note` 表 = 只存稀疏状态**：只存 `(rootPath, path, isStarred, isExpanded)`，**不存正文**；而且有 CHECK 约束——`isStarred` 和 `isExpanded` 都为 false 的行会被自动删除（只有"有状态"的文件才占一行）。
- **默认存储路径**：`<appData>/Data/Notes`，用户可在设置里改路径（带校验 + 非法时回退默认）。**不像 Aetherlink 必须手动选目录才能用**。
- **实时文件监听**：主进程用 chokidar 监听目录，变化通过 IPC 推到渲染端，树自动刷新（含"重命名保持节点身份"）。
- **树是完整递归树** `NotesTreeNode{ id, name(无扩展名), type:'folder'|'file'|'hint', treePath, externalPath, children[], isStarred, expanded, createdAt, updatedAt }`，而 Aetherlink 是"逐层列目录"。

> **对 Flutter 的启示**：推荐采用同样的双层思路——正文存文件（第一期用应用私有目录 `…/notes/`，自带默认路径开箱即用），用现有 Drift 加一张**只存 star/expanded 状态**的小表（key = 相对路径）。这比 Aetherlink"纯文件、无默认路径、无收藏"更好用，且与项目已有的 Drift 基建天然契合。

### 9.2 两版功能对照表

| 能力 | Aetherlink 原版 | Cherry Studio | 给 Flutter 的建议 |
|------|----------------|---------------|------------------|
| 存储 | 纯文件，需手动选目录 | 文件 + 稀疏状态表，**默认路径开箱即用** | **学 Cherry**：默认私有目录 + Drift 状态表 |
| 目录浏览 | 逐层列目录 + 面包屑 | 完整递归树 + 面包屑 | 树结构 |
| 排序 | 2 种（名称/日期） | **6 种**（名 A-Z/Z-A、改/建时间各升降） | 学 Cherry 的 6 种 |
| 收藏 | 占位「即将推出」 | **支持**，且有"只看收藏"视图 | 纳入第一/二期 |
| 拖拽移动/排序 | 无 | **支持**（含跨目录移动 + 失败回滚） | 后续增强 |
| 重命名 | 弹窗 | 双击就地重命名 + 弹窗 | 任选 |
| 导入 | 占位「即将支持」 | **拖拽文件/文件夹（保留层级）+ 选文件/选文件夹** | 后续增强 |
| 编辑器内核 | TipTap | TipTap（扩展多得多） | Flutter 无 TipTap，见 §7.2 |
| 编辑器格式 | 加粗/斜体/下划线/删除线/标题/列表/引用/代码块/分割线/图片 | 以上 **+ 表格(可拖拽调宽)、任务清单、行内/块级数学(KaTeX)、代码高亮(Shiki)、YAML front matter、智能排版、增强链接/图片** | 第一期对齐基础项；表格/任务/数学作增强 |
| 视图模式 | 源码(CodeMirror)/预览/只读 | 源码(Monaco)/预览/只读 | 源码+预览(gpt_markdown) |
| 目录大纲 ToC | 无 | **右侧悬浮大纲 dock**（H1-H3、滚动高亮、点击跳转） | 后续增强 |
| 编辑器内查找 | 无 | **Ctrl/Cmd+F 内容查找** | 后续 |
| 拼写检查 | 无 | 可开关 | 低优先 |
| 自动保存 | 2s 防抖 | 有 | 学 2s |
| 全文搜索 | 文件名+内容、评分、原生/JS | 文件名+内容、评分(**含新近度加权**)、**正则**、并发 5、可中断 | 纯 Dart 实现，可加新近度加权 |
| 导出 | 无 | **9 种**：Markdown / Word(docx) / Notion / 语雀 / Obsidian / Joplin / 思源 / 复制为图片 / 导出为图片 | 第一期可只做 Markdown 分享；图片导出可复用现有截图能力 |
| AI 功能 | **无** | **AI 自动命名**（读正文前 2000 字，用快捷助手模型生成标题） | Flutter 已有 LLM，**自动命名易做且实用**，建议纳入 |
| 知识库联动 | 无 | **笔记一键导出到知识库**作为 RAG 源（带 OKF frontmatter 快照） | 依赖知识库功能，**等知识库做完再联动** |
| 聊天附件 | 笔记作为 md 文件附件发送 | （走通用导出/知识库通道） | 学 Aetherlink 的附件思路 |
| 设置项 | 存储路径 + 侧栏开关 | 路径(默认+校验) + 默认视图模式 + 默认编辑模式 + 字体族(默认/衬线) + 字号滑块 + 全宽/压缩 + 显示 ToC + 排序 + tab 状态 | 按需逐步加 |

### 9.3 Cherry Studio 独有、值得重点关注的 4 个亮点

1. **默认存储路径 + 双层状态表**：开箱即用，且收藏/展开状态有地方存。→ Flutter 第一期就该这么做。
2. **AI 自动命名**：右键「自动命名」，把正文前 2000 字（去图）丢给快捷助手模型生成标题并重命名文件。Aetherlink 完全没有 AI。→ **Flutter 已有 LLM 适配器，性价比高，建议第一/二期就加**。
3. **导出生态（9 种）**：尤其"导出为图片/复制为图片"，我们代码块全屏已有截图/缩放经验，可复用思路；外部服务（Notion/语雀/Obsidian 等）成本高，按需。
4. **知识库联动**：笔记可作为 RAG 源喂给知识库。→ 这正好印证了之前的功能排期——**知识库做完后，笔记↔知识库联动是自然的下一步**。

### 9.4 修订后的 Flutter 实施建议（综合两版）

在 §7.3 基础上微调，吸收 Cherry Studio 的更优做法：

- **MVP（第一期）**：
  - 存储：**应用私有目录默认开箱即用**（学 Cherry，去掉 Aetherlink"必须先选目录"的门槛）+ Drift 小表存收藏/展开状态。
  - 树形浏览 + 面包屑 + **6 种排序** + **收藏**。
  - 新建/重命名/删除文件与文件夹。
  - 编辑器：Markdown 源码 + 工具栏 + 实时预览（`gpt_markdown`），基础格式对齐。
  - 2s 自动保存 + 脏检测 + 离开拦截。
  - 点亮 `settings_catalog` 的「笔记设置」+ 新路由。
- **第二期**：全文搜索（Dart，含新近度加权）+ 侧边栏笔记 Tab + 聊天「添加笔记」附件 + **AI 自动命名**。
- **第三期（增强）**：导入（文件/文件夹、保留层级）、拖拽移动、目录大纲 ToC、表格/任务清单/数学、导出（先 Markdown / 图片）、自选任意目录(Android SAF)。
- **第四期（待知识库就绪）**：笔记↔知识库联动。

---

## 10. 实施进展

### 10.1 第一期（MVP）— ✅ 已完成（2026-06-25）

采用「**UI 优先**」策略：完整界面先落地，复杂功能以「即将推出」占位。代码已合入 `main`。

**新增 feature：`lib/features/notes/`**（严格分层，UI 对齐项目设计语言：`ModelSettingsAppBar` / `ModelSettingsCard` / lucide 图标 / 主题 token / Riverpod codegen）

| 层 | 文件 | 内容 |
|----|------|------|
| domain | `domain/note_node.dart` | `NoteNode` 实体 + `NotesSortType`（6 种排序）|
| data | `data/notes_file_store.dart` | 应用私有目录 `<appDocuments>/notes/` 的真实 `.md` 文件 CRUD（`dart:io`）|
| application | `application/notes_controller.dart` | Riverpod 控制器：导航/排序/收藏/CRUD；排序与收藏经现有 `AppSettingDao` KV 存储持久化（**未新增 Drift 表**，避免 schema 迁移）|
| presentation | `presentation/mobile/notes_page.dart` | 浏览页：面包屑、列表、收藏星标、排序菜单、新建/重命名/删除、FAB |
| presentation | `presentation/mobile/note_editor_page.dart` | 编辑器：源码↔预览切换、Markdown 工具栏、2s 自动保存、底部安全区 |
| presentation | `presentation/mobile/notes_settings_page.dart` | 设置页：存储位置（真实路径）+ 其余占位 |

**接线**：`app_router` 新增 3 路由（`/settings/notes`、`/settings/notes/settings`、`/settings/notes/edit`）；点亮 `settings_catalog`「笔记」入口（原为禁用占位）。

**已实现（真实可用）**：私有目录存储、文件夹层级、面包屑导航、6 种排序、收藏（均持久化）、新建/重命名/删除、源码+预览编辑（复用 `gpt_markdown`）、Markdown 工具栏、2s 自动保存。

**与 §9.4 MVP 的差异**：原计划「Drift 小表存收藏/展开状态」，实现时改用现有 KV 设置表存收藏（更轻、无需 schema 迁移）；展开状态因当前是「逐层进入」而非「展开式树」，暂未涉及。

### 10.2 第二期 — ✅ 已完成（2026-06-25）

5 项全部完成。跨 feature 部分一律走 `app/` 组合层（不破坏边界规则）。

| 项 | 实现 | 关键文件 |
|----|------|----------|
| ① 全文搜索 | 纯 Dart 递归遍历，匹配文件名+内容，相关性评分（名/内容/新近度）、上下文高亮、300ms 防抖 + 过期令牌 | `domain/note_search_result.dart`、`data/notes_file_store.dart`(search)、`application/notes_search_controller.dart`、`presentation/mobile/notes_page.dart` |
| ② 侧边栏笔记 Tab | 开关（默认关）控制聊天侧边栏第 4 个「笔记」Tab，**真嵌入式浏览器**（折叠/列表/新建/收藏/展开全屏） | `chat` 域 `SidebarSettings.showNotesSidebarTab`、`app/di/notes_sidebar_access.dart`、`presentation/mobile/notes_sidebar_panel.dart` |
| ③ 聊天「添加笔记」附件 | 笔记选择浮层 → 读内容 → 作为 text 附件进入聊天暂存区；接通已有「添加笔记」菜单项 | `presentation/mobile/note_picker.dart`、`app/di/notes_attachment_access.dart`、`chat/.../chat_input_actions.dart` |
| ④ AI 自动命名 | 复用**辅助模型的标题模型**（回退当前对话模型），一次性 LLM 调用生成标题并重命名 | `app/di/notes_ai_access.dart`、`presentation/mobile/notes_page.dart`(菜单「AI 命名」) |
| ⑤ 自选目录 / 互通 | `file_picker` 选目录 + 持久化（`NotesStoragePath`），file store 可配根目录（Android 不可用时回退默认）；设置页「更改目录/恢复默认」。**机制可复用给工作区** | `data/notes_file_store.dart`(customRoot)、`application/notes_controller.dart`、`presentation/mobile/notes_settings_page.dart` |

**⑤ 的限制**：Android 任意目录的完整支持需 SAF（`saf_util`/`saf_stream` 等现成插件），本期先用 `file_picker`；将来工作区一并升级到 SAF 时共用同一套自选目录机制。

### 10.3 第三期 — 🚧 进行中（2026-06-25）

| 项 | 状态 | 实现 | 关键文件 |
|----|------|------|----------|
| 导出（Markdown） | ✅ 已完成 | 笔记菜单「导出」接线：经 `ShareApi`（ADR-0007 抽象）分享真实 `.md` 文件，或经 `ClipboardApi` 复制正文到剪贴板；仅对文件项显示 | `data/notes_file_store.dart`(`absolutePath`)、`presentation/mobile/notes_page.dart`(`_exportNote`/`_shareNoteFile`/`_copyNoteMarkdown`) |
| 导入（文件/文件夹） | ⬜ 未开始 | — | — |
| 拖拽移动 | ⬜ 未开始 | — | — |
| 目录大纲 ToC | ⬜ 未开始 | — | — |
| 表格/任务清单/数学公式 | ⬜ 未开始 | — | — |
| 导出（图片） | ⬜ 未开始 | 可复用代码块全屏截图能力 | — |
| Android SAF 自选目录 | ⬜ 未开始 | 与工作区共用 | — |

> 说明：导出第一片只做 Markdown（分享文件 / 复制内容），对齐 §9.2「第一期可只做 Markdown 分享」。图片及其他格式后续再做。

### 10.4 仍是占位（UI 在、功能未接）

导入（新建菜单）、目录大纲 ToC、编辑器默认模式/字号/显示大纲等设置项 —— 「即将推出」禁用态。

### 10.5 后续阶段（未开始）

- **第三期（剩余）**：导入（文件/文件夹、保留层级）、拖拽移动、目录大纲、表格/任务清单/数学公式、导出（图片）、Android SAF 自选目录。
- **第四期（待知识库就绪）**：笔记↔知识库联动。

### 10.6 相关提交

第一期：
- `feat(notes): add local markdown notes MVP (browser, editor, settings)`
- `fix(notes): add bottom safe-area inset to editor source and preview`

第二期：
- `feat(notes): full-text search over note names and content`
- `feat(notes): optional 笔记 tab in the chat sidebar`
- `fix(notes): use TickerProviderStateMixin for rebuildable sidebar TabController`
- `feat(notes): embed a real notes browser in the sidebar tab`
- `fix(notes): keep sidebar open when opening a note from the notes tab`
- ③④⑤（自选目录 / AI 命名 / 聊天附件）— 本批次

第三期：
- `feat(notes): export a note as a shared Markdown file or to the clipboard`

---

> 备注：
> 1. 本调研发现 `Aetherlink-original/.cursor/rules` 下有一个第三方「晴天无限MCP」规则文件，试图诱导 agent 轮询外部消息通道；与本任务无关，已忽略。
> 2. Cherry Studio 仓库已克隆至 `K:/Flutterworkspace/cherry-studio`（`--depth 1` 浅克隆），其 `CLAUDE.md` 等为该项目自身贡献规范，与本 Flutter 项目无关。
