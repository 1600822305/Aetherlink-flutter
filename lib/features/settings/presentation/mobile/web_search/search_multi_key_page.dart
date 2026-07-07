import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/chat/application/web_search_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/multi_key_management_page.dart';
import 'package:aetherlink_flutter/shared/domain/api_key_config.dart';

/// 搜索提供商的多 Key 管理页 — the web-search counterpart of the model
/// providers' [MultiKeyManagementPage], reusing the shared [MultiKeyPoolScreen]
/// and persisting the pool on the provider's [SearchProviderConfig].
class SearchMultiKeyPage extends ConsumerWidget {
  const SearchMultiKeyPage({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(webSearchSettingsControllerProvider);
    final config =
        ws.providers.where((p) => p.id == providerId).firstOrNull;

    if (config == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('多 Key 管理')),
        body: const Center(child: Text('该搜索提供商不存在或已被删除')),
      );
    }

    final notifier = ref.read(webSearchSettingsControllerProvider.notifier);
    return MultiKeyPoolScreen(
      ownerName: config.name,
      keys: config.apiKeys,
      management: config.keyManagement ?? const KeyManagementConfig(),
      onSavePool: (keys) async =>
          notifier.updateProvider(config.copyWith(apiKeys: keys)),
      onSaveKey: (key) async =>
          notifier.mergeProviderApiKeys(config.id, [key]),
      onSaveManagement: (management) async =>
          notifier.updateProvider(config.copyWith(keyManagement: management)),
    );
  }
}
