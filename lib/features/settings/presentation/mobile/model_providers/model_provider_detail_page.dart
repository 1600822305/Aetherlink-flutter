import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// The 供应商详情 hub third-level page, a 1:1 reproduction of
/// `src/pages/Settings/ModelProviders/index.tsx`.
///
/// Pure view, zero data: [providerId] is received from the route but not yet
/// queried (M4.3.2), so the page renders a static skeleton. The API-config
/// inputs and the 获取/添加 model actions render greyed (they need the data
/// layer); the model list shows its empty state. 「配置高级参数」 is a pure
/// navigation hop to the advanced-config page.
class ModelProviderDetailPage extends ConsumerWidget {
  const ModelProviderDetailPage({super.key, required this.providerId});

  final String providerId;

  static const String _title = '模型供应商';
  static const String _apiConfigTitle = 'API配置';
  static const String _apiKeyLabel = 'API密钥';
  static const String _apiKeyHint = '输入API密钥';
  static const String _baseUrlLabel = '基础URL (可选)';
  static const String _baseUrlHint = '输入基础URL，例如: https://tow.bt6.top';
  static const String _baseUrlHelper = '在URL末尾添加#可强制使用自定义格式，末尾添加/也可保持原格式';
  static const String _responsesTitle = 'Responses API';
  static const String _responsesHint =
      '注意：大多数 OpenAI 兼容 API（如硅基流动、DeepSeek）不支持 Responses API，请保持关闭。';
  static const String _disabledLabel = '已禁用';
  static const String _advancedLabel = '高级 API 配置';
  static const String _advancedButton = '配置高级参数';
  static const String _modelsTitle = '模型列表';
  static const String _autoFetchLabel = '获取';
  static const String _manualAddLabel = '添加';
  static const String _noModels = '尚未添加任何模型';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const ModelSettingsAppBar(title: _title),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ModelSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const ModelSectionTitle(_apiConfigTitle),
                const SizedBox(height: 24),
                const ModelFormField(
                  label: _apiKeyLabel,
                  hint: _apiKeyHint,
                  enabled: false,
                  obscureText: true,
                  suffixIcon: IconButton(
                    icon: Icon(LucideIcons.eyeOff, size: 20),
                    onPressed: null,
                  ),
                ),
                const SizedBox(height: 24),
                const ModelFormField(
                  label: _baseUrlLabel,
                  hint: _baseUrlHint,
                  helper: _baseUrlHelper,
                  enabled: false,
                ),
                const SizedBox(height: 24),
                _ResponsesApiRow(theme: theme),
                const SizedBox(height: 24),
                Text(
                  _advancedLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push(AppRouter.advancedApiPath(providerId)),
                  icon: const Icon(LucideIcons.settings, size: 16),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.secondary,
                    side: BorderSide(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  label: const Text(_advancedButton),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ModelSettingsCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 获取/添加 need the provider's models — disabled this
                // milestone (no data layer).
                const Row(
                  children: [
                    Expanded(child: ModelSectionTitle(_modelsTitle)),
                    ModelTonalButton(
                      label: _autoFetchLabel,
                      icon: LucideIcons.zap,
                      onPressed: null,
                    ),
                    SizedBox(width: 8),
                    ModelTonalButton(
                      label: _manualAddLabel,
                      icon: LucideIcons.plus,
                      onPressed: null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      _noModels,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Responses-API switch row (OpenAI-only in the original): a `subtitle2`
/// title + info hint, a trailing switch and a caption note. The switch renders
/// disabled this milestone (it persists provider config).
class _ResponsesApiRow extends StatelessWidget {
  const _ResponsesApiRow({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              ModelProviderDetailPage._responsesTitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.info,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const Spacer(),
            Text(
              ModelProviderDetailPage._disabledLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            const Switch(value: false, onChanged: null),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          ModelProviderDetailPage._responsesHint,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
