// 世界书全局设置页（全屏子页，零时长路由），对应 SillyTavern 世界书面板里的
// 全局设置（`world_info_*`）。条目上留空（跟随全局）的扫描深度 / 区分大小写 /
// 全词匹配 / 组评分都取这里的值。改动即时保存。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/world_book_access.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_settings.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_common.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_entry_form_sections.dart';

Future<void> showWorldBookSettingsPage(BuildContext context) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const WorldBookSettingsPage(),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

class WorldBookSettingsPage extends ConsumerStatefulWidget {
  const WorldBookSettingsPage({super.key});

  @override
  ConsumerState<WorldBookSettingsPage> createState() =>
      _WorldBookSettingsPageState();
}

class _WorldBookSettingsPageState extends ConsumerState<WorldBookSettingsPage> {
  final _scanDepth = TextEditingController();
  final _budgetPercent = TextEditingController();
  final _budgetCap = TextEditingController();
  final _maxRecursion = TextEditingController();
  final _minActivations = TextEditingController();
  final _minDepthMax = TextEditingController();

  /// 正在由程序写入输入框（避免回写时再触发保存）。
  bool _syncing = false;

  List<TextEditingController> get _all => [
    _scanDepth,
    _budgetPercent,
    _budgetCap,
    _maxRecursion,
    _minActivations,
    _minDepthMax,
  ];

  WorldBookSettings get _s => ref.read(worldBookSettingsControllerProvider);

