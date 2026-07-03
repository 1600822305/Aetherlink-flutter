import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/debate_access.dart';
import 'package:aetherlink_flutter/features/debate/application/debate_engine.dart';

part 'debate_controller.g.dart';

/// 一场辩论的运行状态（开始面板与输入框按钮读取）。
class DebateRunState {
  const DebateRunState({
    this.isDebating = false,
    this.round = 0,
    this.speakerName,
  });

  final bool isDebating;

  /// 当前轮次；0 = 开场/总结阶段。
  final int round;

  /// 正在发言的角色名，间隙期间为 null。
  final String? speakerName;
}

/// 驱动 [DebateEngine] 的 Riverpod 控制器：同一时间最多一场辩论，
/// 发言经 `app/di/debate_access.dart` 的端口写进当前话题。
@Riverpod(keepAlive: true)
class DebateController extends _$DebateController {
  DebateEngine? _engine;

  @override
  DebateRunState build() => const DebateRunState();

  Future<void> start(DebateRunConfig config) async {
    if (state.isDebating) return;
    final port = ref.read(debateChatPortProvider);
    final engine = DebateEngine(
      port: port,
      onProgress: (round, speaking) => state = DebateRunState(
        isDebating: true,
        round: round,
        speakerName: speaking?.name,
      ),
    );
    _engine = engine;
    state = const DebateRunState(isDebating: true);
    try {
      final outcome = await engine.run(config);
      if (outcome == DebateOutcome.stopped) {
        await port.announce('🛑 **AI辩论已停止**\n\n辩论被用户手动终止。');
      }
    } finally {
      _engine = null;
      state = const DebateRunState();
    }
  }

  void stop() => _engine?.stop();
}
