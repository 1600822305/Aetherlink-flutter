import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// ── Avatar editing types & widgets ───────────────────────────────────────────

/// The result of the assistant avatar edit sheet: exactly one of [emoji] or
/// [avatar] (base64 data URL) is set; both `null` means "reset to default".
class AvatarResult {
  const AvatarResult({this.emoji, this.avatar});

  final String? emoji;
  final String? avatar;
}

/// Bottom sheet with avatar source options for the assistant.
class AssistantAvatarSheet extends StatelessWidget {
  const AssistantAvatarSheet({
    super.key,
    required this.parentContext,
    required this.pickImage,
  });

  final BuildContext parentContext;
  final Future<AvatarResult?> Function() pickImage;

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
              onTap: () => Navigator.of(
                context,
              ).pop(const AvatarResult(emoji: null, avatar: null)),
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
      Navigator.of(context).pop(AvatarResult(emoji: emoji, avatar: null));
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
    '🤖',
    '🧠',
    '💡',
    '⚡',
    '🔥',
    '🌟',
    '🎯',
    '🚀',
    '📚',
    '🔍',
    '💻',
    '🛠️',
    '🎨',
    '🎵',
    '📊',
    '🌍',
    '🦊',
    '🐱',
    '🐶',
    '🐼',
    '🦁',
    '🐯',
    '🐮',
    '🐸',
    '😀',
    '😎',
    '🤗',
    '🤔',
    '🥳',
    '🤩',
    '😇',
    '🥸',
    '🌸',
    '🌺',
    '🌻',
    '🌹',
    '🍀',
    '⭐',
    '🌈',
    '💎',
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
