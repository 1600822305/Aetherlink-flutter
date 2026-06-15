# ADR-0006：LLM provider 架构——按协议族收口成 3 个 adapter，统一接缝不统一内脏

- **状态**：Accepted（**Refines ADR-0004**：把其中「每 provider 一个 client」细化为「每协议族一个 adapter」；dio + 自写 SSE 的决定不变）
- **日期**：2026-06-15

## 背景（Context）
ADR-0004 定了「dio + 自写 SSE，收口单一 ProviderFactory」，但没定**到底切成几个 client、按什么切、共享到什么程度**。M2 动工前必须先把这条拍死，否则会复制原项目的病。

原项目实测结构（`1600822305/Aetherlink`）：

- `src/shared/api/` 下 **5 个 client 文件夹**：`openai` / `openai-aisdk` / `anthropic-aisdk` / `gemini-aisdk` / `dashscope`。
- **两套 base 类**：`api/baseProvider.ts`（6.5KB）+ `src/shared/providers/BaseAIProvider.ts`——「想抽公共部分」抽出来的，结果各家协议不同、base 越长越缠、谁都不敢动。
- **两个 ProviderFactory**：`api/providerFactory.ts` 和 `services/ai/ProviderFactory.ts`；provider 逻辑散在 7 处。
- 依赖里其实只有 **3 个 SDK 协议族**：`@ai-sdk/openai`、`@ai-sdk/anthropic`、`@ai-sdk/google`（Cherry Studio 同款）。
- **关键事实**：原项目自己的 factory 写着 `case 'dashscope': return new OpenAIProvider(model) // 走 OpenAI 兼容模式`，DashScope 用 `dashscope.aliyuncs.com/compatible-mode/v1` 直接复用 OpenAI client；Grok 同理。**所以「N 个供应商」只有 3 种真正不同的线协议。**

两个要同时满足的诉求：① 收口、别再 5 文件夹 + 2 base + 2 factory；② **别过度抽象**——各家请求/解析/映射本就不同，硬抽公共 base 反而不利于维护（原项目的两套 base 就是证据）。

## 选项（Options）
1. **3 个互不依赖的协议 adapter +（仅）共享接口/中性 DTO/机械水电**，provider 作为配置，单一 factory 按协议选。
2. 每个供应商一个 client（≈ ADR-0004 字面），收口单一 factory——但供应商一多就是 N 个 client，且 OpenAI 兼容族会复制 N 遍。
3. 一个「全能 BaseProvider」抽象类 + 各供应商重写钩子（`buildBody`/`parseChunk`…）——即原项目老路，已被证明越缠越死。

## 决策（Decision）
选 **① 按协议族收口成 3 个 adapter**：

- **3 个协议 adapter**，都架在 dio + 自写 SSE 上（ADR-0004 不变）：
  - `OpenAiCompatibleAdapter`（吃掉 OpenAI / DashScope / Grok / DeepSeek / Moonshot / OpenRouter… 一切 OpenAI 兼容端点）
  - `AnthropicAdapter`
  - `GeminiAdapter`
- `Provider`/`Model` 带一个 `protocol` 枚举（`openaiCompatible` / `anthropic` / `gemini`）+ `baseUrl` + `apiKey` + 能力开关；**单一 `ProviderFactory` 按 `protocol` 选 adapter**。
- **统一「接缝」，不统一「内脏」**（same contract, independent guts）。

### 划线规则一（按线协议切，不按供应商切）
- **跨协议**（OpenAI / Anthropic / Gemini）：3 个独立 adapter，内脏各写各的。
- **同协议内**（OpenAI 兼容族里的各家）：**同一个 adapter**，差异只是 `baseUrl`/`model`/可选参数等**配置**——这不是重复，是同一个协议。**别因为多一个供应商就 fork 出新 adapter。**
- 真冒出第 4 种线协议（不属于 OpenAI/Anthropic/Gemini 任何一种）才加第 4 个 adapter。

### 划线规则二（共享什么 vs 重复什么）
**共享（统一）：**
- `LlmProtocolAdapter` 接口——方法就一个 `Stream<ChatChunk> streamChat(ChatRequest req)`。
- 中性 DTO：`ChatRequest` 进、规范化的 `ChatChunk`/事件 出（再映射成 domain 的 `MessageBlock`）。
- 单一 `ProviderFactory`。
- **纯机械水电**（与供应商无关）：SSE 行分帧解析器（`data: …\n\n` 拆包）、dio 配置（超时/重试/取消/拦截器）、HTTP error → `AppFailure` 映射。

**不共享（每个 adapter 各写各的，重复也无所谓）：**
- 请求体拼装、鉴权头、endpoint 路径、SSE 事件 schema 解析、chunk→`MessageBlock` 映射、reasoning/thinking 处理、tool-call 格式、finish_reason 映射。
- **不要 BaseProvider 抽象类、不要可重写的 `buildBody`/`parseChunk` 钩子。** 每个 adapter 自包含、从上读到下能读懂。

### 抽象判据（要不要抽公共的唯一标准）
> 改 A 家的怪癖，会不会被迫去动一段 B 家也依赖的共享代码？**会 → 抽过头了，拆开。**

机械水电（SSE 分帧、dio 配置）永不触发此条，故可共享；「请求/解析/映射」一定会触发，故不共享。

## 理由（Rationale）
- 原项目 factory 自己就把 `dashscope` 路由到 OpenAI client——「3 种线协议」是源码既成事实，不是臆断。
- **「错误的抽象」比「重复」贵得多**：原项目两套 base 类正是过度抽象的代价。宁可在 adapter 间重复几行长得像的代码，也不耦合两个会各自演化的 API。
- 接缝统一（接口 + 中性 DTO）→ 全 app 只认一个入口，直接修掉「2 factory + provider 逻辑散 7 处」的病（承接 ADR-0004）。
- 供应商扩展 = 加**配置**，不加 client；OpenAI 兼容族天然收敛到一个 adapter。

## 后果（Consequences）
- 正面：收口彻底（5 文件夹 + 2 base + 2 factory → 3 adapter + 1 factory + 一点水电）；各 adapter 可独立读懂、独立改、独立测；加供应商零改代码。
- 负面 / 代价：3 个 adapter 间会有少量「看起来一样」的代码（**有意接受**，不 DRY）；同协议内各家的小差异要靠 provider 能力配置承载，配置项会增长。
- **护栏（加新东西时照这个走，别破）：**
  1. `OpenAiCompatibleAdapter` **不准**长成 `if (vendor == 'dashscope')` 的 god-file；各家差异（如 DashScope `enable_thinking`、reasoning 字段、Responses API vs Chat Completions）进 **provider 能力配置**，不进 adapter 分支。
  2. 共享层**只放机械水电**；任何带「某协议语义」的代码不许进共享层。
  3. 加供应商先判协议：属于现有 3 族 → 加配置；否则才加 adapter。
  4. 非聊天接口（如 DashScope 原生图像生成）**不是**同一协议，是独立能力模块，**不在 M2 流式聊天范围**。
  5. OpenAI 有 Chat Completions 与 Responses 两种形态——M2 先做 Chat Completions，Responses 后续作为该 adapter 的一个模式追加。
- 未来若要推翻的触发条件：出现成熟、活跃、覆盖全 provider 的 Dart 官方/准官方 SDK（则连 ADR-0004 一并重评）；或线协议碎片化到「3 族」不再成立。
