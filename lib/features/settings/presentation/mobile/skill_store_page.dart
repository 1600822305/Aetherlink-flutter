import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/translate_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/chat/domain/translate/translate_language.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/features/settings/application/skill_store_sources.dart';
import 'package:aetherlink_flutter/features/settings/application/skills_controller.dart';
import 'package:aetherlink_flutter/features/settings/application/skillsmp_service.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';

/// The unified skill marketplace — search and import from SkillsMP, ClawHub,
/// and AI Skill Store.
class SkillStorePage extends ConsumerStatefulWidget {
  const SkillStorePage({super.key});

  @override
  ConsumerState<SkillStorePage> createState() => _SkillStorePageState();
}

class _SkillStorePageState extends ConsumerState<SkillStorePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final TabController _tabController;

  SkillStoreSource _currentSource = SkillStoreSource.skillsmp;
  List<StoreSkillItem> _results = [];
  bool _loading = false;
  String? _error;
  int _page = 1;
  int _total = 0;
  bool _hasMore = true;
  String _lastQuery = '';
  String _rateInfo = '';

  /// Monotonically increasing counter to detect stale async responses.
  int _searchEpoch = 0;

  late final Dio _dio;

  @override
  void initState() {
    super.initState();
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    _tabController = TabController(
      length: SkillStoreSource.values.length,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _dio.close();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final source = SkillStoreSource.values[_tabController.index];
    if (source == _currentSource) return;
    _switchSource(source);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loading &&
        _hasMore) {
      _loadMore();
    }
  }

  void _switchSource(SkillStoreSource source) {
    if (source == _currentSource) return;
    _searchEpoch++; // Invalidate any in-flight search.
    setState(() {
      _currentSource = source;
      _results = [];
      _error = null;
      _page = 1;
      _total = 0;
      _hasMore = true;
      _rateInfo = '';
      _lastQuery = '';
      _loading = false;
    });
    // AI Skill Store supports empty-query browsing (returns popular skills).
    if (source == SkillStoreSource.aiskillstore) {
      _loadPopular();
    }
  }

  /// Load popular/trending skills for sources that support empty-query listing.
  Future<void> _loadPopular() async {
    final epoch = ++_searchEpoch;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await searchAiSkillStore(dio: _dio, query: '', limit: 20);
      if (epoch != _searchEpoch) return;
      setState(() {
        _results = result.skills;
        _total = result.total;
        _hasMore = result.hasMore;
        _rateInfo = result.rateInfo;
        _loading = false;
      });
    } catch (e) {
      if (epoch != _searchEpoch) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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

    final epoch = ++_searchEpoch;

    setState(() {
      _loading = true;
      _error = null;
      _lastQuery = query;
    });

    try {
      late final StoreSearchResult result;

      switch (_currentSource) {
        case SkillStoreSource.skillsmp:
          result = await _searchSkillsMP(query);
        case SkillStoreSource.clawhub:
          result = await searchClawHub(dio: _dio, query: query, limit: 20);
        case SkillStoreSource.aiskillstore:
          result = await searchAiSkillStore(dio: _dio, query: query, limit: 20);
      }

      // Discard stale responses (user switched source or started a new search).
      if (epoch != _searchEpoch) return;

      setState(() {
        _results = reset ? result.skills : [..._results, ...result.skills];
        _total = result.total;
        _hasMore = result.hasMore;
        _rateInfo = result.rateInfo;
        _loading = false;
      });
    } catch (e) {
      if (epoch != _searchEpoch) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<StoreSearchResult> _searchSkillsMP(String query) async {
    final service = ref.read(skillsMpServiceProvider.notifier);
    final result = await service.search(
      query: query,
      page: _page,
      limit: 20,
      sortBy: 'stars',
    );
    return StoreSearchResult(
      skills: result.skills
          .map(
            (item) => StoreSkillItem(
              id: item.id,
              name: item.name,
              author: item.author,
              description: item.description,
              url: item.skillUrl,
              source: SkillStoreSource.skillsmp,
              stars: item.stars,
            ),
          )
          .toList(),
      source: SkillStoreSource.skillsmp,
      total: result.total,
      hasMore: _results.length + result.skills.length < result.total,
      rateInfo: result.dailyRemaining >= 0
          ? '今日剩余 ${result.dailyRemaining} 次'
          : '',
    );
  }

  Future<void> _loadMore() async {
    _page++;
    await _search(reset: false);
  }

  Future<void> _importSkill(StoreSkillItem item) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final skill = Skill(
      id: generateId('skill'),
      name: item.name,
      description: item.description,
      source: SkillSource.community,
      emoji: '🌐',
      tags: [item.author, item.source.label],
      content:
          '<!-- 来源: ${item.url} -->\n'
          '<!-- 平台: ${item.source.label} -->\n\n'
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

  void _showSkillDetail(StoreSkillItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SkillDetailSheet(
        item: item,
        onImport: () {
          Navigator.of(context).pop();
          _importSkill(item);
        },
      ),
    );
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
              '填入 API Key 可将每日额度从 50 次提升到 500 次。\n'
              '（仅对 SkillsMP 数据源有效）',
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
          _buildSourceTabs(theme, cs),
          _buildSearchBar(theme, cs),
          if (_rateInfo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(LucideIcons.info, size: 12, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    _rateInfo,
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

  Widget _buildSourceTabs(ThemeData theme, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        labelColor: cs.onSurface,
        unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.08),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        labelPadding: EdgeInsets.zero,
        tabs: SkillStoreSource.values
            .map((s) => _SourceTab(icon: s.icon, label: s.label))
            .toList(),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
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
                hintText: '搜索技能...',
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
                _lastQuery.isEmpty ? _currentSource.subtitle : '没有找到匹配的技能',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              if (_lastQuery.isEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _sourceHint,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
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
        return _StoreSkillCard(
          item: _results[i],
          onImport: () => _importSkill(_results[i]),
          onTap: () => _showSkillDetail(_results[i]),
        );
      },
    );
  }

  String get _sourceHint {
    switch (_currentSource) {
      case SkillStoreSource.skillsmp:
        return '170 万+ 开源 Agent 技能 · skillsmp.com';
      case SkillStoreSource.clawhub:
        return '社区精选 Agent 技能 · clawhub.ai\n3000 次/分钟 · 无需注册';
      case SkillStoreSource.aiskillstore:
        return 'USK 标准技能 · aiskillstore.io\n经 AI 安全审核';
    }
  }
}

class _StoreSkillCard extends StatelessWidget {
  const _StoreSkillCard({
    required this.item,
    required this.onImport,
    required this.onTap,
  });

  final StoreSkillItem item;
  final VoidCallback onImport;
  final VoidCallback onTap;

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
        onTap: onTap,
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
                  if (item.downloads > 0) ...[
                    const SizedBox(width: 6),
                    Icon(LucideIcons.download, size: 12, color: cs.primary),
                    const SizedBox(width: 2),
                    Text(
                      '${item.downloads}',
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

/// Detail BottomSheet for a skill — full description, metadata, translate, and
/// import/open actions.
class _SkillDetailSheet extends ConsumerStatefulWidget {
  const _SkillDetailSheet({required this.item, required this.onImport});

  final StoreSkillItem item;
  final VoidCallback onImport;

  @override
  ConsumerState<_SkillDetailSheet> createState() => _SkillDetailSheetState();
}

class _SkillDetailSheetState extends ConsumerState<_SkillDetailSheet> {
  String? _translatedDescription;
  bool _isTranslating = false;

  Future<void> _translateDescription() async {
    final text = widget.item.description.trim();
    if (text.isEmpty || _isTranslating) return;

    final current = await ref.read(translateModelProvider.future);
    if (!mounted) return;
    if (current == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('请先在「模型」中配置翻译模型')));
      return;
    }

    setState(() {
      _isTranslating = true;
      _translatedDescription = '';
    });

    final effective = effectiveModelFor(current);
    final request = LlmChatRequest(
      model: effective,
      messages: [
        LlmMessage(
          role: MessageRole.user,
          content: buildTranslatePrompt(kChineseSimplified, text),
        ),
      ],
      extraHeaders: effective.providerExtraHeaders,
      extraBody: effective.providerExtraBody,
    );

    final gateway = ref.read(llmGatewayFactoryProvider).forModel(effective);
    final buffer = StringBuffer();
    try {
      await for (final chunk in gateway.streamChat(request)) {
        if (!mounted) return;
        switch (chunk) {
          case LlmTextDelta(:final text):
            buffer.write(text);
            setState(() => _translatedDescription = buffer.toString());
          case LlmReasoningDelta():
          case LlmToolCallChunk():
          case LlmDone():
            break;
        }
      }
      if (mounted) {
        setState(() => _translatedDescription = buffer.toString().trim());
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _translatedDescription = '翻译失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final item = widget.item;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPad),
        child: ListView(
          controller: scrollController,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Title + source badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.source.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Author + stats row
            Row(
              children: [
                Icon(LucideIcons.user, size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    item.author,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.stars > 0) ...[
                  const SizedBox(width: 12),
                  Icon(LucideIcons.star, size: 13, color: cs.primary),
                  const SizedBox(width: 3),
                  Text(
                    '${item.stars}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.primary,
                    ),
                  ),
                ],
                if (item.downloads > 0) ...[
                  const SizedBox(width: 12),
                  Icon(LucideIcons.download, size: 13, color: cs.primary),
                  const SizedBox(width: 3),
                  Text(
                    '${item.downloads}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.primary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            // Description header + translate button
            Row(
              children: [
                Text(
                  '描述',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 28,
                  child: TextButton.icon(
                    onPressed: _isTranslating ? null : _translateDescription,
                    icon: _isTranslating
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: cs.primary,
                            ),
                          )
                        : Icon(LucideIcons.languages, size: 14),
                    label: Text(
                      _isTranslating ? '翻译中...' : '翻译为中文',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Original description
            SelectableText(
              item.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
                height: 1.5,
              ),
            ),
            // Translated description
            if (_translatedDescription != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.languages,
                          size: 13,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '中文翻译',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (_translatedDescription!.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: _translatedDescription!),
                              );
                              ScaffoldMessenger.of(context)
                                ..clearSnackBars()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text('已复制翻译'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                            },
                            child: Icon(
                              LucideIcons.copy,
                              size: 13,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      _translatedDescription!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(item.url),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(LucideIcons.externalLink, size: 16),
                    label: const Text('查看原文'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onImport,
                    icon: const Icon(LucideIcons.download, size: 16),
                    label: const Text('导入技能'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTab extends StatelessWidget {
  const _SourceTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 14), const SizedBox(width: 4), Text(label)],
      ),
    );
  }
}
