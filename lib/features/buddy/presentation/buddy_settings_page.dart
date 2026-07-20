// 宠物设置页：悬浮宠物开关 + 放生（危险操作，二次确认）。
// 从宠物页顶栏设置按钮进入，风格与项目设置页一致。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/buddy/application/buddy_codex_skin_controller.dart';
import 'package:aetherlink_flutter/features/buddy/application/buddy_controller.dart';
import 'package:aetherlink_flutter/features/buddy/application/buddy_overlay_controller.dart';
import 'package:aetherlink_flutter/shared/utils/haptics.dart';

class BuddySettingsPage extends ConsumerWidget {
  const BuddySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final overlay = ref.watch(buddyOverlayControllerProvider);
    final hasPet = ref.watch(buddyControllerProvider).soul != null;

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
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(AppRouter.buddyPath),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
        title: const Text('宠物设置'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          _card(
            theme,
            header: const _CardHeader(title: '悬浮宠物', description: '让宠物陪你到处逛'),
            child: _row(
              theme,
              icon: LucideIcons.pictureInPicture2,
              accent: const Color(0xFF06B6D4),
              label: '悬浮宠物',
              description: '让宠物浮在应用所有页面上，可拖动贴边；展开后可在悬浮窗内直接关闭',
              trailing: Switch(
                value: overlay.enabled,
                onChanged: (v) {
                  Haptics.instance.onSwitch();
                  ref
                      .read(buddyOverlayControllerProvider.notifier)
                      .setEnabled(v);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          _card(
            theme,
            header: const _CardHeader(
                title: 'Codex 宠物皮肤',
                description: '兼容 codex-pet.org 宠物包，粘贴宠物页链接一键导入'),
            child: const _CodexSkinSection(),
          ),
          const SizedBox(height: 16),
          _card(
            theme,
            header: const _CardHeader(title: '危险操作', description: '放生后不可恢复'),
            child: _row(
              theme,
              icon: LucideIcons.doorOpen,
              accent: const Color(0xFFEF4444),
              label: '放生宠物',
              description: '告别当前宠物并清空数据，之后可重新孵化一只全新的（物种和稀有度重新随机）',
              trailing: TextButton(
                onPressed: hasPet ? () => _confirmRelease(context, ref) : null,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                ),
                child: const Text('放生'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRelease(BuildContext context, WidgetRef ref) async {
    final name = ref.read(buddyControllerProvider).soul?.name ?? '宠物';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('放生 $name？'),
        content: const Text('它会回到大自然，数据将被清空且无法找回。之后你可以重新孵化一只全新的宠物。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('放生'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    Haptics.instance.medium();
    ref.read(buddyControllerProvider.notifier).release();
    // 没有宠物就没有悬浮窗，顺手把开关也关掉。
    ref.read(buddyOverlayControllerProvider.notifier).setEnabled(false);
    // 回宠物页（孵化蛋界面）。
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouter.buddyPath);
    }
  }

  Widget _card(ThemeData theme,
      {required Widget header, required Widget child}) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          Divider(height: 1, color: theme.dividerColor),
          child,
        ],
      ),
    );
  }

  Widget _row(
    ThemeData theme, {
    required IconData icon,
    required Color accent,
    required String label,
    required String description,
    required Widget trailing,
  }) {
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                Text(label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _CodexSkinSection extends ConsumerStatefulWidget {
  const _CodexSkinSection();

  @override
  ConsumerState<_CodexSkinSection> createState() => _CodexSkinSectionState();
}

class _CodexSkinSectionState extends ConsumerState<_CodexSkinSection> {
  final TextEditingController _url = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final skinState = ref.watch(buddyCodexSkinProvider);
    final skin = skinState.skin;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (skin != null) ...[
            Row(
              children: [
                Icon(LucideIcons.sparkles,
                    size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('当前皮肤：${skin.name}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500)),
                ),
                TextButton(
                  onPressed: () {
                    Haptics.instance.light();
                    ref.read(buddyCodexSkinProvider.notifier).clear();
                  },
                  child: const Text('恢复默认外观'),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _url,
            decoration: InputDecoration(
              hintText: '例如 https://codex-pet.org/zh/pets/nailong0/',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
            ),
            style: theme.textTheme.bodyMedium,
          ),
          if (skinState.error != null) ...[
            const SizedBox(height: 6),
            Text(skinState.error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: const Color(0xFFEF4444))),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: skinState.importing
                  ? null
                  : () async {
                      Haptics.instance.light();
                      final ok = await ref
                          .read(buddyCodexSkinProvider.notifier)
                          .importFromUrl(_url.text);
                      if (ok) _url.clear();
                    },
              child: Text(skinState.importing ? '导入中…' : '导入皮肤'),
            ),
          ),
        ],
      ),
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
          const SizedBox(height: 2),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
