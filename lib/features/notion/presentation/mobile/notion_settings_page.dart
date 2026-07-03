import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/notion/application/notion_settings_controller.dart';
import 'package:aetherlink_flutter/features/notion/data/notion_client.dart';
import 'package:aetherlink_flutter/features/notion/domain/notion_entities.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/widgets/app_select_field.dart';

/// 设置 → Notion 集成：configure the integration token and target database,
/// resolve its data source (2025-09-03 API model) and pick the optional date
/// property. Exports are triggered from the topic menu / 消息导出 sheet.
class NotionSettingsPage extends ConsumerStatefulWidget {
  const NotionSettingsPage({super.key});

  @override
  ConsumerState<NotionSettingsPage> createState() => _NotionSettingsPageState();
}

class _NotionSettingsPageState extends ConsumerState<NotionSettingsPage> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _databaseIdController;

  bool _connecting = false;
  String? _connectError;

  /// Set when the entered database has multiple data sources and the user
  /// must pick one.
  List<NotionDataSourceRef>? _sourceChoices;

  /// The date-type properties of the connected data source (candidates for
  /// the optional date field).
  List<String> _dateChoices = const [];

  @override
  void initState() {
    super.initState();
    final settings = ref.read(notionSettingsControllerProvider);
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _databaseIdController = TextEditingController(text: settings.databaseId);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _databaseIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(notionSettingsControllerProvider);
    final controller = ref.read(notionSettingsControllerProvider.notifier);
    final connected = settings.dataSourceId.isNotEmpty;

    return Scaffold(
      appBar: const ModelSettingsAppBar(title: 'Notion 集成'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ModelSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModelSectionTitle('连接配置'),
                const SizedBox(height: 16),
                _SwitchRow(
                  title: '启用 Notion 导出',
                  description: '开启后可将话题或选中的消息导出为 Notion 页面',
                  value: settings.enabled,
                  onChanged: controller.setEnabled,
                ),
                const SizedBox(height: 16),
                ModelFormField(
                  label: 'API 密钥',
                  hint: 'ntn_xxx / secret_xxx',
                  helper: '在 Notion 集成管理页创建内部集成后获取',
                  controller: _apiKeyController,
                  obscureText: true,
                  onChanged: (v) {
                    controller.setApiKey(v);
                    _resetConnectState();
                  },
                ),
                const SizedBox(height: 16),
                ModelFormField(
                  label: '数据库 ID 或链接',
                  hint: '粘贴数据库链接或 32 位 ID',
                  controller: _databaseIdController,
                  onChanged: (v) {
                    controller.setDatabaseId(v);
                    _resetConnectState();
                  },
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ModelTonalButton(
                    label: _connecting ? '连接中...' : (connected ? '重新连接' : '连接数据库'),
                    icon: LucideIcons.plug,
                    onPressed: _connecting ? null : _connect,
                  ),
                ),
                if (_sourceChoices != null) ...[
                  const SizedBox(height: 16),
                  AppSelectField<String>(
                    label: '选择数据源',
                    value: '',
                    options: [
                      const AppSelectOption(value: '', label: '请选择...'),
                      for (final s in _sourceChoices!)
                        AppSelectOption(
                          value: s.id,
                          label: s.name.isEmpty ? s.id : s.name,
                        ),
                    ],
                    onChanged: (id) {
                      if (id.isNotEmpty) _selectDataSource(id);
                    },
                  ),
                ],
                if (_connectError != null) ...[
                  const SizedBox(height: 12),
                  _StatusLine(success: false, text: _connectError!),
                ] else if (connected) ...[
                  const SizedBox(height: 12),
                  _StatusLine(
                    success: true,
                    text:
                        '已连接：${settings.dataSourceName.isEmpty ? settings.dataSourceId : settings.dataSourceName}'
                        '（标题属性：${settings.titleProperty}）',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          ModelSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModelSectionTitle('导出选项'),
                const SizedBox(height: 16),
                if (connected && _dateChoices.isNotEmpty) ...[
                  AppSelectField<String>(
                    label: '日期属性（可选）',
                    value: _dateChoices.contains(settings.dateProperty)
                        ? settings.dateProperty
                        : '',
                    options: [
                      const AppSelectOption(value: '', label: '不写入日期'),
                      for (final name in _dateChoices)
                        AppSelectOption(value: name, label: name),
                    ],
                    onChanged: controller.setDateProperty,
                  ),
                  const SizedBox(height: 16),
                ],
                _SwitchRow(
                  title: '导出思考过程',
                  description: '导出话题时包含助手的思考/推理内容',
                  value: settings.includeReasoning,
                  onChanged: controller.setIncludeReasoning,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const ModelSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ModelSectionTitle('配置步骤'),
                SizedBox(height: 12),
                _Note(
                  text:
                      '1. 访问 notion.so/profile/integrations 创建内部集成，复制 API 密钥\n'
                      '2. 在 Notion 中创建（或打开）一个数据库\n'
                      '3. 打开数据库页面右上角「···」→「连接」，添加刚创建的集成\n'
                      '4. 复制数据库链接粘贴到上方，点击「连接数据库」\n'
                      '5. 之后即可在话题菜单或消息导出面板中导出到 Notion',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _resetConnectState() {
    if (_connectError == null && _sourceChoices == null) return;
    setState(() {
      _connectError = null;
      _sourceChoices = null;
    });
  }

  Future<void> _connect() async {
    final settings = ref.read(notionSettingsControllerProvider);
    final id = NotionClient.parseId(settings.databaseId);
    if (settings.apiKey.isEmpty || id == null) {
      setState(() {
        _connectError = '请填写 API 密钥和有效的数据库 ID';
        _sourceChoices = null;
      });
      return;
    }

    setState(() {
      _connecting = true;
      _connectError = null;
      _sourceChoices = null;
    });

    final client = NotionClient(apiKey: settings.apiKey);
    try {
      NotionDataSource? source;
      try {
        final database = await client.retrieveDatabase(id);
        if (database.dataSources.isEmpty) {
          throw const NotionApiException('该数据库下没有数据源');
        }
        if (database.dataSources.length > 1) {
          if (!mounted) return;
          setState(() => _sourceChoices = database.dataSources);
          return;
        }
        source = await client.retrieveDataSource(database.dataSources.first.id);
      } on NotionApiException catch (e) {
        // The pasted ID may already be a data source ID — try it directly.
        if (e.statusCode != 404) rethrow;
        source = await client.retrieveDataSource(id);
      }
      _applyDataSource(source);
    } on NotionApiException catch (e) {
      if (mounted) setState(() => _connectError = e.message);
    } finally {
      client.close();
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _selectDataSource(String dataSourceId) async {
    final settings = ref.read(notionSettingsControllerProvider);
    setState(() {
      _connecting = true;
      _connectError = null;
    });
    final client = NotionClient(apiKey: settings.apiKey);
    try {
      _applyDataSource(await client.retrieveDataSource(dataSourceId));
    } on NotionApiException catch (e) {
      if (mounted) setState(() => _connectError = e.message);
    } finally {
      client.close();
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _applyDataSource(NotionDataSource source) {
    final title = source.titleProperty;
    if (title == null) {
      if (mounted) {
        setState(() => _connectError = '该数据源没有标题属性，无法用于导出');
      }
      return;
    }
    final dateNames = source.dateProperties.map((p) => p.name).toList();
    final current = ref.read(notionSettingsControllerProvider).dateProperty;
    ref
        .read(notionSettingsControllerProvider.notifier)
        .setConnection(
          dataSourceId: source.id,
          dataSourceName: source.name,
          titleProperty: title.name,
          dateProperty: dateNames.contains(current) ? current : '',
        );
    if (mounted) {
      setState(() {
        _sourceChoices = null;
        _dateChoices = dateNames;
      });
    }
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        CustomSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.success, required this.text});

  final bool success;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = success ? const Color(0xFF16A34A) : theme.colorScheme.error;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          success ? LucideIcons.circleCheck : LucideIcons.circleAlert,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12.5,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.6,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
