/// App-level composition seam：主题风格页（theming）读写明暗模式，模式控制器
/// 归 settings 的 application 层，经这里转出（跨 feature 不直接 import
/// application，见 test/architecture/import_boundaries_test.dart）。
library;

export 'package:aetherlink_flutter/features/settings/application/theme_mode_controller.dart'
    show themeModeControllerProvider;
