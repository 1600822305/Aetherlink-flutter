import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/agent/data/datasources/local/agent_dao.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';

part 'agent_data_access.g.dart';

/// App-level composition seam exposing the agent Drift DAO.
///
/// 单一 Drift 库句柄在 chat 的 `appDatabaseProvider` 后面，而 agent 禁止
/// import chat 的任何内容（import 边界测试的 agent↔chat 规则），所以在
/// 组合根（app/di）把 [AgentDao] 组装出来，agent 侧只经此 seam 取用——
/// 与 memory_access.dart 的 [chatMemoryStore] 同款做法。
@Riverpod(keepAlive: true)
AgentDao agentDao(Ref ref) => ref.watch(appDatabaseProvider).agentDao;
