import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/core/network/dio_client.dart';
import 'package:aetherlink_flutter/features/notion/domain/notion_entities.dart';

/// Thin Notion REST client (API version 2025-09-03).
///
/// In this API model a database contains one or more *data sources*, and pages
/// are created under a data source (`parent.data_source_id`) rather than the
/// database itself. Page content is sent as the `markdown` body parameter, so
/// no client-side markdown→block conversion is needed.
class NotionClient {
  NotionClient({required String apiKey, Dio? dio})
    : _dio =
          dio ??
          buildAppDio(
            options: BaseOptions(
              baseUrl: 'https://api.notion.com',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
              headers: {
                'Authorization': 'Bearer $apiKey',
                'Notion-Version': _apiVersion,
                'Content-Type': 'application/json',
              },
            ),
          );

  static const String _apiVersion = '2025-09-03';

  final Dio _dio;

  /// Extracts a 32-hex-char Notion ID from raw input — a bare ID (with or
  /// without dashes) or a pasted database/page URL.
  static String? parseId(String input) {
    final compact = input.trim().replaceAll('-', '');
    final match = RegExp(r'[0-9a-fA-F]{32}').firstMatch(compact);
    return match?.group(0)?.toLowerCase();
  }

  /// `GET /v1/databases/{id}` — the database title and its data sources.
  Future<NotionDatabase> retrieveDatabase(String databaseId) async {
    final data = await _request('GET', '/v1/databases/$databaseId');
    final sources = (data['data_sources'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(
          (s) => NotionDataSourceRef(
            id: s['id']?.toString() ?? '',
            name: s['name']?.toString() ?? '',
          ),
        )
        .toList();
    return NotionDatabase(
      id: data['id']?.toString() ?? databaseId,
      title: _plainTitle(data['title']),
      dataSources: sources,
    );
  }

  /// `GET /v1/data_sources/{id}` — the data source's property schema.
  Future<NotionDataSource> retrieveDataSource(String dataSourceId) async {
    final data = await _request('GET', '/v1/data_sources/$dataSourceId');
    final rawProperties = data['properties'];
    final properties = <NotionProperty>[
      if (rawProperties is Map<String, dynamic>)
        for (final entry in rawProperties.entries)
          if (entry.value is Map<String, dynamic>)
            NotionProperty(
              name: entry.key,
              type: (entry.value as Map<String, dynamic>)['type']?.toString() ??
                  '',
            ),
    ];
    return NotionDataSource(
      id: data['id']?.toString() ?? dataSourceId,
      name: _plainTitle(data['title']),
      properties: properties,
    );
  }

  /// `POST /v1/pages` — creates a page under [dataSourceId] with the given
  /// title/date properties and [markdown] content.
  Future<NotionPageResult> createPage({
    required String dataSourceId,
    required String titleProperty,
    required String title,
    String? dateProperty,
    DateTime? date,
    required String markdown,
  }) async {
    final properties = <String, dynamic>{
      titleProperty: {
        'title': [
          {
            'text': {'content': title},
          },
        ],
      },
      if (dateProperty != null && dateProperty.isNotEmpty && date != null)
        dateProperty: {
          'date': {'start': _formatDate(date)},
        },
    };
    final data = await _request(
      'POST',
      '/v1/pages',
      body: {
        'parent': {'type': 'data_source_id', 'data_source_id': dataSourceId},
        'properties': properties,
        'markdown': markdown,
      },
    );
    return NotionPageResult(
      id: data['id']?.toString() ?? '',
      url: data['url']?.toString() ?? '',
    );
  }

  void close() => _dio.close(force: true);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(method: method),
      );
      return response.data ?? const {};
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      String? apiMessage;
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        apiMessage = data['message']?.toString();
      }
      if (status == null) {
        throw const NotionApiException('网络连接失败，请检查网络设置');
      }
      throw NotionApiException.fromStatus(status, apiMessage);
    }
  }

  static String _plainTitle(dynamic title) {
    if (title is! List) return '';
    return title
        .whereType<Map<String, dynamic>>()
        .map((t) => t['plain_text']?.toString() ?? '')
        .join();
  }

  static String _formatDate(DateTime date) {
    final d = date.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}