  @override
  void initState() {
    super.initState();
    _fill(_s);
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  /// 把 [s] 写进输入框（只改与当前文本不同的，保住光标）。
  void _fill(WorldBookSettings s) {
    _syncing = true;
    void put(TextEditingController c, int v) {
      if (int.tryParse(c.text.trim()) != v) c.text = '$v';
    }

    put(_scanDepth, s.scanDepth);
    put(_budgetPercent, s.budgetPercent);
    put(_budgetCap, s.budgetCap);
    put(_maxRecursion, s.maxRecursionSteps);
    put(_minActivations, s.minActivations);
    put(_minDepthMax, s.minActivationsDepthMax);
    _syncing = false;
  }

  int _read(TextEditingController c, int fallback, int min, int max) =>
      (int.tryParse(c.text.trim()) ?? fallback).clamp(min, max);

  void _save(WorldBookSettings next) {
    ref.read(worldBookSettingsControllerProvider.notifier).update(next);
  }

  /// 数字输入框变化时整体读取、校验并保存。最少激活数与最大扫描次数互斥（ST）：
  /// 刚改成非 0 的那个保留，另一个清零。
  void _onNumbers({bool minChanged = false, bool recursionChanged = false}) {
    if (_syncing) return;
    final s = _s;
    var minAct = _read(_minActivations, s.minActivations, 0, 100);
    var maxRec = _read(_maxRecursion, s.maxRecursionSteps, 0, 100);
    if (minAct > 0 && maxRec > 0) {
      if (minChanged) maxRec = 0;
      if (recursionChanged) minAct = 0;
    }
    final next = s.copyWith(
      scanDepth: _read(_scanDepth, s.scanDepth, 0, WorldBookEntry.kMaxScanDepth),
      budgetPercent: _read(_budgetPercent, s.budgetPercent, 1, 100),
      budgetCap: _read(_budgetCap, s.budgetCap, 0, 1000000),
      maxRecursionSteps: maxRec,
      minActivations: minAct,
      minActivationsDepthMax: _read(
        _minDepthMax,
        s.minActivationsDepthMax,
        0,
        WorldBookEntry.kMaxScanDepth,
      ),
    );
    _save(next);
    // 互斥清零的那个要同步回输入框。
    if (minChanged || recursionChanged) _fill(next);
    setState(() {});
  }

  Future<void> _reset() async {
    final ok = await confirmWorldBookAction(
      context,
      title: '恢复默认设置',
      message: '全局设置将恢复为默认值。',
      confirmLabel: '恢复',
    );
    if (!ok) return;
    ref.read(worldBookSettingsControllerProvider.notifier).reset();
    _fill(WorldBookSettings.defaults);
    setState(() {});
  }

  Widget _card(List<Widget> children) => WorldBookOutlinedCard(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  Widget _divider() => Divider(height: 1, color: Theme.of(context).dividerColor);

  Widget _switch(
    String title,
    bool value,
    WorldBookSettings Function(bool) apply, {
    String? subtitle,
  }) => WorldBookSwitchRow(
    title: title,
    subtitle: subtitle,
    value: value,
    onChanged: (v) {
      _save(apply(v));
      setState(() {});
    },
  );

  Widget _number(
    TextEditingController c,
    String title, {
    String? subtitle,
    required int min,
    required int max,
    VoidCallback? onChanged,
  }) => WorldBookNumberRow(
    controller: c,
    title: title,
    subtitle: subtitle,
    min: min,
    max: max,
    onChanged: onChanged ?? _onNumbers,
  );

  bool _moreOpen = false;

  List<Widget> _moreChildren(WorldBookSettings s) => [
    _switch(
      '包含名字',
      s.includeNames,
      (v) => s.copyWith(includeNames: v),
      subtitle: '每条消息前加「名字: 」，可以按说话人匹配',
    ),
    _divider(),
    _switch(
      '区分大小写',
      s.caseSensitive,
      (v) => s.copyWith(caseSensitive: v),
    ),
    _divider(),
    _switch(
      '全词匹配',
      s.matchWholeWords,
      (v) => s.copyWith(matchWholeWords: v),
      subtitle: '按空格分词，中文世界书建议关闭',
    ),
    _divider(),
    _switch(
      '包含组按命中数评分',
      s.useGroupScoring,
      (v) => s.copyWith(useGroupScoring: v),
      subtitle: '同组多条命中时只保留关键词命中最多的',
    ),
    if (s.recursive) ...[
      _divider(),
      _number(
        _maxRecursion,
        '最大扫描次数',
        subtitle: '含首次扫描；0 = 不限',
        min: 0,
        max: 100,
        onChanged: () => _onNumbers(recursionChanged: true),
      ),
    ],
    _divider(),
    _number(
      _minActivations,
      '最少激活数',
      subtitle: '激活的条目不够时继续往更早的消息扫描；0 = 关闭',
      min: 0,
      max: 100,
      onChanged: () => _onNumbers(minChanged: true),
    ),
    if (s.minActivations > 0) ...[
      _divider(),
      _number(
        _minDepthMax,
        '最大扫描深度',
        subtitle: '往前扫到多少条消息为止；0 = 到聊天开头',
        min: 0,
        max: WorldBookEntry.kMaxScanDepth,
      ),
    ],
    if (s.recursive)
      const WorldBookInlineNote('「最少激活数」与「最大扫描次数」只能设一个，设置其中一个时另一个会清零。'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = ref.watch(worldBookSettingsControllerProvider);
    // 存储读完前 build 时是默认值，读完后同步到输入框。
    ref.listen(worldBookSettingsControllerProvider, (prev, next) {
      if (prev != next) _fill(next);
    });

    return Scaffold(
      appBar: buildWorldBookAppBar(
        context,
        title: '世界书全局设置',
        onBack: () => Navigator.of(context).pop(),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.rotateCcw, size: 20),
            color: theme.colorScheme.primary,
            tooltip: '恢复默认',
            onPressed: s == WorldBookSettings.defaults ? null : _reset,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            _card([
              _number(
                _scanDepth,
                '扫描深度',
                subtitle: '在最近多少条消息里找关键词（条目可单独设置）',
                min: 0,
                max: WorldBookEntry.kMaxScanDepth,
              ),
              _divider(),
              _number(
                _budgetCap,
                '注入上限（token）',
                subtitle: '每次最多注入多少 token；0 = 不限',
                min: 0,
                max: 1000000,
              ),
              if (s.budgetCap == 0)
                const WorldBookInlineNote(
                  '不限时，命中的条目会全部注入。条目多的世界书建议设一个上限，例如 2000。',
                ),
              _divider(),
              _switch(
                '递归扫描',
                s.recursive,
                (v) => s.copyWith(recursive: v),
                subtitle: '被激活条目的内容会继续触发其他条目',
              ),
            ]),
            const SizedBox(height: 12),
            WorldBookOutlinedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () => setState(() => _moreOpen = !_moreOpen),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '高级',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '匹配方式、扫描次数、最少激活数、包含组评分',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            _moreOpen
                                ? LucideIcons.chevronUp
                                : LucideIcons.chevronDown,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_moreOpen) ...[
                    _divider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _moreChildren(s),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
