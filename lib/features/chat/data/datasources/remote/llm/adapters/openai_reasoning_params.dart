import 'dart:math' as math;

import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/reasoning_model_detection.dart';

/// Vendor-aware reasoning ("思考程度") wire params for the OpenAI-compatible
/// Chat Completions protocol.
///
/// Port of Cherry Studio's `getReasoningEffort`
/// (`src/main/ai/utils/reasoning.ts`): vendors disagree on how thinking is
/// controlled — `reasoning_effort` (OpenAI), `thinking: {type}` (DeepSeek /
/// doubao / zhipu / kimi), `enable_thinking` (DashScope / SiliconFlow),
/// `chat_template_kwargs` (NVIDIA / local servers), `reasoning: {…}`
/// (OpenRouter / Together), `extra_body` (Poe / Gemini compat) — and most
/// reject the params of the others with HTTP 400.
///
/// The vendor is resolved from the provider key + base URL host
/// ([_vendorOf]); the model family from its id. `thinking_budget`-style
/// params use the user's `thinkingBudget` parameter when set.
Map<String, dynamic> openAiReasoningBodyParams(LlmChatRequest request) {
  final effort = request.reasoningEffort;
  if (effort == null || effort == 'off' || effort == 'default') {
    return const {};
  }

  final model = request.model;
  final id = model.id;
  final vendor = _vendorOf(model);

  // Groq exposes no thinking control on chat completions.
  if (vendor == _Vendor.groq) return const {};

  if (effort == 'none') return _disableParams(vendor, id);
  return _enableParams(vendor, id, effort, request.thinkingBudget);
}

// ─── Explicit off ────────────────────────────────────────────────────────────

Map<String, dynamic> _disableParams(_Vendor vendor, String id) {
  switch (vendor) {
    case _Vendor.openrouter:
      if (_supportsNoneEffort(id)) {
        return const {
          'reasoning': {'effort': 'none'},
        };
      }
      return const {
        'reasoning': {'enabled': false, 'exclude': true},
      };
    case _Vendor.nvidia:
      if (isQwenReasoningModelId(id) || isZhipuThinkingModelId(id)) {
        return const {
          'chat_template_kwargs': {'enable_thinking': false},
        };
      }
      if (isDeepSeekHybridModelId(id) || isKimiThinkingModelId(id)) {
        return const {
          'chat_template_kwargs': {'thinking': false},
        };
      }
      return const {};
    case _Vendor.dashscope:
    case _Vendor.siliconflow:
      if (isQwenReasoningModelId(id) ||
          isHunyuanThinkingModelId(id) ||
          isDeepSeekHybridModelId(id) ||
          isZhipuThinkingModelId(id) ||
          isKimiThinkingModelId(id)) {
        return const {'enable_thinking': false};
      }
      return const {};
    case _Vendor.together:
      return const {
        'reasoning': {'enabled': false},
      };
    case _Vendor.ollama:
    case _Vendor.lmstudio:
      if (isQwenReasoningModelId(id)) {
        return const {
          'chat_template_kwargs': {'enable_thinking': false},
        };
      }
      return const {};
    default:
      break;
  }

  if (isQwenReasoningModelId(id) || isHunyuanThinkingModelId(id)) {
    return const {'enable_thinking': false};
  }
  if (isGeminiThinkingModelId(id)) {
    if (isGeminiFlashModelId(id)) {
      return const {
        'extra_body': {
          'google': {
            'thinking_config': {'thinking_budget': 0},
          },
        },
      };
    }
    return const {}; // Pro cannot disable thinking.
  }
  if (isDoubaoThinkingModelId(id) ||
      isZhipuThinkingModelId(id) ||
      isKimiThinkingModelId(id) ||
      isMimoThinkingModelId(id)) {
    if (vendor == _Vendor.cerebras) return const {'disable_reasoning': true};
    return const {
      'thinking': {'type': 'disabled'},
    };
  }
  if (isDeepSeekV4PlusModelId(id)) {
    return const {
      'thinking': {'type': 'disabled'},
    };
  }
  // DeepSeek V3.x hybrid defaults to non-thinking; send nothing.
  if (isDeepSeekHybridModelId(id) || isDeepSeekReasonerModelId(id)) {
    return const {};
  }
  // GPT-5.1 / 5.2 accept `reasoning_effort: none`.
  if (_supportsNoneEffort(id)) return const {'reasoning_effort': 'none'};
  return const {};
}

// ─── Effort selected ─────────────────────────────────────────────────────────

