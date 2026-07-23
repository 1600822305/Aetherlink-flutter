import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_capabilities.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/capability_inference.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_enricher.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_id_utils.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_registry.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/vendor_patterns.dart';
import 'package:aetherlink_flutter/shared/domain/model_type.dart';
import 'package:flutter_test/flutter_test.dart';

Model _m(String id) => Model(id: id, name: id, provider: 'p');

void main() {
  group('normalizeModelId', () {
    test('strips namespace, aggregator prefix, variant + size, version sep', () {
      expect(normalizeModelId('deepseek/DeepSeek-V3'), 'deepseek-v3');
      expect(normalizeModelId('siliconflow-qwen2.5-7b'), 'qwen2-5');
      expect(normalizeModelId('gpt-4o:free'), 'gpt-4o');
      // `mm-` is MiniMax shorthand and expands instead of being stripped as an
      // aggregator prefix (faithful to upstream normalize order).
      expect(normalizeModelId('mm-m2-1'), 'minimax-m2-1');
    });

    test('strips date snapshots, quantization and bedrock ARN decorations', () {
      expect(normalizeModelId('claude-sonnet-4-5-20250929'), normalizeModelId('claude-sonnet-4-5'));
      expect(normalizeModelId('gpt-4o-2024-08-06'), 'gpt-4o');
      expect(normalizeModelId('glm-4-5-fp8'), 'glm-4-5');
      expect(normalizeModelId('us.anthropic.claude-sonnet-4-5-v1:0'), normalizeModelId('claude-sonnet-4-5'));
      // sizes/versions are not eaten by the date pattern
      expect(normalizeModelId('qwen3-235b'), 'qwen3');
      expect(normalizeModelId('bce-embedding-base_v1'), 'bce-embedding-base-v1');
    });

    test('colon size/quant tags: realignment and size-preserving key', () {
      expect(colonVariantTagToHyphen('gpt-oss:20b'), 'gpt-oss-20b');
      expect(colonVariantTagToHyphen('mixtral:8x7b'), 'mixtral-8x7b');
      expect(colonVariantTagToHyphen('gemma3:q8_0'), 'gemma3-q8_0');
      expect(colonVariantTagToHyphen('some-model:free'), 'some-model:free');
      // default (size-agnostic) key collapses sizes
      expect(normalizeModelId('gpt-oss-20b'), 'gpt-oss');
      expect(normalizeModelId('gpt-oss-120b'), 'gpt-oss');
      // size-preserving key keeps distinct sizes distinct
      expect(normalizeModelId('gpt-oss:20b', keepParameterSize: true), 'gpt-oss-20b');
      expect(normalizeModelId('gpt-oss:120b', keepParameterSize: true), 'gpt-oss-120b');
      expect(normalizeModelId('qwen2.5:7b', keepParameterSize: true), 'qwen2-5-7b');
    });

    test('lowerBaseModelName strips provider prefix + :free', () {
      expect(lowerBaseModelName('openai/GPT-4o'), 'gpt-4o');
      expect(lowerBaseModelName('qwen-max:free'), 'qwen-max');
    });
  });

  group('vendorPatterns', () {
    test('classifies common vendors', () {
      expect(matchVendor('claude-sonnet-4-5'), 'anthropic');
      expect(matchVendor('gemini-2.5-pro'), 'gemini');
      expect(matchVendor('gpt-4o'), 'openai');
      expect(matchVendor('o3-mini'), 'openai');
      expect(matchVendor('qwen3-max'), 'qwen');
      expect(matchVendor('deepseek-r1'), 'deepseek');
      expect(matchVendor('glm-4.6'), 'zhipu');
      expect(matchVendor('totally-unknown-model'), isNull);
    });
  });

  group('inference: reasoning', () {
    test('positive cases', () {
      for (final id in [
        'o1',
        'o3-mini',
        'deepseek-r1',
        'deepseek-reasoner',
        'qwq-32b',
        'gpt-5',
        'claude-sonnet-4-5',
        'grok-4',
        'gemini-2.5-pro',
        'glm-4.6',
      ]) {
        expect(inferReasoningFromModelId(id), isTrue, reason: id);
      }
    });

    test('negative cases', () {
      for (final id in ['gpt-4o', 'gpt-5-chat', 'text-embedding-3-large', 'dall-e-3']) {
        expect(inferReasoningFromModelId(id), isFalse, reason: id);
      }
    });
  });

  group('inference: vision', () {
    test('positive', () {
      for (final id in ['gpt-4o', 'claude-3-opus', 'gemini-2.5-flash', 'qwen2.5-vl-7b', 'gpt-4.1']) {
        expect(inferVisionFromModelId(id), isTrue, reason: id);
      }
    });
    test('negative', () {
      for (final id in ['o1-mini', 'o3-mini', 'text-embedding-3-large', 'deepseek-chat', 'qwen-max']) {
        expect(inferVisionFromModelId(id), isFalse, reason: id);
      }
    });
  });

  group('inference: embedding / rerank', () {
    test('embedding', () {
      expect(inferEmbeddingFromModelId('text-embedding-3-large'), isTrue);
      expect(inferEmbeddingFromModelId('bge-m3'), isTrue);
      expect(inferEmbeddingFromModelId('gpt-4o'), isFalse);
    });
    test('rerank excluded from embedding', () {
      expect(inferRerankFromModelId('bge-reranker-v2-m3'), isTrue);
      expect(inferEmbeddingFromModelId('bge-reranker-v2-m3'), isFalse);
    });
  });

  group('inference: image generation', () {
    test('dedicated image models', () {
      for (final id in ['dall-e-3', 'flux-1-schnell', 'gpt-image-1', 'imagen-3', 'qwen-image']) {
        expect(inferImageGenerationFromModelId(id), isTrue, reason: id);
      }
    });
    test('chat models are not image-gen', () {
      expect(inferImageGenerationFromModelId('gpt-4o'), isFalse);
    });
  });

  group('inference: function calling', () {
    test('positive', () {
      for (final id in ['gpt-4o', 'claude-sonnet-4-5', 'qwen3-max', 'deepseek-chat', 'gemini-2.5-pro']) {
        expect(inferFunctionCallingFromModelId(id), isTrue, reason: id);
      }
    });
    test('negative (embedding / image / excluded)', () {
      for (final id in ['text-embedding-3-large', 'dall-e-3', 'o1-mini', 'gpt-5-chat']) {
        expect(inferFunctionCallingFromModelId(id), isFalse, reason: id);
      }
    });
  });

  group('inference: web search', () {
    test('positive', () {
      expect(inferWebSearchFromModelId('gpt-4o-search-preview'), isTrue);
      expect(inferWebSearchFromModelId('sonar-pro'), isTrue);
      expect(inferWebSearchFromModelId('claude-sonnet-4-5'), isTrue);
    });
  });

  group('inferCapabilitiesFromModelId', () {
    test('gpt-4o → vision + function-call + web-search, not embedding', () {
      final c = inferCapabilitiesFromModelId('gpt-4o')!;
      expect(c.vision, isTrue);
      expect(c.multimodal, isTrue);
      expect(c.functionCalling, isTrue);
      expect(c.embedding, isNull);
    });
    test('unknown model → null', () {
      expect(inferCapabilitiesFromModelId('totally-unknown-xyz'), isNull);
    });
  });

  group('runtime checks read fields (no regex)', () {
    test('modelTypes override wins', () {
      final model = _m('totally-unknown').copyWith(modelTypes: [ModelType.vision]);
      expect(isVisionModel(model), isTrue);
    });
    test('capabilities field is read', () {
      final model = _m('x').copyWith(capabilities: const ModelCapabilities(reasoning: true));
      expect(isReasoningModel(model), isTrue);
    });
    test('empty model → all false', () {
      final model = _m('x');
      expect(isVisionModel(model), isFalse);
      expect(isReasoningModel(model), isFalse);
      expect(isFunctionCallingModel(model), isFalse);
    });
  });

  group('registry mapping', () {
    test('maps wire vocabulary to ModelCapabilities', () {
      final c = mapRegistryEntryToCapabilities(
        capabilities: ['function-call', 'reasoning', 'image-recognition'],
        inputModalities: ['text', 'image'],
      )!;
      expect(c.functionCalling, isTrue);
      expect(c.toolUse, isTrue);
      expect(c.reasoning, isTrue);
      expect(c.vision, isTrue);
      expect(c.multimodal, isTrue);
    });

    test('fromJsonString indexes by id + normalized id', () {
      final reg = ModelRegistry.fromJsonString(
        '{"version":"t","models":[{"i":"DeepSeek-V3","c":["function-call","reasoning"],"in":["text"]}]}',
      );
      expect(reg.capabilitiesFor('DeepSeek-V3')!.reasoning, isTrue);
      expect(reg.capabilitiesFor('deepseek/deepseek-v3')!.functionCalling, isTrue);
    });

    test('colon size tag resolves to its own-size row, not a sibling', () {
      final reg = ModelRegistry.fromJsonString(
        '{"models":['
        '{"i":"gpt-oss-120b","c":["function-call"],"in":["text"]},'
        '{"i":"gpt-oss-20b","c":["reasoning"],"in":["text"]}'
        ']}',
      );
      expect(reg.capabilitiesFor('gpt-oss:20b')!.reasoning, isTrue);
      expect(reg.capabilitiesFor('gpt-oss:120b')!.functionCalling, isTrue);
      // no exact-size row → null rather than a wrong-size guess
      expect(reg.capabilitiesFor('mixtral:8x7b'), isNull);
    });
  });

  group('capabilitiesToModelTypes', () {
    test('chat is implied for conversational models', () {
      final t = capabilitiesToModelTypes(
        const ModelCapabilities(vision: true, functionCalling: true, reasoning: true),
      );
      expect(t, containsAll([ModelType.vision, ModelType.functionCalling, ModelType.reasoning, ModelType.chat]));
    });

    test('pure embedding model does not imply chat', () {
      final t = capabilitiesToModelTypes(const ModelCapabilities(embedding: true));
      expect(t, {ModelType.embedding});
    });

    test('dedicated image generator does not imply chat', () {
      final t = capabilitiesToModelTypes(const ModelCapabilities(imageGeneration: true));
      expect(t, {ModelType.imageGen});
    });

    test('null capabilities → empty set', () {
      expect(capabilitiesToModelTypes(null), isEmpty);
    });
  });

  group('enricher', () {
    test('registry wins over inference', () async {
      final reg = ModelRegistry.fromJsonString(
        '{"models":[{"i":"custom-vision-x","c":["image-recognition"],"in":["text","image"]}]}',
      );
      final model = await enrichModel(_m('custom-vision-x'), registry: reg);
      expect(model.capabilities!.vision, isTrue);
    });

    test('falls back to inference for unknown model', () async {
      final reg = ModelRegistry.fromJsonString('{"models":[]}');
      final model = await enrichModel(_m('gpt-4o'), registry: reg);
      expect(model.capabilities!.functionCalling, isTrue);
    });

    test('preserves models that already have capabilities', () async {
      final reg = ModelRegistry.fromJsonString('{"models":[]}');
      final original = _m('gpt-4o').copyWith(capabilities: const ModelCapabilities(embedding: true));
      final model = await enrichModel(original, registry: reg);
      expect(model.capabilities!.embedding, isTrue);
      expect(model.capabilities!.functionCalling, isNull);
    });
  });
}
