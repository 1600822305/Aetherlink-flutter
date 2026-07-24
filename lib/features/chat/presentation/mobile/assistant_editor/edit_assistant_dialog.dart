/// 编辑助手 dialog — the port of the web `EditAssistantDialog`
/// (`src/components/TopicManagement/AssistantTab/EditAssistantDialog.tsx`):
/// a full-screen sheet (mobile) / 80vh modal (desktop) with six tabs — 基础 /
/// 提示词 / 参数 / 正则 / 记忆 / 技能.
///
/// The original nests each tab's body in its own scroll inside an 80vh paper;
/// this port keeps the same tab set and instant-swap + horizontal-swipe tab
/// mechanic used elsewhere (MCP 服务器 / 技能管理 pages) and condenses each tab
/// into a single scroll.
///
/// Wired fields (persisted on 保存 via [Assistants.update]): 名称, 系统提示词
/// (+ 预设提示词 picker), 记忆开关, 技能绑定, 头像 (emoji / 图片), 聊天壁纸.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/core/platform/platform_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/parameter_settings.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/assistant_editor/avatar/assistant_avatar_sheet.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/assistant_editor/avatar/avatar_crop_page.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/assistant_editor/tabs/basic_tab.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/assistant_editor/tabs/memory_tab.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/assistant_editor/tabs/parameter_tab.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/assistant_editor/tabs/prompt_tab.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/assistant_editor/tabs/skills_tab.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/assistant_preset_sheet.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/regex_rules_tab.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/agent_prompt_selector.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_chat_background.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// Opens the 编辑助手 dialog for [assistant]. Full-screen on mobile, an 80vh
/// modal on wider layouts (web `BackButtonDialog` fullScreen={isMobile}).
Future<void> showEditAssistantDialog(
  BuildContext context,
  Assistant assistant,
) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x80000000),
    useSafeArea: false,
    builder: (_) => _EditAssistantDialog(assistant: assistant),
  );
}

/// Opens the 创建助手 dialog — same layout as edit but with blank fields and
/// an option to fill from a preset. On save, creates a new assistant.
Future<void> showCreateAssistantDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x80000000),
    useSafeArea: false,
    builder: (_) => const _EditAssistantDialog(assistant: null),
  );
}

class _EditAssistantDialog extends ConsumerStatefulWidget {
  const _EditAssistantDialog({required this.assistant});

  /// `null` means create mode (blank fields); non-null means edit mode.
  final Assistant? assistant;

  @override
  ConsumerState<_EditAssistantDialog> createState() =>
      _EditAssistantDialogState();
}