Map<String, dynamic> _enableParams(
  _Vendor vendor,
  String id,
  String effort,
  int? budget,
) {
  switch (vendor) {
    case _Vendor.poe:
      if (isOpenAiReasoningModelId(id)) {
        return {
          'extra_body': {
            'reasoning_effort': effort == 'auto' ? 'medium' : effort,
          },
        };
      }
      if (isClaudeThinkingModelId(id) || isGeminiThinkingModelId(id)) {
        return {
          'extra_body': {'thinking_budget': budget ?? -1},
        };
      }
      return const {};
    case _Vendor.openrouter:
      if (isGrok4FastModelId(id)) {
        return const {
          'reasoning': {'enabled': true},
        };
      }
      return {
        'reasoning': {'effort': effort == 'auto' ? 'medium' : effort},
      };
    case _Vendor.nvidia:
      if (isQwenReasoningModelId(id)) {
        return {
          'chat_template_kwargs': {
            if (!isQwenAlwaysThinkModelId(id)) 'enable_thinking': true,
            if (budget != null) 'thinking_budget': budget,
          },
        };
      }
      if (isDeepSeekHybridModelId(id) || isKimiThinkingModelId(id)) {
        return const {
          'chat_template_kwargs': {'thinking': true},
        };
      }
      if (isZhipuThinkingModelId(id)) {
        return const {
          'chat_template_kwargs': {'enable_thinking': true},
        };
      }
      return const {};
    case _Vendor.siliconflow:
      if (isDeepSeekHybridModelId(id) ||
          isZhipuThinkingModelId(id) ||
          isQwenReasoningModelId(id) ||
          isHunyuanThinkingModelId(id)) {
        return {
          'enable_thinking': true,
          if (budget != null) 'thinking_budget': math.max(budget, 32768),
        };
      }
      return const {};
    case _Vendor.together:
      return {
        'reasoning_effort': switch (effort) {
          'minimal' => 'low',
          'xhigh' => 'high',
          'auto' => 'medium',
          _ => effort,
        },
        'reasoning': const {'enabled': true},
      };
    default:
      break;
  }

  // DeepSeek V4+: thinking control plus a high|max effort knob.
  if (isDeepSeekV4PlusModelId(id)) {
    return {
      'thinking': const {'type': 'enabled'},
      'reasoning_effort': effort == 'xhigh' ? 'max' : 'high',
    };
  }
  if (isDeepSeekHybridModelId(id)) {
    if (vendor == _Vendor.dashscope) {
      return const {'enable_thinking': true, 'incremental_output': true};
    }
    return const {
      'thinking': {'type': 'enabled'},
    };
  }
  // Always-thinking DeepSeek (reasoner / R1): no control params.
  if (isDeepSeekReasonerModelId(id)) return const {};

  if (vendor == _Vendor.dashscope &&
      (isZhipuThinkingModelId(id) || isKimiThinkingModelId(id))) {
    return {
      'enable_thinking': true,
      if (budget != null) 'thinking_budget': budget,
    };
  }
  if (isQwenReasoningModelId(id)) {
    final config = <String, dynamic>{
      if (!isQwenAlwaysThinkModelId(id)) 'enable_thinking': true,
      if (budget != null) 'thinking_budget': budget,
    };
    if (vendor == _Vendor.ollama || vendor == _Vendor.lmstudio) {
      return {'chat_template_kwargs': config};
    }
    return config;
  }
  if (isHunyuanThinkingModelId(id)) return const {'enable_thinking': true};

  if (isGeminiThinkingModelId(id)) {
    // https://ai.google.dev/gemini-api/docs/openai — Gemini 3 takes
    // reasoning_effort directly; 2.x takes a google thinking_config.
    if (isGemini3ThinkingModelId(id)) return {'reasoning_effort': effort};
    return {
      'extra_body': {
        'google': {
          'thinking_config': {
            'thinking_budget': effort == 'auto' ? -1 : (budget ?? -1),
            'include_thoughts': true,
          },
        },
      },
    };
  }
  if (isClaudeThinkingModelId(id)) {
    return {
      'thinking': {
        'type': 'enabled',
        if (budget != null) 'budget_tokens': budget,
      },
    };
  }
  if (isDoubaoThinkingModelId(id)) {
    if (isDoubaoAfter251015ModelId(id)) return {'reasoning_effort': effort};
    if (effort == 'high') {
      return const {
        'thinking': {'type': 'enabled'},
      };
    }
    if (effort == 'auto' && isDoubaoAutoThinkingModelId(id)) {
      return const {
        'thinking': {'type': 'auto'},
      };
    }
    return const {};
  }
  if (isZhipuThinkingModelId(id)) {
    if (vendor == _Vendor.cerebras) return const {};
    return const {
      'thinking': {'type': 'enabled'},
    };
  }
  if (isMimoThinkingModelId(id) || isKimiThinkingModelId(id)) {
    return const {
      'thinking': {'type': 'enabled'},
    };
  }
  // Grok 4 Fast outside OpenRouter has no effort control.
  if (isGrok4FastModelId(id)) return const {};

  // Generic `reasoning_effort` path (OpenAI o/gpt-5, grok-3-mini, perplexity,
  // unknown gateways): send the effort when the model's option set allows it,
  // otherwise fall back to the first supported level.
  final supported = getReasoningEffortOptions(id)
      .map((o) => o.value.toString())
      .where((v) => v != 'default' && v != 'none' && v != 'off' && v != 'auto')
      .toList();
  if (supported.contains(effort)) return {'reasoning_effort': effort};
  if (supported.isNotEmpty) return {'reasoning_effort': supported.first};
  return const {};
}

