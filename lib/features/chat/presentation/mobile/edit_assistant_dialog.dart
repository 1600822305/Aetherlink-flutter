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
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/skills_access.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/assistant_preset_sheet.dart';
import 'package:aetherlink_flutter/features/memory/presentation/mobile/assistant_memory_index_page.dart';
import 'package:aetherlink_flutter/core/platform/platform_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/parameter_settings.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/regex_rules_tab.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/agent_prompt_selector.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/parameter_editor.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_chat_background.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';
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
  late final _AssistantParamDelegate _paramDelegate = _AssistantParamDelegate(
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
    final result = await showModalBottomSheet<_AvatarResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AssistantAvatarSheet(
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
  Future<_AvatarResult?> _pickAvatarImage(BuildContext sheetContext) async {
    final navigator = Navigator.of(sheetContext);
    final picked = await ref.read(imagePickerApiProvider).pickFromGallery();
    if (picked == null) return null;

    if (!sheetContext.mounted) return null;
    final croppedBytes = await _AvatarCropPage.push(
      sheetContext,
      picked.bytes,
    );
    if (croppedBytes == null) return null;

    final dataUrl = 'data:image/png;base64,${base64Encode(croppedBytes)}';
    final result = _AvatarResult(avatar: dataUrl, emoji: null);
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
      _avatar != null &&
      _avatar!.isNotEmpty &&
      _avatar!.startsWith('data:');

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
                _BasicTab(
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
                _PromptTab(
                  controller: _promptController,
                  onPickPreset: _pickPreset,
                ),
                _ParameterTab(
                  settings: _paramSettings,
                  delegate: _paramDelegate,
                ),
                RegexRulesTab(
                  rules: _regexRules,
                  onChange: (rules) => setState(() => _regexRules = rules),
                ),
                _MemoryTab(
                  assistantId: widget.assistant?.id ?? '',
                  assistantName: widget.assistant?.name ?? '',
                  enabled: _memoryEnabled,
                  onChanged: (v) => setState(() => _memoryEnabled = v),
                ),
                _SkillsTab(skillIds: _skillIds, onToggle: _toggleSkill),
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

// ── 基础 ─────────────────────────────────────────────────────────────────────

class _BasicTab extends StatelessWidget {
  const _BasicTab({
    required this.assistant,
    required this.nameController,
    required this.avatarDisplayText,
    required this.hasAvatarImage,
    required this.onEditAvatar,
    required this.chatBackground,
    required this.onChatBackgroundChanged,
    required this.onPickWallpaper,
    this.avatarImage,
  });

  final Assistant? assistant;
  final TextEditingController nameController;
  final String avatarDisplayText;
  final bool hasAvatarImage;
  final MemoryImage? avatarImage;
  final VoidCallback onEditAvatar;
  final AssistantChatBackground chatBackground;
  final ValueChanged<AssistantChatBackground> onChatBackgroundChanged;
  final Future<void> Function() onPickWallpaper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final image = avatarImage;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onEditAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.12,
                    ),
                    backgroundImage:
                        hasAvatarImage && image != null ? image : null,
                    child: hasAvatarImage && image != null
                        ? null
                        : Text(
                            avatarDisplayText,
                            style: TextStyle(
                              fontSize: 22,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        LucideIcons.pencil,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(theme, '助手名称'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    autofocus: false,
                    style: TextStyle(fontSize: isMobile ? 16 : 14),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '示例助手',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(theme, '聊天壁纸'),
                  const SizedBox(height: 4),
                  Text(
                    '助手壁纸优先级高于全局设置',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CustomSwitch(
              value: chatBackground.enabled,
              onChanged: (v) =>
                  onChatBackgroundChanged(chatBackground.copyWith(enabled: v)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _WallpaperArea(
          imageUrl: chatBackground.imageUrl,
          onPick: onPickWallpaper,
          onRemove: () => onChatBackgroundChanged(
            chatBackground.copyWith(imageUrl: '', enabled: false),
          ),
        ),
        if (chatBackground.enabled && chatBackground.imageUrl.isNotEmpty) ...[
          const SizedBox(height: 16),
          _label(
            theme,
            '背景透明度  ${((chatBackground.opacity ?? 0.7) * 100).round()}%',
          ),
          Slider(
            min: 0.1,
            max: 1,
            divisions: 9,
            value: (chatBackground.opacity ?? 0.7).clamp(0.1, 1),
            label: '${((chatBackground.opacity ?? 0.7) * 100).round()}%',
            onChanged: (v) =>
                onChatBackgroundChanged(chatBackground.copyWith(opacity: v)),
          ),
          Row(
            children: [
              Expanded(
                child: Text('显示渐变遮罩', style: theme.textTheme.bodyMedium),
              ),
              const SizedBox(width: 12),
              CustomSwitch(
                value: chatBackground.showOverlay ?? true,
                onChanged: (v) => onChatBackgroundChanged(
                  chatBackground.copyWith(showOverlay: v),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The assistant wallpaper picker: a tap-to-upload dropzone, or a preview with
/// a remove affordance once an image is set (mirrors the global 聊天背景设置
/// `_ImageArea`).
class _WallpaperArea extends StatelessWidget {
  const _WallpaperArea({
    required this.imageUrl,
    required this.onPick,
    required this.onRemove,
  });

  final String imageUrl;
  final Future<void> Function() onPick;
  final VoidCallback onRemove;

  MemoryImage? _decode() {
    final marker = imageUrl.indexOf('base64,');
    if (marker < 0) return null;
    try {
      return MemoryImage(base64Decode(imageUrl.substring(marker + 7)));
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = _decode();

    if (image != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image(
              image: image,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(LucideIcons.x, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor, width: 2),
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.imagePlus,
              size: 26,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            Text(
              '点击上传壁纸',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 提示词 ────────────────────────────────────────────────────────────────────

class _PromptTab extends StatelessWidget {
  const _PromptTab({required this.controller, required this.onPickPreset});

  final TextEditingController controller;
  final VoidCallback onPickPreset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '系统提示词',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              OutlinedButton.icon(
                onPressed: onPickPreset,
                icon: const Icon(LucideIcons.sparkles, size: 16),
                label: const Text('选择预设提示词'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: false,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(fontSize: isMobile ? 16 : 14, height: 1.5),
              decoration: InputDecoration(
                hintText: '请输入系统提示词，定义助手的角色和行为特征...',
                alignLabelWithHint: true,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '提示词将作为系统消息发送给 AI，定义助手的角色和行为',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 记忆 ─────────────────────────────────────────────────────────────────────

class _MemoryTab extends StatelessWidget {
  const _MemoryTab({
    required this.assistantId,
    required this.assistantName,
    required this.enabled,
    required this.onChanged,
  });

  final String assistantId;
  final String assistantName;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          child: Row(
            children: [
              Icon(
                LucideIcons.brain,
                size: 20,
                color: theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '启用记忆功能',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '开启后，助手会记住与你的对话内容',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              CustomSwitch(value: enabled, onChanged: onChanged),
            ],
          ),
        ),
        if (enabled) ...[
          const SizedBox(height: 16),
          Material(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: assistantId.isEmpty
                  ? null
                  : () => context.push(
                        AssistantMemoryRoute.pathFor(assistantId),
                        extra: assistantName,
                      ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.bookOpen,
                      size: 20,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '私有记忆',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '管理该助手的私有记忆：添加 / 搜索 / 编辑 / 删除',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── 技能 ─────────────────────────────────────────────────────────────────────

class _SkillsTab extends ConsumerWidget {
  const _SkillsTab({required this.skillIds, required this.onToggle});

  final List<String> skillIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final skills = (ref.watch(skillsProvider).asData?.value ?? const <Skill>[])
        .where((s) => s.enabled)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.zap,
                    size: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '绑定技能',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '选择要绑定到此助手的技能，绑定后技能摘要将注入系统提示词',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (skills.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                '暂无可用技能，请先在设置 → 技能管理中启用技能',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (final skill in skills) _skillRow(theme, skill),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '已绑定 ${skillIds.length} 个技能',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _skillRow(ThemeData theme, Skill skill) {
    final checked = skillIds.contains(skill.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: checked
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onToggle(skill.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: checked ? theme.colorScheme.primary : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: checked,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (_) => onToggle(skill.id),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  skill.emoji ?? '🔧',
                  style: const TextStyle(fontSize: 18, height: 1),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        skill.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (skill.source == SkillSource.builtin)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Text(
                      '内置',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── shared bits ──────────────────────────────────────────────────────────────

Widget _label(ThemeData theme, String text) => Text(
  text,
  style: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: theme.colorScheme.onSurfaceVariant,
  ),
);

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: child,
    );
  }
}

// ─── Parameter tab ─────────────────────────────────────────────────────────

/// Wraps [ParameterEditor] in a scrollable tab body, operating on the
/// local per-assistant [ParameterSettings] instead of the global provider.
class _ParameterTab extends StatelessWidget {
  const _ParameterTab({required this.settings, required this.delegate});

  final ParameterSettings settings;
  final ParameterDelegate delegate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [ParameterEditor(settings: settings, delegate: delegate)],
    );
  }
}

/// Local [ParameterDelegate] that mutates an in-memory [ParameterSettings] and
/// calls back with the new value so the dialog's [setState] can rebuild the
/// parameter tab.
class _AssistantParamDelegate implements ParameterDelegate {
  _AssistantParamDelegate(this._onChanged);

  final ValueChanged<ParameterSettings> _onChanged;
  ParameterSettings _ps = const ParameterSettings();

  /// Must be called once from the dialog state to sync the initial value.
  void attach(ParameterSettings initial) => _ps = initial;

  @override
  void setParameterValue(String key, Object? value) {
    final next = Map<String, dynamic>.of(_ps.values);
    next[key] = value;
    _ps = _ps.copyWith(values: next);
    _onChanged(_ps);
  }

  @override
  void setParameterEnabled(String key, bool enabled) {
    final next = Map<String, bool>.of(_ps.enabledFlags);
    next[key] = enabled;
    _ps = _ps.copyWith(enabledFlags: next);
    _onChanged(_ps);
  }

  @override
  void addCustomParameter(Map<String, dynamic> param) {
    final next = List<Map<String, dynamic>>.of(_ps.customParameters)
      ..add(param);
    _ps = _ps.copyWith(customParameters: next);
    _onChanged(_ps);
  }

  @override
  void removeCustomParameter(int index) {
    final next = List<Map<String, dynamic>>.of(_ps.customParameters);
    if (index >= 0 && index < next.length) {
      next.removeAt(index);
      _ps = _ps.copyWith(customParameters: next);
      _onChanged(_ps);
    }
  }

  @override
  void updateCustomParameter(int index, Map<String, dynamic> param) {
    final next = List<Map<String, dynamic>>.of(_ps.customParameters);
    if (index >= 0 && index < next.length) {
      next[index] = param;
      _ps = _ps.copyWith(customParameters: next);
      _onChanged(_ps);
    }
  }
}

// ── Avatar editing types & widgets ───────────────────────────────────────────

/// The result of the assistant avatar edit sheet: exactly one of [emoji] or
/// [avatar] (base64 data URL) is set; both `null` means "reset to default".
class _AvatarResult {
  const _AvatarResult({this.emoji, this.avatar});

  final String? emoji;
  final String? avatar;
}

/// Bottom sheet with avatar source options for the assistant.
class _AssistantAvatarSheet extends StatelessWidget {
  const _AssistantAvatarSheet({
    required this.parentContext,
    required this.pickImage,
  });

  final BuildContext parentContext;
  final Future<_AvatarResult?> Function() pickImage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '设置助手头像',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _AvatarOptionTile(
              icon: LucideIcons.image,
              title: '选择图片',
              subtitle: '从相册选择并裁剪',
              onTap: () => pickImage(),
            ),
            _AvatarOptionTile(
              icon: LucideIcons.smile,
              title: '选择 Emoji',
              subtitle: '使用表情作为头像',
              onTap: () => _pickEmoji(context),
            ),
            _AvatarOptionTile(
              icon: LucideIcons.rotateCcw,
              title: '重置',
              subtitle: '恢复默认头像',
              onTap: () => Navigator.of(context).pop(
                const _AvatarResult(emoji: null, avatar: null),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickEmoji(BuildContext context) async {
    final emoji = await showDialog<String>(
      context: context,
      builder: (_) => const _AssistantEmojiPickerDialog(),
    );
    if (emoji == null || emoji.isEmpty) return;
    if (context.mounted) {
      Navigator.of(context).pop(
        _AvatarResult(emoji: emoji, avatar: null),
      );
    }
  }
}

class _AvatarOptionTile extends StatelessWidget {
  const _AvatarOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, size: 20, color: cs.primary),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Emoji picker dialog for the assistant avatar (mirrors the user avatar's
/// emoji picker).
class _AssistantEmojiPickerDialog extends StatefulWidget {
  const _AssistantEmojiPickerDialog();

  @override
  State<_AssistantEmojiPickerDialog> createState() =>
      _AssistantEmojiPickerDialogState();
}

class _AssistantEmojiPickerDialogState
    extends State<_AssistantEmojiPickerDialog> {
  final _controller = TextEditingController();

  static const _quickEmojis = [
    '🤖', '🧠', '💡', '⚡', '🔥', '🌟', '🎯', '🚀',
    '📚', '🔍', '💻', '🛠️', '🎨', '🎵', '📊', '🌍',
    '🦊', '🐱', '🐶', '🐼', '🦁', '🐯', '🐮', '🐸',
    '😀', '😎', '🤗', '🤔', '🥳', '🤩', '😇', '🥸',
    '🌸', '🌺', '🌻', '🌹', '🍀', '⭐', '🌈', '💎',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('选择 Emoji'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: '输入或粘贴 Emoji',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 12),
            Text(
              '快捷选择',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: _quickEmojis.length,
                itemBuilder: (ctx, i) => GestureDetector(
                  onTap: () => Navigator.of(context).pop(_quickEmojis[i]),
                  child: Center(
                    child: Text(
                      _quickEmojis[i],
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) {
              Navigator.of(context).pop(text.characters.first);
            }
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}

// ── Avatar crop page (bytes variant) ────────────────────────────────────────

/// A crop page that accepts raw bytes (from [ImagePickerApi.pickFromGallery])
/// rather than a file path; otherwise identical to the user avatar crop page.
class _AvatarCropPage extends StatefulWidget {
  const _AvatarCropPage({required this.imageBytes});

  final Uint8List imageBytes;

  static Future<Uint8List?> push(BuildContext context, Uint8List imageBytes) {
    return Navigator.of(context).push<Uint8List?>(
      PageRouteBuilder<Uint8List?>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) =>
            _AvatarCropPage(imageBytes: imageBytes),
      ),
    );
  }

  @override
  State<_AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<_AvatarCropPage> {
  final _cropController = CropController();
  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text(
                    '裁剪头像',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Crop(
                image: widget.imageBytes,
                controller: _cropController,
                aspectRatio: 1,
                withCircleUi: true,
                baseColor: Colors.black,
                maskColor: Colors.black.withValues(alpha: 0.7),
                cornerDotBuilder: (size, edgeAlignment) =>
                    const SizedBox.shrink(),
                onCropped: (croppedImage) {
                  setState(() => _isCropping = false);
                  if (mounted) Navigator.of(context).pop(croppedImage);
                },
              ),
            ),
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _isCropping
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: () {
                            setState(() => _isCropping = true);
                            _cropController.crop();
                          },
                          icon: const Icon(LucideIcons.check, size: 18),
                          label: const Text('确认'),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
