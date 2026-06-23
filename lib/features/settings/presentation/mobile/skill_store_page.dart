import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/settings/application/skills_controller.dart';
import 'package:aetherlink_flutter/features/settings/application/skillsmp_service.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';

/// The SkillsMP marketplace browser — search, preview, and import community
/// skills from https://skillsmp.com.
class SkillStorePage extends ConsumerStatefulWidget {
  const SkillStorePage({super.key});

  @override
  ConsumerState<SkillStorePage> createState() => _SkillStorePageState();
}

class _SkillStorePageState extends ConsumerState<SkillStorePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<SkillsMpItem> _results = [];
  bool _loading = false;
  String? _error;
  int _page = 1;
  int _total = 0;
  int _dailyRemaining = -1;
  bool _hasMore = true;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loading &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _search({bool reset = true}) async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    if (reset) {
      setState(() {
        _page = 1;
        _results = [];
        _hasMore = true;
      });
    }

    setState(() {
      _loading = true;
      _error = null;
      _lastQuery = query;
    });

    try {
      final service = ref.read(skillsMpServiceProvider.notifier);
      final result = await service.search(
        query: query,
        page: _page,
        limit: 20,
        sortBy: 'stars',
      );
      setState(() {
        _results = reset ? result.skills : [..._results, ...result.skills];
        _total = result.total;
        _dailyRemaining = result.dailyRemaining;
        _hasMore = _results.length < _total;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    _page++;
    await _search(reset: false);
  }

  Future<void> _importSkill(SkillsMpItem item) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final skill = Skill(
      id: generateId('skill'),
      name: item.name,
      description: item.description,
      source: SkillSource.community,
      emoji: '🌐',
      tags: [item.author],
      content:
          '<!-- 来源: ${item.skillUrl} -->\n'
          '<!-- GitHub: ${item.githubUrl} -->\n\n'
          '${item.description}',
      author: item.author,
      enabled: true,
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(skillsProvider.notifier).save(skill);
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('已导入「${item.name}」'),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  void _showApiKeyDialog() {
    final apiKey = ref.read(skillsMpServiceProvider);
    final controller = TextEditingController(text: apiKey ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('SkillsMP API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '填入 API Key 可将每日额度从 50 次提升到 500 次。',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'sk_live_...',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => launchUrl(
                Uri.parse('https://skillsmp.com/developers'),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                '前往 skillsmp.com 免费注册获取 →',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.of(ctx).pop();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final key = controller.text.trim();
              await ref
                  .read(skillsMpServiceProvider.notifier)
                  .setApiKey(key.isEmpty ? null : key);
              controller.dispose();
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        key.isEmpty ? 'API Key 已清除' : 'API Key 已保存',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final apiKey = ref.watch(skillsMpServiceProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
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
            color: cs.primary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
        title: const Text('技能商店'),
        actions: [
          IconButton(
            tooltip: 'API Key',
            icon: Icon(
              LucideIcons.key,
              size: 18,
              color: apiKey != null ? cs.primary : cs.onSurfaceVariant,
            ),
            onPressed: _showApiKeyDialog,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(theme, cs),
          if (_dailyRemaining >= 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(LucideIcons.info, size: 12, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '今日剩余 $_dailyRemaining 次请求'
                    '${apiKey != null ? '（已认证）' : '（匿名）'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildBody(theme, cs)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索技能（如 flutter, SEO, code review）...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                ),
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 38,
            child: FilledButton(
              onPressed: _loading ? null : _search,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('搜索'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme cs) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.alertCircle, size: 32, color: cs.error),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
              ),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _search, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.globe, size: 40, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                _lastQuery.isEmpty
                    ? '搜索 170 万+ 开源 Agent 技能\n来自 skillsmp.com'
                    : '没有找到匹配的技能',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bottomPad = MediaQuery.of(context).padding.bottom;
    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomPad),
      itemCount: _results.length + (_loading ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (i >= _results.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return _SkillsMpCard(
          item: _results[i],
          onImport: () => _importSkill(_results[i]),
          onOpenUrl: () => launchUrl(
            Uri.parse(_results[i].skillUrl),
            mode: LaunchMode.externalApplication,
          ),
        );
      },
    );
  }
}

class _SkillsMpCard extends StatelessWidget {
  const _SkillsMpCard({
    required this.item,
    required this.onImport,
    required this.onOpenUrl,
  });

  final SkillsMpItem item;
  final VoidCallback onImport;
  final VoidCallback onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.02);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onOpenUrl,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (item.stars > 0) ...[
                    const SizedBox(width: 6),
                    Icon(LucideIcons.star, size: 12, color: cs.primary),
                    const SizedBox(width: 2),
                    Text(
                      '${item.stars}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(LucideIcons.user, size: 12, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 28,
                    child: FilledButton.tonal(
                      onPressed: onImport,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('导入'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
