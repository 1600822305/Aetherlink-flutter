/// Persisted Notion 集成 settings shown on the 设置 → Notion 集成 page.
///
/// Framework-free so both the settings UI and the export service can share it.
/// The user pastes an integration token and a database ID/URL; the page then
/// resolves the database's data source (2025-09-03 API model: a database can
/// contain multiple data sources, and pages are created under a data source)
/// and stores the resolved [dataSourceId] plus the auto-detected title
/// property, so exports never need to re-discover the schema.
class NotionSettings {
  const NotionSettings({
    this.enabled = false,
    this.apiKey = '',
    this.databaseId = '',
    this.dataSourceId = '',
    this.dataSourceName = '',
    this.titleProperty = '',
    this.dateProperty = '',
    this.includeReasoning = false,
  });

  factory NotionSettings.fromJson(Map<String, dynamic> json) {
    return NotionSettings(
      enabled: json['enabled'] == true,
      apiKey: json['apiKey']?.toString() ?? '',
      databaseId: json['databaseId']?.toString() ?? '',
      dataSourceId: json['dataSourceId']?.toString() ?? '',
      dataSourceName: json['dataSourceName']?.toString() ?? '',
      titleProperty: json['titleProperty']?.toString() ?? '',
      dateProperty: json['dateProperty']?.toString() ?? '',
      includeReasoning: json['includeReasoning'] == true,
    );
  }

  final bool enabled;

  /// Notion internal-integration token（`ntn_` / `secret_` 开头）。
  final String apiKey;

  /// The database ID (or the ID pasted from a database URL) the user entered.
  final String databaseId;

  /// The resolved data source under [databaseId] that pages are created in.
  final String dataSourceId;

  /// Display name of the resolved data source (shown as connection state).
  final String dataSourceName;

  /// The data source's `title`-type property name (auto-detected on connect).
  final String titleProperty;

  /// Optional `date`-type property to stamp with the topic's creation date.
  /// Empty = not written.
  final String dateProperty;

  /// Whether topic exports include assistant thinking/reasoning traces.
  final bool includeReasoning;

  /// Ready to export: enabled with a token and a resolved data source.
  bool get isConfigured =>
      enabled &&
      apiKey.trim().isNotEmpty &&
      dataSourceId.isNotEmpty &&
      titleProperty.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'apiKey': apiKey,
    'databaseId': databaseId,
    'dataSourceId': dataSourceId,
    'dataSourceName': dataSourceName,
    'titleProperty': titleProperty,
    'dateProperty': dateProperty,
    'includeReasoning': includeReasoning,
  };

  NotionSettings copyWith({
    bool? enabled,
    String? apiKey,
    String? databaseId,
    String? dataSourceId,
    String? dataSourceName,
    String? titleProperty,
    String? dateProperty,
    bool? includeReasoning,
  }) {
    return NotionSettings(
      enabled: enabled ?? this.enabled,
      apiKey: apiKey ?? this.apiKey,
      databaseId: databaseId ?? this.databaseId,
      dataSourceId: dataSourceId ?? this.dataSourceId,
      dataSourceName: dataSourceName ?? this.dataSourceName,
      titleProperty: titleProperty ?? this.titleProperty,
      dateProperty: dateProperty ?? this.dateProperty,
      includeReasoning: includeReasoning ?? this.includeReasoning,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is NotionSettings &&
            enabled == other.enabled &&
            apiKey == other.apiKey &&
            databaseId == other.databaseId &&
            dataSourceId == other.dataSourceId &&
            dataSourceName == other.dataSourceName &&
            titleProperty == other.titleProperty &&
            dateProperty == other.dateProperty &&
            includeReasoning == other.includeReasoning;
  }

  @override
  int get hashCode => Object.hash(
    enabled,
    apiKey,
    databaseId,
    dataSourceId,
    dataSourceName,
    titleProperty,
    dateProperty,
    includeReasoning,
  );
}
