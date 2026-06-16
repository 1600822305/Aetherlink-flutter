import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// The "编辑模型" third-level page, a 1:1 reproduction of
/// `src/pages/Settings/ModelProviders/EditModelPage.tsx` (whose form body is the
/// `EditModelForm.solid` component).
///
/// Pure view, zero data: [providerId] is received but not queried (M4.3.2), so
/// the form renders an empty skeleton. Every field needs the model store, so
/// they all render disabled (greyed); the top-right 保存 is likewise disabled.
class EditModelPage extends ConsumerWidget {
  const EditModelPage({super.key, required this.providerId});

  final String providerId;

  static const String _title = '编辑模型';
  static const String _saveLabel = '保存';
  static const String _avatarTitle = '模型头像';
  static const String _avatarDesc = '为此模型设置自定义头像';
  static const String _nameLabel = '模型名称';
  static const String _providerLabel = '提供商';
  static const String _providerHelper = '选择API提供商，可以与模型ID自由组合';
  static const String _modelIdLabel = '模型ID';
  static const String _modelIdHelper = '模型的唯一标识符，例如：gpt-4、claude-3-opus';
  static const String _typeLabel = '模型类型';
  static const String _autoDetectLabel = '自动检测';
  static const String _typeHelperAuto = '根据模型ID和提供商自动检测模型类型';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: ModelSettingsAppBar(
        title: _title,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ElevatedButton(
              // 保存 persists the model — disabled this milestone (no data).
              onPressed: null,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(_saveLabel),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AvatarCard(theme: theme),
          const SizedBox(height: 24),
          const ModelFormField(label: _nameLabel, enabled: false),
          const SizedBox(height: 24),
          const _DisabledSelectField(
            label: _providerLabel,
            helper: _providerHelper,
          ),
          const SizedBox(height: 24),
          const ModelFormField(
            label: _modelIdLabel,
            helper: _modelIdHelper,
            enabled: false,
          ),
          const SizedBox(height: 24),
          _ModelTypeSection(theme: theme),
        ],
      ),
    );
  }
}

/// The avatar card: a circular fallback initial, the 模型头像 title/description
/// and a primary photo button (disabled — avatar upload needs the data layer).
class _AvatarCard extends StatelessWidget {
  const _AvatarCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ModelSettingsCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Text(
              'M',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  EditModelPage._avatarTitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  EditModelPage._avatarDesc,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const IconButton(
            icon: Icon(LucideIcons.image, size: 20),
            onPressed: null,
          ),
        ],
      ),
    );
  }
}

/// A disabled labelled dropdown placeholder (the original `<select>`), drawn
/// greyed with a trailing chevron and an optional helper line.
class _DisabledSelectField extends StatelessWidget {
  const _DisabledSelectField({required this.label, this.helper});

  final String label;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isDense: true,
          isExpanded: true,
          items: const [],
          onChanged: null,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// The 模型类型 section: a header (label + info hint + 自动检测 switch) and the
/// grouped capability chips. The original defaults `autoDetect` on, which
/// disables the chips — matching this milestone's pure-view state.
class _ModelTypeSection extends StatelessWidget {
  const _ModelTypeSection({required this.theme});

  final ThemeData theme;

  static const List<({String label, List<String> types})> _groups = [
    (label: '基础功能', types: ['聊天']),
    (label: '输入能力', types: ['视觉', '语音']),
    (label: '输出能力', types: ['图像生成', '视频生成', '转录', '翻译']),
    (label: '高级功能', types: ['推理', '函数调用', '网络搜索', '工具使用', '代码生成']),
    (label: '数据处理', types: ['嵌入向量', '重排序']),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              EditModelPage._typeLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.info, size: 16, color: scheme.onSurfaceVariant),
            const Spacer(),
            Text(
              EditModelPage._autoDetectLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            // autoDetect defaults on; persisting it needs the data layer, so
            // the switch is disabled this milestone.
            const Switch(value: true, onChanged: null),
            const IconButton(
              icon: Icon(LucideIcons.settings, size: 16),
              onPressed: null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final group in _groups) ...[
          Text(
            group.label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in group.types)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Text(
                    type,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: theme.disabledColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        Text(
          EditModelPage._typeHelperAuto,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
