# UI 像素级 1:1 复刻手册（MUI/SolidJS → Flutter）

> 把 React 19 + MUI v7 的页面**像素级**搬到 Flutter 的标准打法。
> `MIGRATION.md` 讲「行为怎么迁」（自底向上、补丁三分类），本文专讲 **M4 阶段「UI 怎么 1:1」**——逐页复刻时的查表、踩坑、对拍验证。
> 配套：`MIGRATION.md` §4/§7、`CONVENTIONS.md`（DoD）、`adr/0008-themeable-system-tokens-decoration-sharing.md`、`adr/0009-lucide-icon-set-for-visual-parity.md`。

样板实现（照着抄结构）：`lib/features/settings/presentation/mobile/default_model_settings_page.dart` ← 原版 `Aetherlink/src/pages/Settings/DefaultModelSettings.tsx`。

---

## 1. 第一原则

1. **原版 CSS = 规格，不是参考。** 数值（字号/圆角/间距/阴影/透明度）按原版**逐个量**，不靠肉眼「差不多」。±1px 取整误差可接受，超出就是 bug。
2. **能用 theme token 就用 token，字面色是例外。** 只有原版写死的 `rgba(...)` 品牌色/微透明 tint/阴影才用字面色，并在旁边注释原值（见样板里的 `// rgba(0,0,0,0.05)`）。
3. **状态分支 UI 必须整段迁。** 原版用 `useState` 切出来的形态（多选、空态、加载态、错误态）是功能的一部分，不是可选项——漏一个就不是 1:1。
4. **结构按 Flutter 习惯重写，观感 1:1。** 不照搬 DOM 嵌套；用 Flutter idiom（`Material`/`InkWell`/`ReorderableListView`…）拼出同样的像素。

---

## 2. 标准流程（每页 7 步）

1. **定位两端**：原版 `*.tsx` + 样式；Flutter 现有页（若有）。截原版基准图。
2. **列形态清单**：把页面所有状态分支列出来（普通 / 多选 / 空 / 加载 / 错误 / 弹窗…），逐个都要复刻。
3. **量数值**：对每个元素量字号、weight、行高、padding、margin、圆角、边框、阴影、颜色（见 §3 查表）。
4. **写实现**：theme token 优先；字面色注释原值；状态用 `ConsumerStatefulWidget` 本地态（见 §4）。
5. **`flutter analyze` 零告警**（DoD 第一关）。
6. **对拍**：Web 原版（DevTools 移动端断点）vs Flutter（`flutter run -d linux` + mock 数据），同区域 `zoom` 截图并排，逐项核对（见 §5）。
7. **开 PR**：描述写清复刻了哪些形态、量了哪些数值、对拍截图贴上（见 §6 检查清单）。

---

## 3. MUI/CSS → Flutter 映射对照表

### 3.1 排版

| MUI / CSS | Flutter | 备注 |
| --- | --- | --- |
| `theme.typography.h6`（1.125rem=18px / 600） | `titleLarge.copyWith(fontSize: 18, fontWeight: w600)` | HeaderBar 标题 |
| `subtitle1`（未覆写，按 `typography.fontSize:16` 系数 16/14 ≈ 18.29px，行高 1.75=32px） | `titleMedium.copyWith(fontSize: 128/7, height: 1.75)` | **MUI 全局 16/14 缩放系数会放大所有默认字号，别漏乘** |
| `body2`（0.875rem=14px） | `bodyMedium.copyWith(fontSize: 14)` | 次要/描述文字 |
| `ListSubheader`（默认 ×16/14 ≈ 16px） | `bodyMedium.copyWith(fontSize: 16, fontWeight: w600)` | 卡片小标题 |
| `font-weight: 600` | `FontWeight.w600` | MUI `fontWeightBold` 默认 700 |

> ⚠️ MUI 的 `typography.fontSize: 16`（默认 14）会给**所有**未显式 px 的字号乘 `16/14`。量到的渲染值要除回去验证，或直接用渲染值。

### 3.2 间距 / 圆角 / 边框

| MUI / CSS | Flutter |
| --- | --- |
| spacing unit = 8px；`p: 2` = 16px | `EdgeInsets.all(16)` |
| `borderRadius: 2`（× theme `shape.borderRadius: 8`）= **16px** | `BorderRadius.circular(16)` |
| `Button` 默认圆角（`shape.borderRadius`）= 8px | `BorderRadius.circular(8)` |
| `1px solid divider` | `Border.all(color: theme.dividerColor)` + `Divider(height: 1, thickness: 1)` |
| `Divider`（带 1px 占位） | `Divider(height: 1, thickness: 1)` |

### 3.3 颜色 token

| MUI palette | Flutter | 字面值（明 / 暗） |
| --- | --- | --- |
| `text.primary` | `colorScheme.onSurface` | —— |
| `text.secondary` | `colorScheme.onSurfaceVariant` | —— |
| `text.disabled` | `onSurface.withValues(alpha: 0.38)` | —— |
| `success.main` | 字面色 | `#2E7D32` / `#66BB6A` |
| `error.main`（原版红） | **字面色 `#EF4444`** | 本项目 `colorScheme.error` 是 Material `#B00020`，**不等于原版红**，要用字面色 |
| `primary.main` | `colorScheme.primary` | 本项目 = `#64748B` |
| `divider` | `theme.dividerColor` | —— |

### 3.4 透明度十六进制速查（`Color(0xAARRGGBB)` 的 AA）

