import 'package:flutter/material.dart';

/// Static UI strings, ported verbatim from the original (i18n is a later
/// effort, per the M4.1 approach).
const String _assistantTabLabel = '助手';
const String _topicTabLabel = '话题';
const String _settingsTabLabel = '设置';
const String _searchHint = '搜索话题...';
const String _emptySidebarLabel = '暂无内容';

/// The side drawer, restored to the original TopicManagement sidebar's visual
/// shell: a tab bar (助手 / 话题 / 设置), a search field, and a list area.
///
/// This round stands up the structure only (M4.2.0b is appearance-only): there
/// is no real topic/assistant data and no management logic (those are later
/// slices), so the search field is disabled and the list area is an empty
/// placeholder — no mock entries.
class ChatSidebar extends StatelessWidget {
  const ChatSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: _assistantTabLabel),
                  Tab(text: _topicTabLabel),
                  Tab(text: _settingsTabLabel),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                // Search box — restored as a shell; disabled until topic data
                // is wired in a later slice.
                child: TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    hintText: _searchHint,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // List area — empty placeholder; real topic/assistant lists are a
              // later slice (no mock entries this round).
              Expanded(
                child: Center(
                  child: Text(
                    _emptySidebarLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