class _EditAssistantDialogState extends ConsumerState<_EditAssistantDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 6,
    vsync: this,
  )..addListener(_onTabChanged);
  int _index = 0;
  double _swipeDx = 0;
  double _swipeDy = 0;

  bool get _isCreateMode => widget.assistant == null;

  late final TextEditingController _nameController = TextEditingController(
    text: widget.assistant?.name ?? '',
  );
  late final TextEditingController _promptController = TextEditingController(
    text: widget.assistant?.systemPrompt ?? '',
  );
  late bool _memoryEnabled = widget.assistant?.memoryEnabled ?? false;
  late String? _emoji = widget.assistant?.emoji;
  late String? _avatar = widget.assistant?.avatar;
  late AssistantChatBackground _chatBackground =
      widget.assistant?.chatBackground ??
      const AssistantChatBackground(
        enabled: false,
        imageUrl: '',
        opacity: 0.7,
        showOverlay: true,
      );
  late List<String> _skillIds = List<String>.from(
    widget.assistant?.skillIds ?? const <String>[],
  );
  late List<AssistantRegex> _regexRules = List<AssistantRegex>.from(
    widget.assistant?.regexRules ?? const <AssistantRegex>[],
  );
  late ParameterSettings _paramSettings = _initParamSettings();
  late final AssistantParamDelegate _paramDelegate = AssistantParamDelegate(
    (ps) => setState(() => _paramSettings = ps),
  )..attach(_initParamSettings());

  ParameterSettings _initParamSettings() {
    final a = widget.assistant;
    if (a == null) {
      return const ParameterSettings(
        values: <String, dynamic>{},
        enabledFlags: <String, bool>{},
        customParameters: <Map<String, dynamic>>[],
      );
    }
    final values = <String, dynamic>{};
    final flags = <String, bool>{};
    if (a.temperature != null) {
      values['temperature'] = a.temperature;
      flags['temperature'] = true;
    }
    if (a.topP != null) {
      values['topP'] = a.topP;
      flags['topP'] = true;
    }
    if (a.maxTokens != null) {
      values['maxTokens'] = a.maxTokens;
      flags['maxTokens'] = true;
    }
    if (a.frequencyPenalty != null) {
      values['frequencyPenalty'] = a.frequencyPenalty;
      flags['frequencyPenalty'] = true;
    }
    if (a.presencePenalty != null) {
      values['presencePenalty'] = a.presencePenalty;
      flags['presencePenalty'] = true;
    }
    final customParams = (a.customParameters ?? const [])
        .map(
          (cp) => <String, dynamic>{
            'name': cp.name,
            'value': cp.value,
            'type': cp.type.name,
            'enabled': true,
          },
        )
        .toList();
    return ParameterSettings(
      values: values,
      enabledFlags: flags,
      customParameters: customParams,
    );
  }

  bool _saving = false;

  // ---- Avatar editing -------------------------------------------------------

  /// Shows a bottom sheet with avatar source options (image, emoji, URL, reset).
  Future<void> _editAvatar() async {
    final result = await showModalBottomSheet<AvatarResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AssistantAvatarSheet(
        parentContext: context,
        pickImage: () => _pickAvatarImage(ctx),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _emoji = result.emoji;
      _avatar = result.avatar;
    });
  }

  /// Picks a gallery image, crops it, and returns a base64 data URL stored in
  /// [Assistant.avatar] (same encoding as the wallpaper picker).
  Future<AvatarResult?> _pickAvatarImage(BuildContext sheetContext) async {
    final navigator = Navigator.of(sheetContext);
    final picked = await ref.read(imagePickerApiProvider).pickFromGallery();
    if (picked == null) return null;

    if (!sheetContext.mounted) return null;
    final croppedBytes = await AvatarCropPage.push(sheetContext, picked.bytes);
    if (croppedBytes == null) return null;

    final dataUrl = 'data:image/png;base64,${base64Encode(croppedBytes)}';
    final result = AvatarResult(avatar: dataUrl, emoji: null);
    if (navigator.mounted) navigator.pop(result);
    return result;
  }

  /// The display text shown on the avatar circle: current emoji, image
  /// indicator, or the first character of the name.
  String get _avatarDisplayText {
    if (_emoji != null && _emoji!.isNotEmpty) return _emoji!;
    final name = _nameController.text;
    if (name.isEmpty) return '助';
    return String.fromCharCodes(name.runes.take(1));
  }

  /// Whether the current avatar state has an image (base64 data URL).
  bool get _hasAvatarImage =>
      _avatar != null && _avatar!.isNotEmpty && _avatar!.startsWith('data:');

  /// Decodes the base64 avatar image for preview.
  MemoryImage? get _avatarImage {
    final url = _avatar;
    if (url == null) return null;
    final marker = url.indexOf('base64,');
    if (marker < 0) return null;
    try {
      return MemoryImage(base64Decode(url.substring(marker + 7)));
    } on FormatException {
      return null;
    }
  }

  // ---- Wallpaper picking ----------------------------------------------------

  /// Picks a gallery image and stores it as a base64 data URL on the assistant
  /// wallpaper draft (mirrors the global 聊天背景设置 picker), enabling the
  /// override on first pick.
  Future<void> _pickWallpaper() async {
    final picked = await ref.read(imagePickerApiProvider).pickFromGallery();
    if (picked == null) return;
    final mime = _wallpaperMime(picked.name);
    final dataUrl = 'data:$mime;base64,${base64Encode(picked.bytes)}';
    setState(() {
      _chatBackground = _chatBackground.copyWith(
        imageUrl: dataUrl,
        enabled: true,
      );
    });
  }

  static String _wallpaperMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void _onTabChanged() {
    if (_tabController.index != _index) {
      setState(() => _index = _tabController.index);
    }
  }

  void _onSwipeEnd() {
    final dx = _swipeDx;
    final dy = _swipeDy;
    _swipeDx = 0;
    _swipeDy = 0;
    // Only switch on a clearly horizontal swipe so vertical scrolling and the
    // 正则 tab's drag-to-reorder don't accidentally flip the tab.
    if (dx.abs() <= 60 || dx.abs() < dy.abs() * 1.5) return;
    final next = (_tabController.index + (dx < 0 ? 1 : -1)).clamp(0, 5);
    if (next != _tabController.index) _tabController.animateTo(next);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _nameController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickPreset() async {
    final selected = await showAgentPromptSelector(context);
    if (selected == null || !mounted) return;
    setState(() => _promptController.text = selected);
  }

  void _toggleSkill(String id) {
    setState(() {
      if (_skillIds.contains(id)) {
        _skillIds = _skillIds.where((s) => s != id).toList();
      } else {
        _skillIds = [..._skillIds, id];
      }
    });
  }

  /// Opens the preset bottom sheet and fills the form with the selected preset.
  Future<void> _applyPreset() async {
    final preset = await showAssistantPresetSheet(context);
    if (preset == null || !mounted) return;
    setState(() {
      _nameController.text = preset.name;
      _promptController.text = preset.systemPrompt ?? '';
      _emoji = preset.emoji;
      _avatar = preset.avatar;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      if (_isCreateMode) {
        if (name.isEmpty) {
          setState(() => _saving = false);
          AppToast.error(context, '请输入助手名称');
          return;
        }
        await ref
            .read(assistantsProvider.notifier)
            .createAssistant(
              name: name,
              systemPrompt: _promptController.text.trim(),
              emoji: _emoji,
              avatar: _avatar,
              memoryEnabled: _memoryEnabled,
              skillIds: _skillIds,
              paramSettings: _paramSettings,
              chatBackground: _chatBackground.imageUrl.isEmpty
                  ? null
                  : _chatBackground,
              regexRules: _regexRules,
            );
      } else {
        await ref
            .read(assistantsProvider.notifier)
            .applyEdits(
              widget.assistant!.id,
              name: name.isEmpty ? widget.assistant!.name : name,
              systemPrompt: _promptController.text.trim(),
              memoryEnabled: _memoryEnabled,
              skillIds: _skillIds,
              emoji: _emoji,
              avatar: _avatar,
              paramSettings: _paramSettings,
              chatBackground: _chatBackground.imageUrl.isEmpty
                  ? null
                  : _chatBackground,
              regexRules: _regexRules,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.error(context, '保存失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final isMobile = mq.size.width < 600;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(theme, isMobile),
        _tabBar(theme),
        Expanded(
          // Raw [Listener] rather than a GestureDetector: pointer events bypass
          // the gesture arena, so the swipe is detected reliably even over the
          // 正则 tab's ReorderableListView (whose reorder/scroll recognizers
          // otherwise win the arena and swallow horizontal drags) without
          // disturbing scrolling or drag-to-reorder.
          child: Listener(
            onPointerDown: (_) {
              _swipeDx = 0;
              _swipeDy = 0;
            },
            onPointerMove: (e) {
              _swipeDx += e.delta.dx;
              _swipeDy += e.delta.dy;
            },
            onPointerUp: (_) => _onSwipeEnd(),
            onPointerCancel: (_) {
              _swipeDx = 0;
              _swipeDy = 0;
            },
            child: IndexedStack(
              index: _index,
              sizing: StackFit.expand,
              children: [
                BasicTab(
                  assistant: widget.assistant,
                  nameController: _nameController,
                  avatarDisplayText: _avatarDisplayText,
                  hasAvatarImage: _hasAvatarImage,
                  avatarImage: _avatarImage,
                  onEditAvatar: _editAvatar,
                  chatBackground: _chatBackground,
                  onChatBackgroundChanged: (bg) =>
                      setState(() => _chatBackground = bg),
                  onPickWallpaper: _pickWallpaper,
                ),
                PromptTab(
                  controller: _promptController,
                  onPickPreset: _pickPreset,
                ),
                ParameterTab(
                  settings: _paramSettings,
                  delegate: _paramDelegate,
                ),
                RegexRulesTab(
                  rules: _regexRules,
                  onChange: (rules) => setState(() => _regexRules = rules),
                ),
                MemoryTab(
                  assistantId: widget.assistant?.id ?? '',
                  assistantName: widget.assistant?.name ?? '',
                  enabled: _memoryEnabled,
                  onChanged: (v) => setState(() => _memoryEnabled = v),
                ),
                SkillsTab(skillIds: _skillIds, onToggle: _toggleSkill),
              ],
            ),
          ),
        ),
        _actions(theme, isMobile),
      ],
    );

    if (isMobile) {
      return Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: theme.colorScheme.surface,
        shape: const RoundedRectangleBorder(),
        child: SafeArea(child: body),
      );
    }
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: mq.size.height * 0.8,
        ),
        child: body,
      ),
    );
  }

  // ---- Header ---------------------------------------------------------------

  Widget _header(ThemeData theme, bool isMobile) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            iconSize: isMobile ? 26 : 22,
            color: theme.colorScheme.onSurface,
            icon: const Icon(LucideIcons.chevronLeft),
            tooltip: '返回',
          ),
          const SizedBox(width: 4),
          Text(
            _isCreateMode ? '创建助手' : '编辑助手',
            style: TextStyle(
              fontSize: isMobile ? 18 : 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          if (_isCreateMode)
            OutlinedButton.icon(
              onPressed: _applyPreset,
              icon: const Icon(LucideIcons.sparkles, size: 16),
              label: const Text('使用预设'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  // ---- Tab bar --------------------------------------------------------------

  Widget _tabBar(ThemeData theme) {
    // Scrollable pill segmented control — same style as the 辅助模型 / 外观 /
    // 消息气泡 / 智能体提示词 settings pages: rounded bordered track + tinted
    // rounded indicator, suited for many tabs.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
          color: theme.colorScheme.surface,
        ),
        padding: const EdgeInsets.all(3),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerHeight: 0,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          tabs: const [
            _IconTab(icon: LucideIcons.settings, label: '基础'),
            _IconTab(icon: LucideIcons.fileText, label: '提示词'),
            _IconTab(icon: LucideIcons.settings2, label: '参数'),
            _IconTab(icon: LucideIcons.wand2, label: '正则'),
            _IconTab(icon: LucideIcons.brain, label: '记忆'),
            _IconTab(icon: LucideIcons.zap, label: '技能'),
          ],
        ),
      ),
    );
  }

  // ---- Actions --------------------------------------------------------------

  Widget _actions(ThemeData theme, bool isMobile) {
    return Container(
      padding: isMobile
          ? const EdgeInsets.fromLTRB(16, 12, 16, 16)
          : const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving
                  ? (_isCreateMode ? '创建中...' : '保存中...')
                  : (_isCreateMode ? '创建' : '保存'),
            ),
          ),
        ],
      ),
    );
  }
}
// ── Tab bar item ─────────────────────────────────────────────────────────────

class _IconTab extends StatelessWidget {
  const _IconTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 34,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 15), const SizedBox(width: 5), Text(label)],
      ),
    );
  }
}
