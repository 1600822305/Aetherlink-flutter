// 条目编辑页（全屏子页，零时长路由），字段与 SillyTavern 世界书条目一致。
//
// 主页面只放三块，按「写什么 → 什么时候触发 → 放在哪里」：
//   · 内容：标题 + 正文（无边框输入，像写笔记），底部字数 / token；
//   · 触发：关键词触发 / 始终注入；关键词；次级条件（默认收起）；「匹配方式」
//     一行，点开底部面板调大小写、全词、扫描深度；
//   · 注入：位置（点开底部面板选择）、深度与身份 / Outlet 名、顺序。
// 其余设置在「更多」卡片里，每项一行、右侧显示当前值，点开底部面板编辑：
// 触发概率、包含组、计时器、递归、SillyTavern 兼容；「不计入注入上限」直接是开关。
// 有未保存修改时返回会二次确认；编辑已有条目时页底可删除。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/world_book_access.dart';

import 'package:aetherlink_flutter/features/world_book/application/world_books_controller.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_import.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_timed_selection.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_settings.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_common.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_entry_form_sections.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_entry_row.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 打开条目编辑页；[entry] 为 null 表示新建。
Future<void> showWorldBookEntryEditPage(
  BuildContext context, {
  required String bookId,
  WorldBookEntry? entry,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) =>
          WorldBookEntryEditPage(bookId: bookId, entry: entry),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

/// ST `triggers` 的生成类型及中文名。
const List<(String, String)> _kTriggerTypes = [
  ('normal', '正常发送'),
  ('continue', '继续'),
  ('impersonate', '代写'),
  ('swipe', '多版本'),
  ('regenerate', '重新生成'),
  ('quiet', '后台生成'),
];

class WorldBookEntryEditPage extends ConsumerStatefulWidget {
  const WorldBookEntryEditPage({super.key, required this.bookId, this.entry});

  final String bookId;
  final WorldBookEntry? entry;

  @override
  ConsumerState<WorldBookEntryEditPage> createState() =>
      _WorldBookEntryEditPageState();
}

class _WorldBookEntryEditPageState
    extends ConsumerState<WorldBookEntryEditPage> {
  late final WorldBookSettings _settings = ref.read(
    worldBookSettingsControllerProvider,
  );

  /// 编辑起点。标题为空的旧条目（修复前导入的）用列表上显示的同一个名字填进
  /// 标题框，保存后真正写入，列表和编辑页始终一致。
  late final WorldBookEntry _base = switch (widget.entry) {
    final e? when e.hasInferredTitle => e.copyWith(name: e.displayTitle),
    final e? => e,
    null => const WorldBookEntry(id: ''),
  };

  late final _name = TextEditingController(text: _base.name);
  late final _content = TextEditingController(text: _base.content);
  late final _outletName = TextEditingController(text: _base.outletName);
  late final _group = TextEditingController(text: _base.group);
  late final _automationId = TextEditingController(text: _base.automationId);
  late final _order = _number(_base.order);
  late final _depth = _number(_base.depth);
  late final _scanDepth = _number(_base.scanDepth ?? _settings.scanDepth);
  late final _probability = _number(_base.probability);
  late final _groupWeight = _number(_base.groupWeight);
  late final _delayUntilRecursion = _number(_base.delayUntilRecursion);
  late final _sticky = _number(_base.sticky ?? 0);
  late final _cooldown = _number(_base.cooldown ?? 0);
  late final _delay = _number(_base.delay ?? 0);

  late List<String> _keywords = List.of(_base.keywords);
  late List<String> _secondary = List.of(_base.secondaryKeywords);
  late bool _constant = _base.constant;
  late WorldBookSecondaryLogic _logic = _base.secondaryLogic;
  late bool? _caseSensitive = _base.caseSensitive;
  late bool? _matchWholeWords = _base.matchWholeWords;
  late bool _followScanDepth = _base.scanDepth == null;
  late WorldBookInjectionPosition _position = _base.position;
  late WorldBookInjectionRole _role = _base.role;
  late bool _useProbability = _base.useProbability;
  late bool _groupOverride = _base.groupOverride;
  late bool? _useGroupScoring = _base.useGroupScoring;
  late bool _excludeRecursion = _base.excludeRecursion;
  late bool _preventRecursion = _base.preventRecursion;
  late bool _ignoreBudget = _base.ignoreBudget;
  late bool _vectorized = _base.vectorized;
  late bool _matchPersona = _base.matchPersonaDescription;
  late bool _matchCharDesc = _base.matchCharacterDescription;
  late bool _matchCharPersonality = _base.matchCharacterPersonality;
  late bool _matchDepthPrompt = _base.matchCharacterDepthPrompt;
  late bool _matchScenario = _base.matchScenario;
  late bool _matchCreatorNotes = _base.matchCreatorNotes;
  late Set<String> _triggers = {..._base.triggers};
  late List<String> _filterNames = _filterList('names');
  late List<String> _filterTags = _filterList('tags');
  late bool _filterExclude = _base.characterFilter?['isExclude'] == true;

  List<String> _filterList(String key) {
    final v = _base.characterFilter?[key];
    return v is List<dynamic>
        ? [
            for (final x in v)
              if ('$x'.trim().isNotEmpty) '$x'.trim(),
          ]
        : <String>[];
  }

  /// ST `characterFilter`：没设置任何名字 / 标签且原来就没有时保持 null；
  /// 原对象里本应用不认识的键原样保留。
  Map<String, dynamic>? _characterFilter() {
    final base = _base.characterFilter;
    if (base == null &&
        _filterNames.isEmpty &&
        _filterTags.isEmpty &&
        !_filterExclude) {
      return null;
    }
    return <String, dynamic>{
      ...?base,
      'isExclude': _filterExclude,
      'names': _filterNames,
      'tags': _filterTags,
    };
  }

  /// 次级条件区：已有次级关键词时直接显示，否则点「添加次级条件」才出现。
  bool _showSecondary = false;
  bool _saving = false;

  bool get _isNew => widget.entry == null;

  static TextEditingController _number(int value) =>
      TextEditingController(text: value.toString());

  List<TextEditingController> get _controllers => [
    _name,
    _content,
    _outletName,
    _group,
    _automationId,
    _order,
    _depth,
    _scanDepth,
    _probability,
    _groupWeight,
    _delayUntilRecursion,
    _sticky,
    _cooldown,
    _delay,
  ];

  /// 打开页面时表单「原样收集」出来的条目，作为判断有没有修改的基准。
  ///
  /// 不能直接拿 [_base] 比：收集时会做规整（标题去空格、计时器 0 存成 null、
  /// 数字限定范围、生成类型按固定顺序排列……），导入的条目经常和规整后的值
  /// 不完全一样（比如酒馆文件里 sticky / cooldown / delay 写的是 0），什么都
  /// 没改也会被判成「已修改」。
  late final WorldBookEntry _initial;

  @override
  void initState() {
    super.initState();
    _initial = _collect();
    _content.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  /// 底部面板里的表单跟着页面状态刷新：页面每次 setState 都让它 +1。
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _tick.value++;
  }

  @override
  void dispose() {
    _tick.dispose();
    _content.removeListener(_refresh);
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  int _read(TextEditingController c, int fallback, int min, int max) =>
      (int.tryParse(c.text.trim()) ?? fallback).clamp(min, max);

  /// 计时器：0 存成 null（ST 的「未设置」）。
  int? _timer(TextEditingController c) {
    final v = _read(c, 0, 0, WorldBookEntry.kMaxNumber);
    return v == 0 ? null : v;
  }

  WorldBookEntry _collect() => _base.copyWith(
    name: _name.text.trim(),
    content: _content.text,
    keywords: _keywords,
    secondaryKeywords: _secondary,
    secondaryLogic: _logic,
    constant: _constant,
    caseSensitive: _caseSensitive,
    matchWholeWords: _matchWholeWords,
    scanDepth: _followScanDepth
        ? null
        : _read(_scanDepth, _settings.scanDepth, 0, WorldBookEntry.kMaxScanDepth),
    position: _position,
    depth: _read(_depth, 4, 0, WorldBookEntry.kMaxNumber),
    role: _role,
    outletName: _outletName.text.trim(),
    order: _read(_order, 100, -WorldBookEntry.kMaxNumber, WorldBookEntry.kMaxNumber),
    useProbability: _useProbability,
    probability: _read(_probability, 100, 0, 100),
    group: _group.text.trim(),
    groupOverride: _groupOverride,
    groupWeight: _read(_groupWeight, 100, 1, WorldBookEntry.kMaxNumber),
    useGroupScoring: _useGroupScoring,
    excludeRecursion: _excludeRecursion,
    preventRecursion: _preventRecursion,
    delayUntilRecursion: _read(
      _delayUntilRecursion,
      0,
      0,
      WorldBookEntry.kMaxNumber,
    ),
    sticky: _timer(_sticky),
    cooldown: _timer(_cooldown),
    delay: _timer(_delay),
    ignoreBudget: _ignoreBudget,
    vectorized: _vectorized,
    matchPersonaDescription: _matchPersona,
    matchCharacterDescription: _matchCharDesc,
    matchCharacterPersonality: _matchCharPersonality,
    matchCharacterDepthPrompt: _matchDepthPrompt,
    matchScenario: _matchScenario,
    matchCreatorNotes: _matchCreatorNotes,
    triggers: [
      for (final (type, _) in _kTriggerTypes)
        if (_triggers.contains(type)) type,
      // 保留本应用不认识的生成类型。
      for (final t in _base.triggers)
        if (!_kTriggerTypes.any((k) => k.$1 == t) && _triggers.contains(t)) t,
    ],
    automationId: _automationId.text.trim(),
    characterFilter: _characterFilter(),
  );

  bool get _dirty => _collect() != _initial;

  bool get _canSave =>
      !_saving &&
      (_name.text.trim().isNotEmpty || _content.text.trim().isNotEmpty);

  Future<void> _save() async {
    // 先收起键盘，让关键词输入框里还没回车的内容提交进去（焦点变化在下一个
    // microtask 才通知）。
    FocusScope.of(context).unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted || !_canSave) return;
    // 没改动的已有条目不用写库，直接关闭。
    if (!_isNew && !_dirty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(worldBooksControllerProvider.notifier)
          .saveEntry(widget.bookId, _collect());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) AppToast.error(context, '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final entry = widget.entry;
    if (entry == null) return;
    final ok = await confirmWorldBookAction(
      context,
      title: '删除条目',
      message: '将删除「${entry.displayTitle.isEmpty ? '未命名条目' : entry.displayTitle}」。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) return;
    await ref
        .read(worldBooksControllerProvider.notifier)
        .deleteEntry(widget.bookId, entry.id);
    if (!mounted) return;
    AppToast.success(context, '已删除条目');
    Navigator.of(context).pop();
  }

  Future<void> _back() async {
    FocusScope.of(context).unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final ok =
        !_dirty ||
        await confirmWorldBookAction(
          context,
          title: '放弃修改？',
          message: '这个条目有未保存的修改，返回后会丢失。',
          confirmLabel: '放弃',
          destructive: true,
        );
    if (ok && mounted) Navigator.of(context).pop();
  }

  // ───────────────────────── building blocks ─────────────────────────

  Widget _card(List<Widget> children) => WorldBookOutlinedCard(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  Widget _divider({double indent = 0}) => Divider(
    height: 1,
    indent: indent,
    color: Theme.of(context).dividerColor,
  );

  Widget _subhead(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 2),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _switch(
    String title,
    bool value,
    ValueChanged<bool> onChanged, {
    String? subtitle,
  }) => WorldBookSwitchRow(
    title: title,
    subtitle: subtitle,
    value: value,
    onChanged: (v) => setState(() => onChanged(v)),
  );

  Widget _triState(String title, bool? value, ValueChanged<bool?> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 196,
              child: WorldBookSegmented<bool?>(
                options: const [(null, '跟随全局'), (true, '开'), (false, '关')],
                value: value,
                onChanged: (v) => setState(() => onChanged(v)),
              ),
            ),
          ],
        ),
      );

  Widget _numberRow(
    TextEditingController c,
    String title, {
    String? subtitle,
    required int min,
    required int max,
  }) => WorldBookNumberRow(
    controller: c,
    title: title,
    subtitle: subtitle,
    min: min,
    max: max,
    onChanged: _refresh,
  );

  Widget _textField(TextEditingController c, String label, {String? hint}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextField(
          controller: c,
          onChanged: (_) => _refresh(),
          decoration: InputDecoration(
            isDense: true,
            labelText: label,
            hintText: hint,
          ),
        ),
      );

  /// 一行设置入口：图标 + 名称，右侧是当前值和「›」。
  Widget _navRow({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
    bool warn = false,
    EdgeInsets padding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 13,
    ),
  }) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            Icon(icon, size: 18, color: muted),
            const SizedBox(width: 12),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12.5,
                  color: warn ? const Color(0xFFD97706) : muted,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronRight, size: 16, color: muted),
          ],
        ),
      ),
    );
  }

  /// 底部面板编辑一组设置；改动直接作用在页面状态上（随页面一起保存）。
  Future<void> _openSheet(
    String title,
    List<Widget> Function() children, {
    String? note,
  }) {
    FocusScope.of(context).unfocus();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: ListenableBuilder(
                listenable: _tick,
                builder: (_, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (note != null) WorldBookInlineNote(note),
                    const SizedBox(height: 4),
                    ...children(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── summaries ─────────────────────────

  String _matchSummary() {
    String? tri(String name, bool? v) =>
        v == null ? null : '$name${v ? '开' : '关'}';
    final parts = [
      tri('大小写', _caseSensitive),
      tri('全词', _matchWholeWords),
      if (!_followScanDepth) '最近 ${_scanDepth.text.trim()} 条',
    ].whereType<String>().toList();
    return parts.isEmpty ? '跟随全局' : parts.join(' · ');
  }

  String _probabilitySummary() =>
      _useProbability ? '${_read(_probability, 100, 0, 100)}%' : '不判定';

  String _groupSummary() {
    final g = _group.text.trim();
    return g.isEmpty ? '无' : g;
  }

  String _timerSummary() {
    final sticky = _timer(_sticky);
    final cooldown = _timer(_cooldown);
    final delay = _timer(_delay);
    final parts = [
      if (sticky != null) '持续 $sticky',
      if (cooldown != null) '冷却 $cooldown',
      if (delay != null) '延迟 $delay',
    ];
    return parts.isEmpty ? '无' : parts.join(' · ');
  }

  String _recursionSummary() {
    final level = _read(_delayUntilRecursion, 0, 0, WorldBookEntry.kMaxNumber);
    final parts = [
      if (_excludeRecursion) '不被触发',
      if (_preventRecursion) '不触发其他',
      if (level > 0) '第 $level 层',
    ];
    if (parts.isEmpty) return _settings.recursive ? '默认' : '全局未开启';
    return parts.join(' · ');
  }

  /// 兼容区的摘要；用到本应用不起作用的设置时为警示色。
  (String, bool) _compatSummary() {
    final e = _collect();
    final pending = worldBookPendingFeatures(e);
    if (pending.isNotEmpty) return ('${pending.length} 项不起作用', true);
    final parts = [
      if (e.matchCharacterDescription ||
          e.matchCharacterPersonality ||
          e.matchScenario)
        '额外匹配源',
      if (e.triggers.isNotEmpty) '生成类型',
      if (_filterNames.isNotEmpty || _filterTags.isNotEmpty) '助手筛选',
    ];
    return (parts.isEmpty ? '未使用' : parts.join('、'), false);
  }

  // ───────────────────────── sheet contents ─────────────────────────

  List<Widget> _matchChildren() => [
    _triState('区分大小写', _caseSensitive, (v) => _caseSensitive = v),
    _divider(),
    _triState('全词匹配', _matchWholeWords, (v) => _matchWholeWords = v),
    const WorldBookInlineNote('全词匹配按空格分词，中文条目建议关闭。'),
    const SizedBox(height: 4),
    _divider(),
    _switch(
      '扫描深度跟随全局',
      _followScanDepth,
      (v) => _followScanDepth = v,
      subtitle: '全局是最近 ${_settings.scanDepth} 条消息',
    ),
    if (!_followScanDepth)
      _numberRow(
        _scanDepth,
        '扫描深度',
        subtitle: '在最近多少条消息里找关键词',
        min: 0,
        max: WorldBookEntry.kMaxScanDepth,
      ),
  ];

  List<Widget> _probabilityChildren() => [
    _switch(
      '按概率触发',
      _useProbability,
      (v) => _useProbability = v,
      subtitle: '关键词命中后，再按概率决定这次注不注入',
    ),
    if (_useProbability)
      _numberRow(_probability, '概率（%）', min: 0, max: 100),
  ];

  List<Widget> _groupChildren() => [
    _textField(_group, '组名', hint: '多个组用逗号分隔'),
    _switch(
      '组内优先',
      _groupOverride,
      (v) => _groupOverride = v,
      subtitle: '同组时直接选它（多个优先时选顺序最大的）',
    ),
    _numberRow(
      _groupWeight,
      '权重',
      subtitle: '随机挑选时，权重越大越容易被选中',
      min: 1,
      max: WorldBookEntry.kMaxNumber,
    ),
    _triState('按命中数评分', _useGroupScoring, (v) => _useGroupScoring = v),
  ];

  List<Widget> _timerChildren() => [
    _numberRow(
      _sticky,
      '持续',
      subtitle: '激活后接下来多少条消息内保持注入',
      min: 0,
      max: WorldBookEntry.kMaxNumber,
    ),
    _numberRow(
      _cooldown,
      '冷却',
      subtitle: '之后多少条消息内不能再触发',
      min: 0,
      max: WorldBookEntry.kMaxNumber,
    ),
    _numberRow(
      _delay,
      '延迟',
      subtitle: '聊天满多少条消息后才能触发',
      min: 0,
      max: WorldBookEntry.kMaxNumber,
    ),
  ];

  List<Widget> _recursionChildren() => [
    if (!_settings.recursive)
      const WorldBookInlineNote('全局设置里的「递归扫描」没有开启，这些设置暂时不起作用。'),
    _switch(
      '不被其他条目触发',
      _excludeRecursion,
      (v) => _excludeRecursion = v,
      subtitle: '只认聊天记录里的关键词',
    ),
    _switch(
      '不触发其他条目',
      _preventRecursion,
      (v) => _preventRecursion = v,
      subtitle: '它的内容不再用来找其他条目的关键词',
    ),
    _numberRow(
      _delayUntilRecursion,
      '延迟到递归层级',
      subtitle: '0 = 关闭；N = 第 N 层递归时才能触发',
      min: 0,
      max: WorldBookEntry.kMaxNumber,
    ),
  ];

  List<Widget> _compatChildren() => [
    _subhead('额外匹配源'),
    const WorldBookInlineNote('除了聊天记录，再在这些内容里找关键词。'),
    _switch(
      '角色描述',
      _matchCharDesc,
      (v) => _matchCharDesc = v,
      subtitle: '对应助手的系统提示词',
    ),
    _switch(
      '角色性格',
      _matchCharPersonality,
      (v) => _matchCharPersonality = v,
      subtitle: '对应助手简介',
    ),
    _switch(
      '场景',
      _matchScenario,
      (v) => _matchScenario = v,
      subtitle: '对应话题提示词',
    ),
    if (_matchPersona || _matchDepthPrompt || _matchCreatorNotes) ...[
      _switch(
        '用户人设',
        _matchPersona,
        (v) => _matchPersona = v,
        subtitle: '本应用没有对应内容，不起作用',
      ),
      _switch(
        '角色备注',
        _matchDepthPrompt,
        (v) => _matchDepthPrompt = v,
        subtitle: '本应用没有对应内容，不起作用',
      ),
      _switch(
        '作者备注',
        _matchCreatorNotes,
        (v) => _matchCreatorNotes = v,
        subtitle: '本应用没有对应内容，不起作用',
      ),
    ],
    _subhead('生成类型'),
    const WorldBookInlineNote('不选 = 都可以触发。发送、重新发送和多模型都算「正常发送」。'),
    const SizedBox(height: 8),
    Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (type, label) in _kTriggerTypes)
          FilterChip(
            label: Text(label),
            visualDensity: VisualDensity.compact,
            selected: _triggers.contains(type),
            onSelected: (v) => setState(() {
              _triggers = {..._triggers};
              v ? _triggers.add(type) : _triggers.remove(type);
            }),
          ),
      ],
    ),
    _subhead('助手筛选'),
    const WorldBookInlineNote('只对指定的助手生效（或排除它们）。名字可填助手名或 id。'),
    _switch(
      '排除模式',
      _filterExclude,
      (v) => _filterExclude = v,
      subtitle: _filterExclude ? '下面的助手不触发' : '只有下面的助手触发',
    ),
    const WorldBookFieldLabel('助手名字'),
    WorldBookKeywordsField(
      keywords: _filterNames,
      hint: '留空 = 不按名字筛选',
      onChanged: (v) => setState(() => _filterNames = v),
    ),
    const WorldBookFieldLabel('助手标签'),
    WorldBookKeywordsField(
      keywords: _filterTags,
      hint: '留空 = 不按标签筛选',
      onChanged: (v) => setState(() => _filterTags = v),
    ),
    if (_vectorized || _automationId.text.trim().isNotEmpty) ...[
      _subhead('仅保存'),
      const WorldBookInlineNote('导入时带过来的设置，本应用不使用，导出时原样写回。'),
      _switch('向量匹配', _vectorized, (v) => _vectorized = v),
      _textField(_automationId, '自动化 ID'),
    ],
  ];

  Future<void> _pickPosition() async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<WorldBookInjectionPosition>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        Widget tile(WorldBookInjectionPosition p) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Text(worldBookPositionLabel(p)),
          subtitle: Text(
            worldBookPositionHint(p),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: p == _position
              ? Icon(LucideIcons.check, size: 18, color: theme.colorScheme.primary)
              : null,
          onTap: () => Navigator.of(ctx).pop(p),
        );
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final p in WorldBookInjectionPosition.values)
                  if (p.isImplemented) tile(p),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Text(
                    '本应用没有对应功能（只保存，不注入）',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final p in WorldBookInjectionPosition.values)
                  if (!p.isImplemented) tile(p),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) setState(() => _position = picked);
  }

  // ───────────────────────── sections ─────────────────────────

  static const InputDecoration _bare = InputDecoration(
    isDense: true,
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
  );

  Widget _contentCard(ThemeData theme) => _card([
    TextField(
      controller: _name,
      autofocus: _isNew,
      textInputAction: TextInputAction.next,
      onChanged: (_) => _refresh(),
      style: theme.textTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: _bare.copyWith(
        hintText: '标题',
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
      ),
    ),
    _divider(),
    TextField(
      controller: _content,
      minLines: 6,
      maxLines: 16,
      style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
      decoration: _bare.copyWith(
        hintText: '触发时发给模型的内容，可以用 {{char}}、{{user}} 等宏',
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    ),
    Text(
      '${_content.text.characters.length} 字 · '
      '约 ${worldBookRoughTokens(_content.text)} tokens',
      textAlign: TextAlign.right,
      style: theme.textTheme.bodySmall?.copyWith(
        fontSize: 11.5,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  ]);

  Widget _triggerCard() => _card([
    WorldBookSegmented<bool>(
      options: const [(false, '关键词触发'), (true, '始终注入')],
      value: _constant,
      onChanged: (v) => setState(() => _constant = v),
    ),
    if (_constant)
      const WorldBookInlineNote('每次对话都会注入，会一直占用上下文。')
    else ...[
      const WorldBookFieldLabel('关键词（命中任意一个即触发）'),
      WorldBookKeywordsField(
        keywords: _keywords,
        onChanged: (v) => setState(() => _keywords = v),
      ),
      if (_keywords.isEmpty)
        const WorldBookInlineNote('还没有关键词，这个条目不会被触发。', warning: true),
      if (_secondary.isEmpty && !_showSecondary)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            onPressed: () => setState(() => _showSecondary = true),
            icon: const Icon(LucideIcons.plus, size: 14),
            label: const Text('添加次级条件'),
          ),
        )
      else ...[
        const WorldBookFieldLabel('次级条件（关键词命中后再检查）'),
        WorldBookSegmented<WorldBookSecondaryLogic>(
          options: const [
            (WorldBookSecondaryLogic.andAny, '含任一'),
            (WorldBookSecondaryLogic.andAll, '含全部'),
            (WorldBookSecondaryLogic.notAny, '都不含'),
            (WorldBookSecondaryLogic.notAll, '不全含'),
          ],
          value: _logic,
          onChanged: (v) => setState(() => _logic = v),
        ),
        const SizedBox(height: 8),
        WorldBookKeywordsField(
          keywords: _secondary,
          hint: '次级关键词',
          onChanged: (v) => setState(() => _secondary = v),
        ),
      ],
      const SizedBox(height: 8),
      _divider(),
      _navRow(
        icon: LucideIcons.sliders,
        title: '匹配方式',
        value: _matchSummary(),
        padding: const EdgeInsets.only(top: 12, bottom: 2),
        onTap: () => _openSheet('匹配方式', _matchChildren),
      ),
    ],
  ]);

  Widget _injectionCard() => _card([
    _navRow(
      icon: LucideIcons.mapPin,
      title: '位置',
      value: worldBookPositionLabel(_position),
      warn: !_position.isImplemented,
      padding: const EdgeInsets.symmetric(vertical: 6),
      onTap: _pickPosition,
    ),
    WorldBookInlineNote(
      worldBookPositionHint(_position),
      warning: !_position.isImplemented,
    ),
    if (_position == WorldBookInjectionPosition.atDepth) ...[
      const SizedBox(height: 8),
      _divider(),
      _numberRow(
        _depth,
        '深度',
        subtitle: '0 = 放在最后一条消息之后',
        min: 0,
        max: WorldBookEntry.kMaxNumber,
      ),
      const WorldBookFieldLabel('作为谁的消息'),
      WorldBookSegmented<WorldBookInjectionRole>(
        options: [
          for (final r in WorldBookInjectionRole.values)
            (r, worldBookRoleLabel(r)),
        ],
        value: _role,
        onChanged: (v) => setState(() => _role = v),
      ),
      if (_role == WorldBookInjectionRole.system)
        const WorldBookInlineNote(
          'Claude、Gemini 不支持对话中间的系统消息，发给它们时会改成带标注的用户消息。',
        ),
    ],
    if (_position == WorldBookInjectionPosition.outlet)
      _textField(_outletName, 'Outlet 名字', hint: '在系统提示词里写 {{outlet::名字}}'),
    const SizedBox(height: 8),
    _divider(),
    _numberRow(
      _order,
      '顺序',
      subtitle: '同一位置里数值大的排在后面，对回复影响更大',
      min: -WorldBookEntry.kMaxNumber,
      max: WorldBookEntry.kMaxNumber,
    ),
  ]);

  Widget _moreCard() {
    final (compat, compatWarn) = _compatSummary();
    return WorldBookOutlinedCard(
      child: Column(
        children: [
          _navRow(
            icon: LucideIcons.gauge,
            title: '触发概率',
            value: _probabilitySummary(),
            onTap: () => _openSheet('触发概率', _probabilityChildren),
          ),
          _divider(indent: 44),
          _navRow(
            icon: LucideIcons.layers,
            title: '包含组',
            value: _groupSummary(),
            onTap: () => _openSheet(
              '包含组',
              _groupChildren,
              note: '同组的条目同时命中时，只注入其中一条。',
            ),
          ),
          _divider(indent: 44),
          _navRow(
            icon: LucideIcons.timer,
            title: '计时器',
            value: _timerSummary(),
            onTap: () => _openSheet(
              '计时器',
              _timerChildren,
              note: '按消息条数计算，用户和助手的消息都算，一来一回是 2 条。0 = 关闭。',
            ),
          ),
          _divider(indent: 44),
          _navRow(
            icon: LucideIcons.refreshCw,
            title: '递归',
            value: _recursionSummary(),
            onTap: () => _openSheet(
              '递归',
              _recursionChildren,
              note: '已触发条目的内容，也可以用来触发其他条目。',
            ),
          ),
          _divider(indent: 44),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _switch(
              '不计入注入上限',
              _ignoreBudget,
              (v) => _ignoreBudget = v,
              subtitle: '超出全局注入上限时也照常注入',
            ),
          ),
          _divider(indent: 44),
          _navRow(
            icon: LucideIcons.plug,
            title: 'SillyTavern 兼容',
            value: compat,
            warn: compatWarn,
            onTap: () => _openSheet(
              'SillyTavern 兼容',
              _compatChildren,
              note: '从酒馆导入的世界书才会用到，一般不用管。',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: buildWorldBookAppBar(
          context,
          title: _isNew ? '新建条目' : '编辑条目',
          onBack: _back,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: _canSave ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              _contentCard(theme),
              const WorldBookFormLabel('触发'),
              _triggerCard(),
              const WorldBookFormLabel('注入'),
              _injectionCard(),
              const WorldBookFormLabel('更多'),
              _moreCard(),
              if (!_isNew) ...[
                const SizedBox(height: 24),
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      visualDensity: VisualDensity.compact,
                      textStyle: theme.textTheme.bodySmall,
                    ),
                    onPressed: _delete,
                    icon: const Icon(LucideIcons.trash2, size: 14),
                    label: const Text('删除条目'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
