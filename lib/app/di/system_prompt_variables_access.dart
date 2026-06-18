import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/settings/application/system_prompt_variables_controller.dart';
import 'package:aetherlink_flutter/shared/domain/system_prompt_variables.dart';

part 'system_prompt_variables_access.g.dart';

/// App-level composition seam exposing the 系统提示词变量注入 config
/// ([SystemPromptVariables]) to the `chat` feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`,
/// so the chat send flow cannot read [SystemPromptVariablesController] (which
/// lives in `settings/application`) directly. It instead reads this provider in
/// `app/` (the composition root, which may depend on any feature) plus the
/// pure-Dart `shared/domain` [SystemPromptVariables] type.
///
/// Reactively re-exposes the controller's state, so toggling a variable in
/// 智能体提示词集合 takes effect on the next sent message.
@Riverpod(keepAlive: true)
SystemPromptVariables systemPromptVariables(Ref ref) =>
    ref.watch(systemPromptVariablesControllerProvider);
