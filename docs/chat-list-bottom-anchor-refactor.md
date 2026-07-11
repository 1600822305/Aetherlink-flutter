# 聊天列表「底部锚定」重构设计文档

> 目标：让聊天消息列表在结构上做到「加载历史 / 内容增长永远不动视口」，
> 达到微信 / QQ / Telegram 原生聊天界面的滚动流畅度与稳定性。
> 状态：实施中，进度见 §8。

## 1. 现状分析

### 1.1 现有架构（`chat_page.dart` → `_MessageListView`）

当前实现是一个**正向** `ListView.builder`（index 0 = 最老的可见行），配合一整套补偿机制：

| 机制 | 位置 | 作用 |
|---|---|---|
| `ChatAutoFollowScrollController` | `chat_auto_scroll_controller.dart` | 布局期（`applyContentDimensions`）把 pixels 钉在 `maxScrollExtent`，实现流式输出零延迟跟底 |
| `pendingAdjust` | 同上 | 键盘 reserve 变化时同帧平移内容（微信式整体位移） |
| `extentAnchor`（PR #666） | 同上 | 历史揭示时按 extent 增量同帧修正 offset |
| 历史窗口（`_hiddenRowCount`） | `_MessageListViewState` | 入场只 mount 最近 30 行，滚近顶部再按页揭示 |
| 入场分帧 ramp（8 行/帧） | 同上 | 首帧只 build ~1 屏，后续帧补齐窗口 |
| `_DeferredBubble` / `DeferredContent` | 同上 / blocks | 重内容骨架屏延迟物化 |
| `ChatAutoScrollController` | controllers | stick-to-bottom 状态机（阈值 80px、pin window 500ms） |
| `ListObserverController` | scrollview_observer | 上一条/下一条导航、mini-map 跳转的索引观察 |

### 1.2 结构性问题：为什么补偿机制是「对症下药」而不是「去根」

正向列表 + 顶部插入，在 Flutter 的 sliver 布局模型里天然会移动内容：
`SliverList` 的 scroll offset 以**列表头部**为原点，任何在头部之上插入/移除
行、或未 build 行的**估算高度**变化，都会改变既有内容的 scroll offset。
于是每一个会改变头部内容的操作，都需要一个对应的补偿：

1. **历史揭示**（`_maybeRevealMore` / `_rampStep` / `_revealDownTo`）→ `extentAnchor` 补偿；
2. **流式增长**（尾部长高）→ 布局期跟底 `correctPixels`；
3. **`ListView.builder` 估算 extent 抖动**（未 build 的行以估算高度参与
   `maxScrollExtent`，滚动中不断被真实高度替换）→ 跟底逻辑双向修正
   （`gap < 0` 分支）；这也是「上滑松手回弹」类 bug 的共同根源：
   松手瞬间 ballistic 模拟基于一个随后会被修正的 extent。

补偿链路（notification → post-frame / layout 修正）每多一环，就多一个时序
窗口可能漏帧或与 fling / ballistic 打架。#666 已把最明显的一帧跳动消掉，
但**估算 extent 抖动**（第 3 条）在正向列表里无法根除——只要视口上方存在
未 build 的行，`maxScrollExtent` 就只是猜测。

### 1.3 原生端为什么没有这个问题

- **Android `RecyclerView`/`LinearLayoutManager`**：布局以「锚点 child」为
  基准向两侧展开，`stackFromEnd` / `reverseLayout` 让聊天从底部锚定；
  prepend 历史时锚点 child 不动，offset 是布局的**输出**而非输入。
- **iOS 微信/Telegram**：`UITableView` 翻转 180°（transform）或在
  `layoutSubviews` 里同帧调 `contentOffset`——和我们 `extentAnchor` 同理，
  但 Telegram 采用的是前者（结构性方案）。

共同点：**滚动原点在「最新消息」一侧**，历史向远离原点的方向增长。

## 2. 方案选型

### 方案 A：`ListView.builder(reverse: true)`（推荐）

把列表翻转：`index 0 = 最新一行`，行序数组倒排。scroll offset 0 = 底部。

