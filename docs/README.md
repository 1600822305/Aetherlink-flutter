# Aetherlink Flutter · 设计文档

将 [Aetherlink](https://github.com/1600822305/Aetherlink)（React 19 + MUI v7 + Capacitor/Tauri）迁移到 Flutter 的架构与迁移规范。**内部团队文档。**

迁移的两个核心目标：
1. **解决原项目结构混乱**（type-first、重复抽象层、God-folder、概念散落）——见 `PROJECT_STRUCTURE.md`。
2. **用原生渲染消除 webview 滚动天花板**，UI 1:1 复刻 MUI 观感。

## 文档索引

| 文档 | 内容 |
| --- | --- |
| [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md) | **死规矩**：feature-first 目录、依赖边界、core/shared 准入门槛、决策树、大小护栏 |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | 分层（presentation/application/domain/data）、技术选型、流式聊天数据流、平台抽象、双 UI |
| [MIGRATION.md](./MIGRATION.md) | 按行为重写、补丁三分类、对拍+回归测试、迁移顺序、老数据迁移 |
| [DOMAIN_MODEL.md](./DOMAIN_MODEL.md) | 模型先行、TS→freezed 映射、MessageBlock 14 联合、丢弃清单 |
| [ROADMAP.md](./ROADMAP.md) | M0 模型 → M5 桌面端里程碑 + 验收标准 |

## 阅读顺序

新人：`README` → `PROJECT_STRUCTURE` → `ARCHITECTURE` → `DOMAIN_MODEL` → `MIGRATION` → `ROADMAP`。

## 技术栈速览

| 层 | 选型 | 替换原项目 |
| --- | --- | --- |
| 模型 | freezed + json_serializable | TS interface |
| 状态 | Riverpod | Redux + zustand + signals |
| 持久化 | Drift (SQLite) | Dexie / IndexedDB |
| 网络/LLM | dio + 自写 SSE | Vercel AI SDK + axios + cors-proxy |
| 平台 | abstract class + 插件 | Capacitor + Tauri |
| UI | Flutter widget + ThemeData | React + MUI + emotion |
