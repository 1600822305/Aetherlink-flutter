import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/web_search_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/web_search/search_provider_catalog.dart';

/// 搜索提供商详情三级页面 — 配置一个搜索提供商的参数（API Key、Base URL、启用开关）。
/// 类似模型服务商的 `ModelProviderDetailPage`，但更简洁。
class SearchProviderDetailPage extends ConsumerStatefulWidget {
  const SearchProviderDetailPage({super.key, required this.providerId});

  final String providerId;

  @override
  ConsumerState<SearchProviderDetailPage> createState() =>
      _SearchProviderDetailPageState();
}

class _SearchProviderDetailPageState
    extends ConsumerState<SearchProviderDetailPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _apiHostController = TextEditingController();
  bool _obscureKey = true;
  bool _initialized = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiHostController.dispose();
    super.dispose();
  }

  void _seedFrom(SearchProviderConfig config) {
    if (_initialized) return;
    _initialized = true;
    _apiKeyController.text = config.apiKey;
    _apiHostController.text = config.apiHost;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ws = ref.watch(webSearchSettingsControllerProvider);
    final config = ws.providers
        .cast<SearchProviderConfig?>()
        .firstWhere((p) => p!.id == widget.providerId, orElse: () => null);

    if (config == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('提供商未找到')),
        body: const Center(child: Text('该搜索提供商不存在或已被删除')),
      );
    }

    _seedFrom(config);
    final preset = presetForId(config.id);
    final accent = preset?.accent ?? theme.colorScheme.primary;
    final isActive = ws.activeProviderId == config.id;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        centerTitle: false,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leadingWidth: 44,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(LucideIcons.arrowLeft, size: 24),
            color: theme.colorScheme.primary,
            onPressed: () => context.pop(),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: Text(config.name),
        actions: [
          // 保存按钮
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              icon: const Icon(LucideIcons.save, size: 16),
              label: const Text('保存', style: TextStyle(fontSize: 14)),
              onPressed: () => _save(config),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          // ── Header ────────────────────────────────────────────────────
          _OutlinedCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SearchProviderIcon(preset: preset, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (preset != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            preset.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12.5,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── 配置 card ─────────────────────────────────────────────────
          _OutlinedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardHeader(title: '配置', description: '搜索服务的连接参数'),
                Divider(height: 1, color: theme.dividerColor),

                // 启用开关
                _SwitchRow(
                  icon: LucideIcons.power,
                  accent: const Color(0xFF10B981),
                  label: '启用',
                  description: '是否在搜索时使用此提供商',
                  value: config.isEnabled,
                  onChanged: (v) {
                    ref
                        .read(webSearchSettingsControllerProvider.notifier)
                        .toggleProvider(config.id);
                  },
                ),
                Divider(height: 1, color: theme.dividerColor),

                // 设为默认 — 单选语义：已是默认时锁定为开，点击其它提供商可切换。
                _SwitchRow(
                  icon: LucideIcons.star,
                  accent: const Color(0xFFF59E0B),
                  label: '设为默认搜索引擎',
                  description: isActive
                      ? '当前默认，开启搜索时优先使用此提供商'
                      : '开启搜索时优先使用此提供商',
                  value: isActive,
                  onChanged: isActive
                      ? null
                      : (_) => ref
                          .read(webSearchSettingsControllerProvider.notifier)
                          .setActiveProvider(config.id),
                ),
                Divider(height: 1, color: theme.dividerColor),

                // API Host
                _TextFieldRow(
                  icon: LucideIcons.server,
                  accent: const Color(0xFF3B82F6),
                  label: 'API 地址',
                  description: '搜索服务的 API 端点',
                  controller: _apiHostController,
                  placeholder: 'https://api.example.com',
                ),
                Divider(height: 1, color: theme.dividerColor),

                // API Key
                _TextFieldRow(
                  icon: LucideIcons.key,
                  accent: const Color(0xFF8B5CF6),
                  label: 'API 密钥',
                  description: preset?.needsApiKey == true
                      ? '此提供商需要 API 密钥'
                      : '可选，部分提供商无需密钥',
                  controller: _apiKeyController,
                  placeholder: 'sk-...',
                  obscure: _obscureKey,
                  onToggleObscure: () =>
                      setState(() => _obscureKey = !_obscureKey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── 删除按钮 ──────────────────────────────────────────────────
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              icon: const Icon(LucideIcons.trash2, size: 16),
              label: const Text('删除此提供商'),
              onPressed: () => _confirmDelete(context, config.name),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _save(SearchProviderConfig current) {
    final updated = current.copyWith(
      apiKey: _apiKeyController.text.trim(),
      apiHost: _apiHostController.text.trim(),
    );
    ref
        .read(webSearchSettingsControllerProvider.notifier)
        .updateProvider(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已保存'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text(
            '确认删除',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.error,
            ),
          ),
          content: Text('确定要删除搜索提供商「$name」吗？此操作无法撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                backgroundColor: const Color(0x1AEF4444),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('确认删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    ref
        .read(webSearchSettingsControllerProvider.notifier)
        .removeProvider(widget.providerId);
    if (mounted) context.pop();
  }
}

// =============================================================================
// Shared widgets (scoped to this file)
// =============================================================================

class _OutlinedCard extends StatelessWidget {
  const _OutlinedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: theme.colorScheme.onSurface.withValues(alpha: 0.015),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A switch row with icon badge.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.accent,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String description;
  final bool value;

  /// When `null` the switch is shown disabled (e.g. the active provider's
  /// "设为默认" toggle, which can only be changed by activating another one).
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// A text field row with icon badge, label, and description.
class _TextFieldRow extends StatelessWidget {
  const _TextFieldRow({
    required this.icon,
    required this.accent,
    required this.label,
    required this.description,
    required this.controller,
    this.placeholder,
    this.obscure = false,
    this.onToggleObscure,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String description;
  final TextEditingController controller;
  final String? placeholder;
  final bool obscure;
  final VoidCallback? onToggleObscure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(
                fontSize: 13,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: theme.colorScheme.primary, width: 1.5),
              ),
              suffixIcon: onToggleObscure != null
                  ? IconButton(
                      icon: Icon(
                        obscure ? LucideIcons.eyeOff : LucideIcons.eye,
                        size: 16,
                      ),
                      onPressed: onToggleObscure,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