- 贴底 = `pixels == 0`（minScrollExtent），**恒为精确值**，不受估算影响 →
  跟底不再需要 `correctPixels`，流式增长天然不动视口（内容向"负方向"长）。
- 加载历史 = 在列表**尾部**追加 → 不影响 offset，`extentAnchor` 整套删除。
- 估算 extent 抖动只影响远离视口的顶部（maxScrollExtent），用户贴底或中部
  滚动时完全无感。
- Flutter 聊天生态的主流做法（flutter_chat_ui、stream_chat_flutter 等）。

代价：所有「index / 方向」语义翻转（详见 §4 迁移映射）。

### 方案 B：`CustomScrollView` + `center` key 双 sliver

历史 sliver 在 center 之前（向上增长），当前会话 sliver 在 center 之后。

- 优点：无需倒排数据，理论上最接近 RecyclerView 锚点模型。
- 缺点：`scrollview_observer` 对多 sliver + center 的支持不完整；跟底仍需
  自定义（center 锚定的是「某条消息」而不是底部）；padding/键盘补偿逻辑
  复杂化。实现风险显著高于 A，收益并不更多。

### 方案 C：换第三方框架（flutter_chat_ui / super_sliver_list）

现有定制（多模型对比行、骨架延迟物化、mini-map、导航、多选、性能监控埋点）
过深，换框架等于重写渲染层且失去这些能力。仅 `super_sliver_list` 可作为 A
的可选增强（精确 extent 估算 + `jumpToItem`），不单独成方案。

**结论：采用方案 A（reverse 列表），保留现有渲染层组件不动。**

## 3. 目标架构

```
ListView.builder(
  reverse: true,                      // offset 0 = 底部（最新）
  controller: _scrollController,      // 仍是 ChatAutoFollowScrollController（大幅简化）
  padding: EdgeInsets.fromLTRB(0, 8 + bottomReserve, 0, 8),  // 上下互换
  itemCount: visibleRows + loaderCount + headerCount,
  itemBuilder: (_, i) => rowFor(reversedIndex(i)),
)
```

- `rows` 保持现有正序数据结构，仅在 `itemBuilder` 里做 `rev = rows.length - 1 - i`
  的索引换算（不复制数组）。
- 历史窗口：`_hiddenRowCount` 语义不变（隐藏最老的 N 行），但揭示 =
  reverse 列表尾部追加，**无需任何 offset 补偿**。
- loader 行（历史加载 spinner）与 system prompt 头部：位于 reverse 列表的
  **最后一个 index**（视觉上的最顶部）。

### 3.1 各机制的去留

| 现有机制 | 重构后 |
|---|---|
| 布局期跟底（`shouldAutoFollow` + `correctPixels`） | **删除**。贴底 = `jumpTo(0)`/保持 `pixels==0`，流式增长天然不动 |
| `extentAnchor`（#666） | **删除**（历史追加不再影响 offset） |
| `pendingAdjust`（键盘同帧平移） | **保留**，方向取反（reverse 下正方向 = 向下） |
| `ChatAutoScrollController` 状态机 | **保留**，`atBottom` 判定改为 `pixels <= threshold` |
| 历史窗口 + 入场 ramp | **保留**，去掉三处补偿代码 |
| `_DeferredBubble` / `_KeepAliveItem` | 不变 |
| `ListObserverController` | 保留（scrollview_observer 支持 reverse），索引换算集中封装 |
| 对话导航（top/prev/next/bottom） | 保留，top↔bottom 目标互换、prev/next 方向取反 |
| mini-map 跳转 / 多选展开 | 保留，索引经统一换算函数 |

### 3.2 索引换算的统一封装

翻转 bug 的主要来源是散落的 index 运算。集中成一个纯函数组（可单测）：

```dart
/// rows 为正序（0 = 最老）。list index 为 reverse 列表的 item index。
class ChatListIndexMap {
  ChatListIndexMap({required this.totalRows, required this.hiddenRows,
                   required this.headerCount, required this.loaderCount});

  int listIndexOf(int rowIndex);   // 正序行号 → reverse list index
  int rowIndexOf(int listIndex);   // 反向
  bool isLoader(int listIndex);    // 视觉最顶（index == count-1）
  bool isHeader(int listIndex);
}
```

