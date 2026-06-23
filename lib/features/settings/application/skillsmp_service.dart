import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';

part 'skillsmp_service.g.dart';

/// Storage key for the SkillsMP API Key.
const String kSkillsMpApiKeySettingKey = 'skillsmp_api_key';

/// A single skill result from the SkillsMP search API.
class SkillsMpItem {
  SkillsMpItem({
    required this.id,
    required this.name,
    required this.author,
    required this.description,
    required this.githubUrl,
    required this.skillUrl,
    required this.stars,
    required this.updatedAt,
  });

  factory SkillsMpItem.fromJson(Map<String, dynamic> json) => SkillsMpItem(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    author: json['author']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    githubUrl: json['githubUrl']?.toString() ?? '',
    skillUrl: json['skillUrl']?.toString() ?? '',
    stars: (json['stars'] as num?)?.toInt() ?? 0,
    updatedAt: json['updatedAt']?.toString() ?? '',
  );

  final String id;
  final String name;
  final String author;
  final String description;
  final String githubUrl;
  final String skillUrl;
  final int stars;
  final String updatedAt;
}

/// Search result from SkillsMP API.
class SkillsMpSearchResult {
  SkillsMpSearchResult({
    required this.skills,
    required this.total,
    required this.page,
    required this.limit,
    required this.dailyRemaining,
  });

  final List<SkillsMpItem> skills;
  final int total;
  final int page;
  final int limit;
  final int dailyRemaining;
}

/// Service for interacting with the SkillsMP public API.
@Riverpod(keepAlive: true)
class SkillsMpService extends _$SkillsMpService {
  static const String _baseUrl = 'https://skillsmp.com/api/v1';

  late final Dio _dio;

  @override
  String? build() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    // Load the stored API key (synchronous since we kick off from the KV).
    _loadApiKey();
    return null;
  }

  Future<void> _loadApiKey() async {
    final raw = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kSkillsMpApiKeySettingKey);
    if (raw != null && raw.trim().isNotEmpty) {
      state = raw.trim();
    }
  }

  /// Save or clear the API key.
  Future<void> setApiKey(String? key) async {
    final trimmed = key?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await ref
          .read(appSettingsStoreProvider)
          .saveSetting(kSkillsMpApiKeySettingKey, '');
      state = null;
    } else {
      await ref
          .read(appSettingsStoreProvider)
          .saveSetting(kSkillsMpApiKeySettingKey, trimmed);
      state = trimmed;
    }
  }

  /// Search skills on SkillsMP.
  Future<SkillsMpSearchResult> search({
    required String query,
    int page = 1,
    int limit = 20,
    String sortBy = 'stars',
    String? category,
    String? occupation,
  }) async {
    final params = <String, dynamic>{
      'q': query,
      'page': page,
      'limit': limit,
      'sortBy': sortBy,
    };
    if (category != null) params['category'] = category;
    if (occupation != null) params['occupation'] = occupation;

    final headers = <String, String>{};
    final apiKey = state;
    if (apiKey != null && apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final response = await _dio.get<String>(
      '/skills/search',
      queryParameters: params,
      options: Options(headers: headers),
    );

    final body = jsonDecode(response.data!) as Map<String, dynamic>;
    if (body['success'] != true) {
      final error = body['error'] as Map<String, dynamic>?;
      throw Exception(error?['message'] ?? '搜索失败');
    }

    final data = body['data'] as Map<String, dynamic>;
    final skills = (data['skills'] as List<dynamic>)
        .map((e) => SkillsMpItem.fromJson(e as Map<String, dynamic>))
        .toList();

    // Extract rate limit info from headers.
    final dailyRemaining =
        int.tryParse(
          response.headers.value('x-ratelimit-daily-remaining') ?? '',
        ) ??
        -1;

    return SkillsMpSearchResult(
      skills: skills,
      total: (data['total'] as num?)?.toInt() ?? skills.length,
      page: (data['page'] as num?)?.toInt() ?? page,
      limit: (data['limit'] as num?)?.toInt() ?? limit,
      dailyRemaining: dailyRemaining,
    );
  }
}
