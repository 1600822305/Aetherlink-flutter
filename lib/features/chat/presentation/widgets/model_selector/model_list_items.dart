part of 'model_selector_dialog.dart';

/// Provider group header shown between search-result groups — provider icon +
/// uppercase vendor name, styled like a section label.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.tokens,
    required this.provider,
    required this.isFirst,
  });

  final _Tokens tokens;
  final ModelProvider provider;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final isDark = tokens.brightness == Brightness.dark;
    final asset = getModelOrProviderIcon('', provider.id, isDark: isDark);
    return Padding(
      padding: EdgeInsets.fromLTRB(12, isFirst ? 4 : 12, 12, 2),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Image.asset(
              asset,
              width: 16,
              height: 16,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              provider.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: tokens.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: tokens.border, height: 1)),
        ],
      ),
    );
  }
}

class _ModelItem extends StatefulWidget {
  const _ModelItem({
    required this.tokens,
    required this.provider,
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  final _Tokens tokens;
  final ModelProvider provider;
  final Model model;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_ModelItem> createState() => _ModelItemState();
}

class _ModelItemState extends State<_ModelItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final selected = widget.isSelected;

    // .solid-model-item background: transparent; selected -> selected-bg;
    // hover -> hover-bg; selected:hover -> active-bg.
    Color bg;
    if (selected) {
      bg = _hover ? t.active : t.selected;
    } else {
      bg = _hover ? t.hover : Colors.transparent;
    }

    final providerName = widget.provider.name;
    final description = (widget.model.description?.trim().isNotEmpty ?? false)
        ? widget.model.description!.trim()
        : '$providerName模型';

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          // .solid-model-item padding: 8px 12px; border-radius: 4px.
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              _ProviderIcon(
                tokens: t,
                provider: widget.provider,
                model: widget.model,
              ),
              // .solid-model-icon margin-right: 12px
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.model.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16, // 1rem
                        // selected -> font-weight 500, else 400
                        fontWeight: selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                        color: t.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    // .solid-model-name margin-bottom: 2px
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 12, // 0.75rem
                        color: t.textSecondary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Padding(
                  // .solid-model-check margin-left: 8px; color: primary.
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.check, size: 20, color: t.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderIcon extends StatelessWidget {
  const _ProviderIcon({
    required this.tokens,
    required this.provider,
    required this.model,
  });

  final _Tokens tokens;
  final ModelProvider provider;
  final Model model;

  @override
  Widget build(BuildContext context) {
    final isDark = tokens.brightness == Brightness.dark;
    final providerId = model.provider.isNotEmpty ? model.provider : provider.id;
    final asset = getModelOrProviderIcon(model.id, providerId, isDark: isDark);

    // .solid-model-icon : 28x28; img object-fit contain, 4px radius, soft shadow.
    return SizedBox(
      width: 28,
      height: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              offset: Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            asset,
            width: 28,
            height: 28,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _fallback(),
          ),
        ),
      ),
    );
  }

  // .solid-model-icon-fallback : provider name's first letter on bg-elevated.
  Widget _fallback() {
    final name = provider.name;
    final label = name.isNotEmpty ? name.characters.first : '?';
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.bgElevated,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: tokens.textSecondary,
        ),
      ),
    );
  }
}
