import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/adapters/openai_reasoning_params.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:flutter_test/flutter_test.dart';

LlmChatRequest _req({
  required String provider,
  required String modelId,
  String? baseUrl,
  String? effort,
  int? budget,
}) {
  return LlmChatRequest(
    model: Model(
      id: modelId,
      name: modelId,
      provider: provider,
      providerType: provider,
      baseUrl: baseUrl,
    ),
    messages: const [],
    reasoningEffort: effort,
    thinkingBudget: budget,
  );
}

void main() {
  group('openAiReasoningBodyParams', () {
    test('null / off / default send nothing', () {
      for (final effort in [null, 'off', 'default']) {
        expect(
          openAiReasoningBodyParams(
            _req(provider: 'openai', modelId: 'o3', effort: effort),
          ),
          isEmpty,
        );
      }
    });

    test('generic vendor keeps reasoning_effort', () {
      expect(
        openAiReasoningBodyParams(
          _req(provider: 'openai', modelId: 'o3', effort: 'medium'),
        ),
        {'reasoning_effort': 'medium'},
      );
    });

    test('generic vendor falls back to a supported level', () {
      // grok-3-mini supports only low/high.
      expect(
        openAiReasoningBodyParams(
          _req(provider: 'grok', modelId: 'grok-3-mini', effort: 'medium'),
        ),
        {'reasoning_effort': 'low'},
      );
    });

    test('DeepSeek official hybrid uses thinking.enabled', () {
      expect(
        openAiReasoningBodyParams(
          _req(
            provider: 'deepseek',
            modelId: 'deepseek-chat',
            baseUrl: 'https://api.deepseek.com',
            effort: 'high',
          ),
        ),
        {
          'thinking': {'type': 'enabled'},
        },
      );
    });

    test('DeepSeek V4+ adds high|max effort; none disables', () {
      expect(
        openAiReasoningBodyParams(
          _req(provider: 'deepseek', modelId: 'deepseek-v4', effort: 'xhigh'),
        ),
        {
          'thinking': {'type': 'enabled'},
          'reasoning_effort': 'max',
        },
      );
      expect(
        openAiReasoningBodyParams(
          _req(provider: 'deepseek', modelId: 'deepseek-v4', effort: 'none'),
        ),
        {
          'thinking': {'type': 'disabled'},
        },
      );
    });

    test('deepseek-reasoner / R1 sends nothing', () {
      expect(
        openAiReasoningBodyParams(
          _req(
            provider: 'deepseek',
            modelId: 'deepseek-reasoner',
            effort: 'high',
          ),
        ),
        isEmpty,
      );
    });

    test('OpenRouter maps to reasoning.effort (auto → medium)', () {
      expect(
        openAiReasoningBodyParams(
          _req(
            provider: 'openrouter',
            modelId: 'deepseek/deepseek-chat-v3.1',
            baseUrl: 'https://openrouter.ai/api/v1',
            effort: 'auto',
          ),
        ),
        {
          'reasoning': {'effort': 'medium'},
        },
      );
    });

    test('OpenRouter none disables and excludes', () {
      expect(
        openAiReasoningBodyParams(
          _req(provider: 'openrouter', modelId: 'openai/o3', effort: 'none'),
        ),
        {
          'reasoning': {'enabled': false, 'exclude': true},
        },
      );
    });

    test('DashScope qwen uses enable_thinking + thinking_budget', () {
      expect(
        openAiReasoningBodyParams(
          _req(
            provider: 'dashscope',
            modelId: 'qwen-plus',
            baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
            effort: 'high',
            budget: 4096,
          ),
        ),
        {'enable_thinking': true, 'thinking_budget': 4096},
      );
      expect(
        openAiReasoningBodyParams(
          _req(provider: 'dashscope', modelId: 'qwen-plus', effort: 'none'),
        ),
        {'enable_thinking': false},
      );
    });

    test('DashScope DeepSeek hybrid adds incremental_output', () {
      expect(
        openAiReasoningBodyParams(
          _req(
            provider: 'dashscope',
            modelId: 'deepseek-v3.1',
            effort: 'high',
          ),
        ),
        {'enable_thinking': true, 'incremental_output': true},
      );
    });

    test('SiliconFlow enforces a 32768 minimum budget', () {
      expect(
        openAiReasoningBodyParams(
          _req(
            provider: 'siliconflow',
            modelId: 'Qwen/Qwen3-32B',
            effort: 'high',
            budget: 1024,
          ),
        ),
        {'enable_thinking': true, 'thinking_budget': 32768},
      );
    });

    test('NVIDIA wraps params in chat_template_kwargs', () {
      expect(
        openAiReasoningBodyParams(
          _req(
            provider: 'nvidia',
            modelId: 'qwen/qwen3-235b-a22b',
            baseUrl: 'https://integrate.api.nvidia.com/v1',
            effort: 'high',
          ),
        ),
        {
          'chat_template_kwargs': {'enable_thinking': true},
        },
      );
      expect(
        openAiReasoningBodyParams(
          _req(
            provider: 'nvidia',
            modelId: 'deepseek-ai/deepseek-v3.1',
            effort: 'high',
          ),
        ),
        {
          'chat_template_kwargs': {'thinking': true},
        },
      );
    });

    test('zhipu / doubao / kimi thinking models use thinking.type', () {
      expect(
        openAiReasoningBodyParams(
          _req(provider: 'zhipu', modelId: 'glm-4.5', effort: 'high'),
        ),
        {
          'thinking': {'type': 'enabled'},
        },
      );
      expect(
        openAiReasoningBodyParams(
          _req(
            provider: 'volcengine',
            modelId: 'doubao-1-5-thinking-pro',
            effort: 'none',
          ),
        ),
        {
          'thinking': {'type': 'disabled'},
        },
      );
      expect(
        openAiReasoningBodyParams(
          _req(provider: 'moonshot', modelId: 'kimi-k2.5', effort: 'high'),
        ),
        {
          'thinking': {'type': 'enabled'},
        },
      );
    });

    test('doubao seed-1.6/1.8 use reasoning_effort directly', () {
      expect(
        openAiReasoningBodyParams(
          _req(
            provider: 'volcengine',
            modelId: 'doubao-seed-1-6-thinking',
            effort: 'auto',
          ),
        ),
        {'reasoning_effort': 'auto'},
      );
    });

    test('Together maps effort and enables reasoning', () {
      expect(
        openAiReasoningBodyParams(
          _req(
            provider: 'together',
            modelId: 'deepseek-ai/DeepSeek-R1',
            baseUrl: 'https://api.together.xyz/v1',
            effort: 'xhigh',
          ),
        ),
        {
          'reasoning_effort': 'high',
          'reasoning': {'enabled': true},
        },
      );
    });

    test('Groq sends nothing', () {
      expect(
        openAiReasoningBodyParams(
          _req(
            provider: 'groq',
            modelId: 'qwen/qwen3-32b',
            baseUrl: 'https://api.groq.com/openai/v1',
            effort: 'high',
          ),
        ),
        isEmpty,
      );
    });

    test('Gemini compat endpoint uses google thinking_config', () {
      expect(
        openAiReasoningBodyParams(
          _req(
            provider: 'custom',
            modelId: 'gemini-2.5-flash',
            effort: 'high',
            budget: 8192,
          ),
        ),
        {
          'extra_body': {
            'google': {
              'thinking_config': {
                'thinking_budget': 8192,
                'include_thoughts': true,
              },
            },
          },
        },
      );
      expect(
        openAiReasoningBodyParams(
          _req(provider: 'custom', modelId: 'gemini-2.5-flash', effort: 'none'),
        ),
        {
          'extra_body': {
            'google': {
              'thinking_config': {'thinking_budget': 0},
            },
          },
        },
      );
    });

    test('Claude via OpenAI-compat uses thinking budget_tokens', () {
      expect(
        openAiReasoningBodyParams(
          _req(
            provider: 'custom',
            modelId: 'claude-sonnet-4-5',
            effort: 'high',
            budget: 2048,
          ),
        ),
        {
          'thinking': {'type': 'enabled', 'budget_tokens': 2048},
        },
      );
    });

    test('vendor recognized by base URL host for custom providers', () {
      expect(
        openAiReasoningBodyParams(
          _req(
            provider: 'custom',
            modelId: 'deepseek-chat',
            baseUrl: 'https://api.deepseek.com/v1',
            effort: 'medium',
          ),
        ),
        {
          'thinking': {'type': 'enabled'},
        },
      );
    });
  });
}
