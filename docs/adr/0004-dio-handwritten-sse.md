# ADR-0004：网络/LLM 用 dio + 自写 SSE（不移植 Vercel AI SDK）

- **状态**：Accepted
- **日期**：2026-06-15

## 背景
原项目 LLM 层 = 自研 provider 客户端（openai / anthropic-aisdk / gemini-aisdk / dashscope）架在 Vercel AI SDK（`ai` / `@ai-sdk/*`）+ axios + SSE 上，dev 还挂了 `cors-proxy.js`。Dart 侧没有 Vercel AI SDK 的对等物。

## 选项
1. **dio + 自写 SSE 解析 + 每 provider 一个 client**，收口到**单一** provider factory。
2. 找第三方 Dart LLM 封装包（生态不齐、覆盖 provider 有限、受制于上游）。
3. 裸 `http` 包（够用但拦截器/超时/重试/取消等要自造）。

## 决策
用 **dio**（拦截器/超时/取消/重试齐全）+ **自写 SSE 行解析** + 每 provider 一个 client，**collapse 成一个 ProviderFactory**。

## 理由
- OpenAI/Claude/Gemini/DashScope 本质都是 **REST + SSE**，自写流式解析不难且**完全可控**，不被第三方封装的抽象绑架。
- dio 的拦截器适合统一塞 auth、日志、错误映射、重试。
- **收口单一 factory** 直接修原项目的病——原项目有**两个** ProviderFactory（`api/providerFactory.ts` 和 `services/ai/ProviderFactory.ts`）+ provider 逻辑散在 7 处。新项目规定：provider 的创建只有一个入口。
- **白赚简化**：原生无 CORS → `cors-proxy` 整个删掉；`event-source-polyfill` 不需要。
- ②类业务修复（provider 专属字段剥离等）在重写时显式实现 + 配测试（见 `MIGRATION.md` / `TESTING.md`），不逐行抄。

## 后果
- 正面：完全可控、依赖少、能精确复刻各 provider 行为、修掉双 factory 病。
- 负面：4 套 client + 流式解析要自己写并维护；上游 API 变更要自己跟。
- 推翻触发条件：出现成熟、活跃、覆盖全 provider 的 Dart 官方/准官方 SDK 时再评估。
