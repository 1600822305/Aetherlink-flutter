// Avatar editing bottom sheet: pick local image (+ crop), emoji, URL, QQ
// import, or reset. Modelled after kelivo's `_editAvatar` with the addition of
// the original web's crop capability.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:aetherlink_flutter/features/chat/application/user_avatar_controller.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/dialogs/avatar_crop_page.dart';

/// Shows the avatar editing bottom sheet with multiple source options.
Future<void> showAvatarEditSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _AvatarEditSheetContent(parentRef: ref),
  );
}

class _AvatarEditSheetContent extends StatelessWidget {
  const _AvatarEditSheetContent({required this.parentRef});

  final WidgetRef parentRef;

  UserAvatarController get _controller =>
      parentRef.read(userAvatarControllerProvider.notifier);

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
            // Drag handle
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
              '设置头像与名称',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _OptionTile(
              icon: LucideIcons.userPen,
              title: '修改名称',
              subtitle: '自定义聊天中显示的用户名',
              onTap: () => _editName(context),
            ),
            _OptionTile(
              icon: LucideIcons.image,
              title: '选择图片',
              subtitle: '从相册选择并裁剪',
              onTap: () => _pickLocalImage(context),
            ),
            _OptionTile(
              icon: LucideIcons.smile,
              title: '选择 Emoji',
              subtitle: '使用表情作为头像',
              onTap: () => _pickEmoji(context),
            ),
            _OptionTile(
              icon: LucideIcons.link,
              title: '输入链接',
              subtitle: '使用网络图片 URL',
              onTap: () => _inputUrl(context),
            ),
            _OptionTile(
              icon: LucideIcons.messageCircle,
              title: '从 QQ 导入',
              subtitle: '输入 QQ 号获取头像',
              onTap: () => _importFromQQ(context),
            ),
            _OptionTile(
              icon: LucideIcons.rotateCcw,
              title: '重置',
              subtitle: '恢复默认头像',
              onTap: () {
                _controller.reset();
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _editName(BuildContext context) async {
    final navigator = Navigator.of(context);
    final current = parentRef.read(userAvatarControllerProvider).name;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => _NameInputDialog(initial: current),
    );
    if (name == null) return;
    _controller.setName(name);
    if (navigator.mounted) navigator.pop();
  }

  Future<void> _pickLocalImage(BuildContext context) async {
    final navigator = Navigator.of(context);
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    // Navigate to custom crop page (with SafeArea, no transition animation)
    if (!context.mounted) return;
    final croppedBytes = await AvatarCropPage.push(context, picked.path);
    if (croppedBytes == null) return;

    // Save cropped bytes to a persistent path under app documents
    final appDir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory(p.join(appDir.path, 'avatars'));
    if (!avatarDir.existsSync()) {
      avatarDir.createSync(recursive: true);
    }
    final destPath = p.join(avatarDir.path, 'user_avatar.png');
    await File(destPath).writeAsBytes(croppedBytes);

    _controller.setFile(destPath);
    if (navigator.mounted) navigator.pop();
  }

  Future<void> _pickEmoji(BuildContext context) async {
    final navigator = Navigator.of(context);
    final emoji = await showDialog<String>(
      context: context,
      builder: (ctx) => const _EmojiPickerDialog(),
    );
    if (emoji == null || emoji.isEmpty) return;
    _controller.setEmoji(emoji);
    if (navigator.mounted) navigator.pop();
  }

  Future<void> _inputUrl(BuildContext context) async {
    final navigator = Navigator.of(context);
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => const _UrlInputDialog(),
    );
    if (url == null || url.isEmpty) return;
    _controller.setUrl(url);
    if (navigator.mounted) navigator.pop();
  }

  Future<void> _importFromQQ(BuildContext context) async {
    final navigator = Navigator.of(context);
    final qq = await showDialog<String>(
      context: context,
      builder: (ctx) => const _QQInputDialog(),
    );
    if (qq == null || qq.isEmpty) return;
    final url = 'https://q1.qlogo.cn/g?b=qq&nk=$qq&s=640';
    _controller.setUrl(url);
    if (navigator.mounted) navigator.pop();
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
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

// ── Name input dialog ───────────────────────────────────────────────────────

class _NameInputDialog extends StatefulWidget {
  const _NameInputDialog({required this.initial});

  final String initial;

  @override
  State<_NameInputDialog> createState() => _NameInputDialogState();
}

class _NameInputDialogState extends State<_NameInputDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改用户名称'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: '输入自定义名称，留空恢复默认',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        maxLength: 24,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

// ── Emoji picker dialog ─────────────────────────────────────────────────────

class _EmojiPickerDialog extends StatefulWidget {
  const _EmojiPickerDialog();

  @override
  State<_EmojiPickerDialog> createState() => _EmojiPickerDialogState();
}

class _EmojiPickerDialogState extends State<_EmojiPickerDialog> {
  final _controller = TextEditingController();

  static const _quickEmojis = [
    '😀', '😁', '😂', '🤣', '😃', '😄', '😅', '😊',
    '😍', '😘', '🥰', '😎', '🤗', '🤔', '😏', '🙄',
    '😴', '🥳', '🤩', '😇', '🤠', '🥸', '🦊', '🐱',
    '🐶', '🐼', '🐨', '🦁', '🐯', '🐮', '🐷', '🐸',
    '🌸', '🌺', '🌻', '🌹', '🍀', '⭐', '🌈', '🔥',
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

// ── URL input dialog ────────────────────────────────────────────────────────

class _UrlInputDialog extends StatefulWidget {
  const _UrlInputDialog();

  @override
  State<_UrlInputDialog> createState() => _UrlInputDialogState();
}

class _UrlInputDialogState extends State<_UrlInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('输入图片链接'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'https://example.com/avatar.png',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType: TextInputType.url,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final url = _controller.text.trim();
            if (url.isNotEmpty) Navigator.of(context).pop(url);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}

// ── QQ input dialog ─────────────────────────────────────────────────────────

class _QQInputDialog extends StatefulWidget {
  const _QQInputDialog();

  @override
  State<_QQInputDialog> createState() => _QQInputDialogState();
}

class _QQInputDialogState extends State<_QQInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('从 QQ 导入'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: '输入 QQ 号',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType: TextInputType.number,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final qq = _controller.text.trim();
            if (qq.isNotEmpty) Navigator.of(context).pop(qq);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