/// GPT-5.1 / 5.2 series accept `reasoning_effort: none`.
bool _supportsNoneEffort(String id) {
  final type = getThinkModelType(id);
  return type == ThinkingModelType.gpt5_1 ||
      type == ThinkingModelType.gpt5_1Codex ||
      type == ThinkingModelType.gpt5_1CodexMax ||
      type == ThinkingModelType.gpt5_2 ||
      type == ThinkingModelType.gpt52pro;
}

// ─── Vendor resolution ───────────────────────────────────────────────────────

enum _Vendor {
  deepseek,
  dashscope,
  siliconflow,
  openrouter,
  nvidia,
  doubao,
  zhipu,
  kimi,
  hunyuan,
  together,
  poe,
  groq,
  cerebras,
  ollama,
  lmstudio,
  other,
}

/// Resolves the serving vendor from the provider key (`providerType` /
/// `provider`) and the base-URL host. Custom providers get recognized by
/// host so official endpoints behave correctly regardless of the id the
/// user picked.
_Vendor _vendorOf(Model model) {
  final key = (model.providerType ?? model.provider).toLowerCase();
  final host =
      (Uri.tryParse(model.baseUrl ?? '')?.host ?? '').toLowerCase();
  final port = Uri.tryParse(model.baseUrl ?? '')?.port;

  bool hostIs(String h) => host == h || host.endsWith('.$h');

  if (key == 'deepseek' || hostIs('api.deepseek.com')) return _Vendor.deepseek;
  if (key == 'dashscope' || hostIs('dashscope.aliyuncs.com')) {
    return _Vendor.dashscope;
  }
  if (key == 'siliconflow' ||
      key == 'silicon' ||
      hostIs('api.siliconflow.cn') ||
      hostIs('api.siliconflow.com')) {
    return _Vendor.siliconflow;
  }
  if (key == 'openrouter' || hostIs('openrouter.ai')) return _Vendor.openrouter;
  if (key == 'nvidia' || hostIs('integrate.api.nvidia.com')) {
    return _Vendor.nvidia;
  }
  if (key == 'volcengine' || key == 'doubao' || hostIs('volces.com')) {
    return _Vendor.doubao;
  }
  if (key == 'zhipu' || hostIs('open.bigmodel.cn') || hostIs('api.z.ai')) {
    return _Vendor.zhipu;
  }
  if (key == 'moonshot' ||
      key == 'kimi' ||
      hostIs('api.moonshot.cn') ||
      hostIs('api.moonshot.ai')) {
    return _Vendor.kimi;
  }
  if (key == 'hunyuan' || hostIs('api.hunyuan.cloud.tencent.com')) {
    return _Vendor.hunyuan;
  }
  if (key == 'together' || hostIs('api.together.xyz')) return _Vendor.together;
  if (key == 'poe' || hostIs('api.poe.com')) return _Vendor.poe;
  if (key == 'groq' || hostIs('api.groq.com')) return _Vendor.groq;
  if (key == 'cerebras' || hostIs('api.cerebras.ai')) return _Vendor.cerebras;
  if (key == 'ollama' || (hostIs('localhost') && port == 11434)) {
    return _Vendor.ollama;
  }
  if (key == 'lmstudio' || (hostIs('localhost') && port == 1234)) {
    return _Vendor.lmstudio;
  }
  return _Vendor.other;
}
