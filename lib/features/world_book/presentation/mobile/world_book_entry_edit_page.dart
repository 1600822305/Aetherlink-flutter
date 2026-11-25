// 条目编辑页（全屏子页，零时长路由），字段与 SillyTavern 世界书条目一致。
// 按「写什么 → 什么时候注入 → 注入到哪里 → 高级」组织：
//   · 内容：标题（ST comment）+ 内容；
//   · 触发：常驻 / 关键词；主关键词、次级关键词与四种逻辑、区分大小写 / 全词匹配
//     （可跟随全局）、扫描深度（可跟随全局）；
//   · 注入：ST 的 8 个位置（暂未实现的标「暂不生效」）、深度与角色、Outlet 名、
//     顺序（order）；
//   · 高级（可折叠，有非默认值时默认展开）：概率、包含组、递归、计时器、预算、
//     额外匹配源、生成类型、自动化 ID。引擎尚未实现的分组标「暂不生效」。
// 有未保存修改时返回会二次确认；编辑已有条目时页底可删除。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/world_book_access.dart';

import 'package:aetherlink_flutter/features/world_book/application/world_books_controller.dart';
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

  late final WorldBookEntry _base = widget.entry ?? const WorldBookEntry(id: '');

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

  late bool _advancedOpen = _hasAdvanced(_base);
  bool _saving = false;

  bool get _isNew => widget.entry == null;

  static TextEditingController _number(int value) =>
      TextEditingController(text: value.toString());

  /// 高级区里有非默认值时默认展开，避免用户看不到已有设置。
  static bool _hasAdvanced(WorldBookEntry e) =>
      !e.useProbability ||
      e.probability != 100 ||
      e.groups.isNotEmpty ||
      e.useGroupScoring != null ||
      e.excludeRecursion ||
      e.preventRecursion ||
      e.delayUntilRecursion > 0 ||
      (e.sticky ?? 0) > 0 ||
      (e.cooldown ?? 0) > 0 ||
      (e.delay ?? 0) > 0 ||
      e.ignoreBudget ||
      e.vectorized ||
      e.matchPersonaDescription ||
      e.matchCharacterDescription ||
      e.matchCharacterPersonality ||
      e.matchCharacterDepthPrompt ||
      e.matchScenario ||
      e.matchCreatorNotes ||
      e.triggers.isNotEmpty ||
      e.characterFilter != null ||
      e.automationId.isNotEmpty;

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

  @override
  void initState() {
    super.initState();
    _content.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
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

  bool get _dirty => _collect() != _base;

  bool get _canSave =>
      !_saving &&
      (_name.text.trim().isNotEmpty || _content.text.trim().isNotEmpty);

  Future<void> _save() async {
    if (!_canSave) return;
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
      message: '将删除「${entry.name.isEmpty ? '未命名条目' : entry.name}」。',
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

  Widget _divider() => Divider(height: 1, color: Theme.of(context).dividerColor);

  Widget _subhead(String text, {bool pending = false}) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 2),
    child: Row(
      children: [
        Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (pending) const WorldBookBadge('暂不生效'),
      ],
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
          decoration: InputDecoration(isDense: true, labelText: label, hintText: hint),
        ),
      );

  // ───────────────────────── sections ─────────────────────────

  Widget _contentCard(ThemeData theme) => _card([
    TextField(
      controller: _name,
      autofocus: _isNew,
      textInputAction: TextInputAction.next,
      onChanged: (_) => _refresh(),
      style: theme.textTheme.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: const InputDecoration(
        labelText: '标题',
        hintText: '如：外貌、王都、魔法规则（不参与匹配）',
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _content,
      minLines: 5,
      maxLines: 14,
      style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
      decoration: const InputDecoration(
        labelText: '内容',
        hintText:
            '激活时注入给模型的文本，可用 {{char}} {{user}} 等宏；'
            '首行写 @@activate / @@dont_activate 可强制激活 / 不激活',
        alignLabelWithHint: true,
      ),
    ),
    Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '${_content.text.characters.length} 字',
        textAlign: TextAlign.right,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 11.5,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  ]);

  Widget _triggerCard() => _card([
    WorldBookSegmented<bool>(
      options: const [(false, '出现关键词时'), (true, '总是（常驻）')],
      value: _constant,
      onChanged: (v) => setState(() => _constant = v),
    ),
    if (_constant)
      const WorldBookInlineNote('每次对话都会注入这段内容，会持续占用上下文。')
    else ...[
      const WorldBookFieldLabel('主关键词（任一命中即可）'),
      WorldBookKeywordsField(
        keywords: _keywords,
        onChanged: (v) => setState(() => _keywords = v),
      ),
      if (_keywords.isEmpty)
        const WorldBookInlineNote('还没有主关键词，这个条目不会被触发。', warning: true),
      const WorldBookFieldLabel('次级关键词（可选）'),
      WorldBookKeywordsField(
        keywords: _secondary,
        hint: '主关键词命中后，再按下面的逻辑检查',
        onChanged: (v) => setState(() => _secondary = v),
      ),
      if (_secondary.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (logic, label) in const [
              (WorldBookSecondaryLogic.andAny, '且含任一'),
              (WorldBookSecondaryLogic.andAll, '且含全部'),
              (WorldBookSecondaryLogic.notAny, '且都不含'),
              (WorldBookSecondaryLogic.notAll, '且不全含'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _logic == logic,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _logic = logic),
              ),
          ],
        ),
      ],
      const SizedBox(height: 6),
      _divider(),
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
        subtitle: '全局默认扫描最近 ${_settings.scanDepth} 条消息',
      ),
      if (!_followScanDepth)
        _numberRow(
          _scanDepth,
          '扫描深度',
          subtitle: '在最近多少条消息里找关键词',
          min: 0,
          max: WorldBookEntry.kMaxScanDepth,
        ),
    ],
  ]);

  Widget _injectionCard() => _card([
    WorldBookPositionSelector(
      value: _position,
      onChanged: (v) => setState(() => _position = v),
    ),
    WorldBookInlineNote(
      worldBookPositionHint(_position),
      warning: !_position.isImplemented,
    ),
    if (_position == WorldBookInjectionPosition.atDepth) ...[
      const SizedBox(height: 4),
      _numberRow(
        _depth,
        '深度',
        subtitle: '0 = 最后一条消息之后',
        min: 0,
        max: WorldBookEntry.kMaxNumber,
      ),
      const WorldBookFieldLabel('以谁的身份插入'),
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
          'Claude、Gemini 不接受对话中间的系统消息，发给它们时会改为用户消息并标注为系统内容。',
        ),
    ],
    if (_position == WorldBookInjectionPosition.outlet)
      _textField(_outletName, 'Outlet 名字', hint: '在提示词里用 {{outlet::名字}} 取出'),
    const SizedBox(height: 4),
    _divider(),
    _numberRow(
      _order,
      '顺序',
      subtitle: '数值大的更靠近提示词末尾，对输出影响更大',
      min: -WorldBookEntry.kMaxNumber,
      max: WorldBookEntry.kMaxNumber,
    ),
  ]);

  Widget _advancedCard(ThemeData theme) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final pendingCount = worldBookPendingCount();
    return WorldBookOutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _advancedOpen = !_advancedOpen),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '概率、包含组、递归、计时器等',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          pendingCount == 0
                              ? '默认'
                              : '已设置 $pendingCount 项暂不生效的功能',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _advancedOpen
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 16,
                    color: muted,
                  ),
                ],
              ),
            ),
          ),
          if (_advancedOpen) ...[
            _divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _advancedChildren(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 高级区里设置了、但引擎暂未实现的功能数（用于折叠时的摘要）。
  int worldBookPendingCount() {
    final e = _collect();
    return [
      e.vectorized,
      e.matchPersonaDescription ||
          e.matchCharacterDepthPrompt ||
          e.matchCreatorNotes,
      e.automationId.isNotEmpty,
    ].where((v) => v).length;
  }

  List<Widget> _advancedChildren() => [
    _subhead('概率'),
    _switch('启用概率', _useProbability, (v) => _useProbability = v),
    if (_useProbability)
      _numberRow(
        _probability,
        '触发概率（%）',
        subtitle: '关键词命中后按这个概率决定是否注入',
        min: 0,
        max: 100,
      ),
    _subhead('包含组'),
    _textField(_group, '组名', hint: '同组条目同时命中时只注入一条；多个组用逗号分隔'),
    _switch(
      '组内优先',
      _groupOverride,
      (v) => _groupOverride = v,
      subtitle: '同组时直接选顺序最大的，不随机',
    ),
    _numberRow(
      _groupWeight,
      '组内权重',
      subtitle: '随机选择时的权重',
      min: 1,
      max: WorldBookEntry.kMaxNumber,
    ),
    _triState('按命中数评分', _useGroupScoring, (v) => _useGroupScoring = v),
    _subhead('递归'),
    if (!_settings.recursive)
      const WorldBookInlineNote('全局设置里的「递归扫描」未开启，这一组设置暂时不起作用。'),
    _switch(
      '不可被递归激活',
      _excludeRecursion,
      (v) => _excludeRecursion = v,
      subtitle: '其他条目的内容不能触发它',
    ),
    _switch(
      '阻止后续递归',
      _preventRecursion,
      (v) => _preventRecursion = v,
      subtitle: '它的内容不再用来触发其他条目',
    ),
    _numberRow(
      _delayUntilRecursion,
      '延迟到递归层级',
      subtitle: '0 = 关闭；N = 只在第 N 层递归扫描时才能激活',
      min: 0,
      max: WorldBookEntry.kMaxNumber,
    ),
    _subhead('计时器'),
    _numberRow(
      _sticky,
      '持续',
      subtitle: '激活后保持生效的消息数，0 = 关闭',
      min: 0,
      max: WorldBookEntry.kMaxNumber,
    ),
    _numberRow(
      _cooldown,
      '冷却',
      subtitle: '持续结束后多少条消息内不能再激活',
      min: 0,
      max: WorldBookEntry.kMaxNumber,
    ),
    _numberRow(
      _delay,
      '延迟',
      subtitle: '聊天满多少条消息后才可激活',
      min: 0,
      max: WorldBookEntry.kMaxNumber,
    ),
    const WorldBookInlineNote('按消息条数计算（用户和助手的消息都算），一来一回是 2 条。'),
    _subhead('预算'),
    _switch(
      '不计入预算',
      _ignoreBudget,
      (v) => _ignoreBudget = v,
      subtitle: '超出 token 预算时也照常注入',
    ),
    _subhead('额外匹配源'),
    const WorldBookInlineNote('除了聊天记录，再在这些内容里找关键词。'),
    _switch(
      '角色描述',
      _matchCharDesc,
      (v) => _matchCharDesc = v,
      subtitle: '本应用对应：助手的系统提示词',
    ),
    _switch(
      '角色性格',
      _matchCharPersonality,
      (v) => _matchCharPersonality = v,
      subtitle: '本应用对应：助手简介',
    ),
    _switch(
      '场景',
      _matchScenario,
      (v) => _matchScenario = v,
      subtitle: '本应用对应：话题提示词',
    ),
    _switch(
      '用户人设',
      _matchPersona,
      (v) => _matchPersona = v,
      subtitle: '本应用暂无对应内容，开启后不会匹配到',
    ),
    _switch(
      '角色备注',
      _matchDepthPrompt,
      (v) => _matchDepthPrompt = v,
      subtitle: '本应用暂无对应内容，开启后不会匹配到',
    ),
    _switch(
      '作者备注',
      _matchCreatorNotes,
      (v) => _matchCreatorNotes = v,
      subtitle: '本应用暂无对应内容，开启后不会匹配到',
    ),
    _subhead('生成类型'),
    const WorldBookInlineNote(
      '不选 = 所有类型都可以激活。本应用的发送、重新发送和多模型都算「正常发送」；'
      '「代写」「后台生成」在本应用中不会出现。',
    ),
    const SizedBox(height: 6),
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
    _subhead('角色筛选'),
    const WorldBookInlineNote('「角色」指当前助手：名字可填助手名或 id，标签对应助手标签。'),
    _switch(
      '排除模式',
      _filterExclude,
      (v) => _filterExclude = v,
      subtitle: _filterExclude ? '下面列出的助手不激活这个条目' : '只有下面列出的助手才激活这个条目',
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
    _subhead('其他', pending: true),
    _switch(
      '向量匹配',
      _vectorized,
      (v) => _vectorized = v,
      subtitle: '按语义相似度激活',
    ),
    _textField(_automationId, '自动化 ID', hint: 'SillyTavern 快速回复联动'),
  ];

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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              _contentCard(theme),
              const WorldBookFormLabel('什么时候注入'),
              _triggerCard(),
              const WorldBookFormLabel('注入到哪里'),
              _injectionCard(),
              const WorldBookFormLabel('高级'),
              _advancedCard(theme),
              if (!_isNew) ...[
                const SizedBox(height: 20),
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
