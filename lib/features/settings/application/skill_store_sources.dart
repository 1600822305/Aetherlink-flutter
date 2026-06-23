import 'dart:convert';

import 'package:dio/dio.dart';

/// Unified data model for a skill from any marketplace source.
class StoreSkillItem {
  StoreSkillItem({
    required this.id,
    required this.name,
    required this.author,
    required this.description,
    required this.url,
    required this.source,
    this.stars = 0,
    this.downloads = 0,
  });

  final String id;
  final String name;
  final String author;
  final String description;
  final String url;
  final SkillStoreSource source;
  final int stars;
  final int downloads;
}

/// Search result from any source.
class StoreSearchResult {
  StoreSearchResult({
    required this.skills,
    required this.source,
    this.total = 0,
    this.hasMore = false,
    this.rateInfo = '',
  });

  final List<StoreSkillItem> skills;
  final SkillStoreSource source;
  final int total;
  final bool hasMore;
  final String rateInfo;
}

/// Available skill store data sources.
enum SkillStoreSource {
  skillsmp('SkillsMP', '170万+ 技能'),
  clawhub('ClawHub', '社区精选'),
  aiskillstore('AI Skill Store', 'USK 标准');

  const SkillStoreSource(this.label, this.subtitle);
  final String label;
  final String subtitle;
}

/// Fetches skills from ClawHub (OpenClaw).
/// No auth required, 3000 req/min rate limit.
Future<StoreSearchResult> searchClawHub({
  required Dio dio,
  required String query,
  int limit = 20,
  String sort = 'downloads',
}) async {
  final response = await dio.get<String>(
    'https://clawhub.ai/api/v1/search',
    queryParameters: <String, dynamic>{'q': query, 'limit': limit},
  );

  final body = jsonDecode(response.data!) as Map<String, dynamic>;
  final results = body['results'] as List<dynamic>? ?? [];

  final skills = results.map((e) {
    final item = e as Map<String, dynamic>;
    final owner = item['owner'] as Map<String, dynamic>?;
    final slug = item['slug'] as String? ?? '';
    final ownerHandle = item['ownerHandle'] as String? ?? '';
    return StoreSkillItem(
      id: slug,
      name: item['displayName'] as String? ?? slug,
      author: owner?['displayName'] as String? ?? ownerHandle,
      description: item['summary'] as String? ?? '',
      url: 'https://clawhub.ai/$ownerHandle/$slug',
      source: SkillStoreSource.clawhub,
      stars: 0,
      downloads: (item['downloads'] as num?)?.toInt() ?? 0,
    );
  }).toList();

  final remaining = response.headers.value('x-ratelimit-remaining') ?? '';
  final rateInfo = remaining.isNotEmpty ? '剩余 $remaining 次/分钟' : '';

  return StoreSearchResult(
    skills: skills,
    source: SkillStoreSource.clawhub,
    total: skills.length,
    hasMore: false,
    rateInfo: rateInfo,
  );
}

/// Fetches skills from AI Skill Store.
/// No auth required for reads, 20 req/day/IP rate limit.
Future<StoreSearchResult> searchAiSkillStore({
  required Dio dio,
  required String query,
  int limit = 20,
}) async {
  final response = await dio.get<String>(
    'https://www.aiskillstore.io/v1/agent/search',
    queryParameters: <String, dynamic>{'q': query, 'limit': limit},
  );

  final body = jsonDecode(response.data!) as Map<String, dynamic>;
  final results = body['skills'] as List<dynamic>? ?? [];

  final skills = results.map((e) {
    final item = e as Map<String, dynamic>;
    final skillId =
        item['skill_id'] as String? ?? item['name'] as String? ?? '';
    final name = item['name'] as String? ?? '';
    return StoreSkillItem(
      id: skillId,
      name: name,
      author: item['trust_level'] as String? ?? 'community',
      description: item['description'] as String? ?? '',
      url: 'https://www.aiskillstore.io/skills/$skillId',
      source: SkillStoreSource.aiskillstore,
      stars: 0,
      downloads: (item['download_count'] as num?)?.toInt() ?? 0,
    );
  }).toList();

  final count = (body['count'] as num?)?.toInt() ?? skills.length;

  return StoreSearchResult(
    skills: skills,
    source: SkillStoreSource.aiskillstore,
    total: count,
    hasMore: false,
    rateInfo: '20 次/天（匿名）',
  );
}
