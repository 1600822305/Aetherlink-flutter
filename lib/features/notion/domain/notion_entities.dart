/// Pure value types for the Notion API (2025-09-03 model: database → data
/// sources → pages) plus the API error the client throws.
library;

/// A data source listed under a database (`GET /v1/databases/{id}`).
class NotionDataSourceRef {
  const NotionDataSourceRef({required this.id, required this.name});

  final String id;
  final String name;
}

/// A database: its title and the data sources it contains.
class NotionDatabase {
  const NotionDatabase({
    required this.id,
    required this.title,
    required this.dataSources,
  });

  final String id;
  final String title;
  final List<NotionDataSourceRef> dataSources;
}

/// One property of a data source's schema (`GET /v1/data_sources/{id}`).
class NotionProperty {
  const NotionProperty({required this.name, required this.type});

  final String name;

  /// Notion property type, e.g. `title`, `date`, `rich_text`.
  final String type;
}

/// A data source's schema: display name plus its property list.
class NotionDataSource {
  const NotionDataSource({
    required this.id,
    required this.name,
    required this.properties,
  });

  final String id;
  final String name;
  final List<NotionProperty> properties;

  /// The single `title`-type property every data source has.
  NotionProperty? get titleProperty {
    for (final property in properties) {
      if (property.type == 'title') return property;
    }
    return null;
  }

  /// All `date`-type properties (candidates for the optional date field).
  List<NotionProperty> get dateProperties =>
      properties.where((p) => p.type == 'date').toList();
}

/// The created page returned by `POST /v1/pages`.
class NotionPageResult {
  const NotionPageResult({required this.id, required this.url});

  final String id;
  final String url;
}

/// A Notion API failure with a user-facing Chinese message.
class NotionApiException implements Exception {
  const NotionApiException(this.message, {this.statusCode});

  factory NotionApiException.fromStatus(int? status, String? apiMessage) {
    final friendly = switch (status) {
      401 => 'API 密钥无效，请检查集成令牌',
      403 => '权限不足，请在 Notion 中将数据库连接到该集成',
      404 => '找不到数据库或数据源，请检查 ID 并确认已连接集成',
      429 => '请求过于频繁，请稍后重试',
      != null && >= 500 => 'Notion 服务器错误，请稍后重试',
      _ => null,
    };
    return NotionApiException(
      friendly ?? apiMessage ?? '请求失败（HTTP $status）',
      statusCode: status,
    );
  }

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