| alpha | AA | 常见用途 |
| --- | --- | --- |
| 0.01 | `03` | 卡片头微 tint `rgba(0,0,0,0.01)` |
| 0.05 | `0D` | 柔阴影 / disabled 填充 `rgba(0,0,0,0.05)` |
| 0.08 | `14` | 选中行底色 |
| 0.10 | `1A` | tonal 按钮填充 |
| 0.12 | `1F` | 头像 accent 底色 |
| 0.38 | `61` | text.disabled |
| 0.50 | `80` | chevron `rgba(79,70,229,0.5)` → `Color(0x804F46E5)` |
| 0.60 | `99` | 拖拽手柄 `opacity: 0.6` |

> 半透明优先用 `color.withValues(alpha: x)`；只有「字面色 + 字面 alpha」一起写死时才用 `Color(0xAARRGGBB)`。

### 3.5 阴影

| CSS `box-shadow` | Flutter `BoxShadow` |
| --- | --- |
| `0 2px 6px rgba(0,0,0,0.05)` | `BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2))` |
| `0 4px 12px rgba(0,0,0,0.05)` | `BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 4))` |

### 3.6 组件等价

| MUI | Flutter |
| --- | --- |
| `Paper`（圆角 + 边框 + 阴影，裁剪子元素） | `DecoratedBox` + `ClipRRect` + `Material(transparency)`（见样板 `_ModelCard`） |
| `Avatar`（40px，透明底，首字母兜底） | `Container(40×40, shape: circle)` + `Image.asset(errorBuilder: 首字母)` |
| `ListItemButton` | `Material` + `InkWell` + `Row(Padding(h:16, v:8))` |
| 工具栏 tonal `Button`（startIcon + label） | 自写 pill：`Container(圆角+tint)` + `Row(Icon, label)`，**外包 `Center`**（见 §4 坑①） |
| `Dialog`（确认弹窗） | `showDialog` + `AlertDialog`（title/content/actions） |
| `Checkbox` | `Checkbox(visualDensity: compact, materialTapTargetSize: shrinkWrap)` |
| 可拖拽列表（`reorder`） | `ReorderableListView.builder(buildDefaultDragHandles: false)` + `ReorderableDragStartListener`；用 `onReorderItem`（新 API，已自动校正 newIndex） |
| `lucide-react` 图标 | `lucide_icons_flutter`（`LucideIcons.*`，见 ADR 0009） |

---

## 4. 实战坑清单

| 坑 | 现象 | 解 |
| --- | --- | --- |
| **① `AppBar.actions` 拉伸** | action 内的 pill/按钮被拉成整个 toolbar 高（如 56px），而非 MUI 按钮的 36.5px | actions 的子项用 `Center(child: ...)` 包裹，保持 intrinsic 高度并垂直居中 |
| **② `Container(alignment:)` 撑满父高** | 设了 `alignment: Alignment.center` 的 Container 会扩展填满父级高度 | 去掉 `alignment`，改用外层 `Center` 控制居中 |
| **③ Riverpod 3.x `StateProvider` 未定义** | `Undefined name 'StateProvider'`（3.x 移到 `flutter_riverpod/legacy.dart`） | 临时 UI 态（多选、选中集合）一律用 `ConsumerStatefulWidget` 本地字段 + `setState`，**别引 legacy**——这也是本仓约定 |
| **④ `colorScheme.error` ≠ 原版红** | 本项目 error = Material `#B00020`，比原版 `#EF4444` 暗 | 工具栏红、弹窗红用字面 `Color(0xFFEF4444)` |
| **⑤ MUI 16/14 缩放漏乘** | 默认字号（subtitle1/ListSubheader 等）偏小 | 未显式 px 的 MUI 默认字号要乘 `16/14` |
| **⑥ 漏迁状态分支** | 多选/空态/弹窗没复刻，只做了「主态」 | §2 第 2 步先列全形态清单，逐个复刻 |

---

## 5. 对拍验证（截图流程）

1. **Web 原版**：Chrome DevTools 打开设备模式（Responsive），宽度设 **400px**（移动端断点）；导航到目标页，配置好能展示全部形态的数据。
2. **Flutter**：`flutter run -d linux`，准备 mock 数据（如至少 1 个服务商）让列表行/状态都显示出来。
3. **截同区域**：用 `computer` 工具的 `zoom` 截两端的相同区域（整页或工具栏+列表+卡片），得到全分辨率干净裁剪。
4. **并排**：`montage -tile 2x1`（ImageMagick）拼成「左原版 / 右 Flutter」对比图，贴进 PR。
5. **逐项核对**：头像尺寸/底色/阴影、状态文字色/字号、图标尺寸、按钮 padding/圆角/高度、卡片头 tint、间距。
6. **多形态都要对**：普通态 + 多选态 + 弹窗，各出一张。

> mock 数据条数两端不一致没关系——对拍的是**行/工具栏/卡片头的样式**，不是数据本身。

---

## 6. 复刻完成检查清单

- [ ] 所有状态形态都复刻（主态 / 多选等分支 / 空态 / 弹窗）。
- [ ] 字号/weight/行高、padding/margin、圆角/边框、阴影逐项对齐原版。
- [ ] 颜色：token 优先；字面色（品牌/红/微 tint）注释了原 `rgba` 值。
- [ ] 临时 UI 态用 `ConsumerStatefulWidget`，未引 Riverpod legacy。
- [ ] `flutter analyze` 零告警；`dart format` 无改动（CONVENTIONS DoD）。
- [ ] 对拍截图（各形态）贴进 PR，逐项核对通过。
- [ ] PR 描述写清：复刻了哪些形态、量了哪些关键数值、字面色为何用字面色。
