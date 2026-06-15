// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_capabilities.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ModelCapabilities _$ModelCapabilitiesFromJson(Map<String, dynamic> json) =>
    _ModelCapabilities(
      multimodal: json['multimodal'] as bool?,
      vision: json['vision'] as bool?,
      imageGeneration: json['imageGeneration'] as bool?,
      videoGeneration: json['videoGeneration'] as bool?,
      webSearch: json['webSearch'] as bool?,
      reasoning: json['reasoning'] as bool?,
      functionCalling: json['functionCalling'] as bool?,
      toolUse: json['toolUse'] as bool?,
      embedding: json['embedding'] as bool?,
      rerank: json['rerank'] as bool?,
      codeGen: json['codeGen'] as bool?,
      translation: json['translation'] as bool?,
      transcription: json['transcription'] as bool?,
    );

Map<String, dynamic> _$ModelCapabilitiesToJson(_ModelCapabilities instance) =>
    <String, dynamic>{
      'multimodal': ?instance.multimodal,
      'vision': ?instance.vision,
      'imageGeneration': ?instance.imageGeneration,
      'videoGeneration': ?instance.videoGeneration,
      'webSearch': ?instance.webSearch,
      'reasoning': ?instance.reasoning,
      'functionCalling': ?instance.functionCalling,
      'toolUse': ?instance.toolUse,
      'embedding': ?instance.embedding,
      'rerank': ?instance.rerank,
      'codeGen': ?instance.codeGen,
      'translation': ?instance.translation,
      'transcription': ?instance.transcription,
    };