`itemBuilder`、导航、mini-map、observer 回调全部只经这一层换算。

## 4. 迁移映射表

| 现在（正向） | 重构后（reverse） |
|---|---|
| 贴底：`maxScrollExtent - pixels <= 80` | `pixels <= 80` |
| `pinToBottom` → `jumpTo(maxScrollExtent)` | `jumpTo(0)` |
| 回顶：`animateTo(0)` | `animateTo(maxScrollExtent)`（先揭示全部历史） |
| 回底：`animateTo(maxScrollExtent)` | `animateTo(0)` |
| 揭示触发：`pixels < 200`（近顶） | `maxScrollExtent - pixels < 200`（近顶 = 近尾） |
| 键盘补偿 `pendingAdjust += delta` | `pendingAdjust -= delta` |
| `userScrollDirection` forward/reverse 语义 | 互换（滚动方向翻转） |
| padding bottom = reserve | padding top = reserve |
| loader/header 在 index 0 | 在 index count-1 |

## 5. 实施计划（分 4 个 PR，每步可独立回滚）

1. **PR-1 索引层**：引入 `ChatListIndexMap` + 单测；现有代码先以
   `reverse=false` 模式接入（行为零变化），把散落的 index 运算收拢。
2. **PR-2 列表翻转**：`reverse: true` + itemBuilder/padding/揭示触发/键盘
   补偿方向翻转；删除 `extentAnchor` 与三处揭示补偿。
3. **PR-3 跟底简化**：`ChatAutoScrollController` 改 `pixels<=threshold`
   判定与 `jumpTo(0)`；删除布局期跟底的 `correctPixels` 双向修正（保留
   `pendingAdjust`）。`ChatAutoFollowScrollController` 大幅瘦身。
4. **PR-4 导航与跳转适配**：对话导航、mini-map、多选、`_navCacheBoost`
   glide 路径的方向适配；回归测试清单见 §6。

## 6. 回归测试清单

- [ ] 入场：打开长会话，首帧显示最新消息，无跳动；ramp 期间视口静止
- [ ] 上滑加载历史：连续 fling 到顶，无回弹/跳帧，fling 不被打断
- [ ] 流式输出：贴底时零延迟跟随；上滑离底后不被拽回
- [ ] 发送消息：pin 到底部
- [ ] 键盘弹出/收起：内容整体平移，输入框上方内容不动
- [ ] 对话导航：回顶/回底/上一条/下一条（含跨隐藏历史的 prev）
- [ ] mini-map 点击跳转（含隐藏历史内的目标）
- [ ] 多选模式（行展开后的索引正确）
- [ ] 消息分割线 / plain 样式 / 系统提示气泡（reverse 下 divider 方向）
- [ ] 话题切换 / 空会话 / 单条消息会话

## 7. 风险与缓解

| 风险 | 缓解 |
|---|---|
| scrollview_observer 在 reverse 下的 index 语义 | PR-1 先落索引层单测；观察回调统一走 `ChatListIndexMap` |
| 隐蔽的方向假设（如 `_onScroll` 的 direction 判断） | 迁移映射表逐条过；PR-2/3 各自附带手工回归 |
| divider / padding 视觉细节翻转 | 截图对比 |
| 大改动引入新 bug | 4 个 PR 分步合入，任一步可单独 revert |

## 8. 实施进度

| 步骤 | 状态 | PR | 备注 |
|---|---|---|---|
| PR-1 索引层 | 已实现 | — | 新增 `ChatListIndexMap`（`chat_list_index_map.dart`）+ 单测；`chat_page.dart` 的 itemBuilder / 导航 / mini-map 索引运算全部收拢到该层，`reverse=false` 行为零变化 |
| PR-2 列表翻转 | 未开始 | — | |
| PR-3 跟底简化 | 未开始 | — | |
| PR-4 导航与跳转适配 | 未开始 | — | |

实施备注：
- 多选模式下 mini-map 的「展开索引」计算（`_scrollToMessageFromMiniMap` 的
  isSelecting 分支）暂未走索引层，PR-2 翻转时需一并适配。
