import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// The built-in model providers, translated 1:1 (at the provider level) from
/// the original `getDefaultModelProviders()`
/// (`src/shared/config/defaultModels.ts`): same ids, names, avatars, colors,
/// base URLs, `providerType`s and enablement (only `model-combo` is enabled and
/// `isSystem`; every other vendor ships disabled with an empty `apiKey`).
///
/// NOTE: the per-provider preset model catalogs (the dozens of `gpt-*`,
/// `gemini-*`, `claude-*`… entries the original ships) are intentionally NOT
/// reproduced here — they are a large data set the model-config UI / a later
/// slice will populate, and the persistence layer already round-trips a
/// populated `models` list (proven by the data-layer tests). Each seed
/// provider therefore starts with an empty `models` list.
///
/// This is seed data only: it is never written automatically. A caller invokes
/// [seedDefaultModelProviders] (see `model_providers.dart`) explicitly; a fresh
/// install stays empty until then.
List<ModelProvider> defaultModelProviders() => const [
  ModelProvider(
    id: 'model-combo',
    name: '模型组合',
    avatar: '🧠',
    color: '#f43f5e',
    isEnabled: true,
    apiKey: '',
    baseUrl: '',
    isSystem: true,
  ),
  ModelProvider(
    id: 'openai',
    name: 'OpenAI',
    avatar: 'O',
    color: '#10a37f',
    isEnabled: false,
    apiKey: '',
    baseUrl: 'https://api.openai.com/v1',
    providerType: 'openai',
  ),
  ModelProvider(
    id: 'openai-aisdk',
    name: 'OpenAI (AI SDK)',
    avatar: '🚀',
    color: '#10a37f',
    isEnabled: false,
    apiKey: '',
    baseUrl: 'https://api.openai.com/v1',
    providerType: 'openai-aisdk',
  ),
  ModelProvider(
    id: 'gemini',
    name: 'Gemini',
    avatar: 'G',
    color: '#4285f4',
    isEnabled: false,
    apiKey: '',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    providerType: 'gemini',
  ),
  ModelProvider(
    id: 'anthropic',
    name: 'Anthropic',
    avatar: 'A',
    color: '#b83280',
    isEnabled: false,
    apiKey: '',
    baseUrl: 'https://api.anthropic.com/v1',
    providerType: 'anthropic',
  ),
  ModelProvider(
    id: 'deepseek',
    name: 'DeepSeek',
    avatar: 'D',
    color: '#754AB4',
    isEnabled: false,
    apiKey: '',
    baseUrl: 'https://api.deepseek.com',
    providerType: 'openai',
  ),
  ModelProvider(
    id: 'volcengine',
    name: '火山引擎',
    avatar: 'V',
    color: '#ff3d00',
    isEnabled: false,
    apiKey: '',
    baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
    providerType: 'volcengine',
  ),
  ModelProvider(
    id: 'zhipu',
    name: '智谱AI',
    avatar: '智',
    color: '#4f46e5',
    isEnabled: false,
    apiKey: '',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4/',
    providerType: 'zhipu',
  ),
  ModelProvider(
    id: 'minimax',
    name: 'MiniMax',
    avatar: 'M',
    color: '#ff6b6b',
    isEnabled: false,
    apiKey: '',
    baseUrl: 'https://api.minimaxi.com/v1',
    providerType: 'openai',
  ),
  ModelProvider(
    id: 'dashscope',
    name: '阿里云百炼',
    avatar: 'dashscope',
    color: '#ff6a00',
    isEnabled: false,
    apiKey: '',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    providerType: 'dashscope',
  ),
];
