/// How Termux was installed, which decides whether the one-tap setup can work
/// (设计文档 §10.5 坑：必须 F-Droid/GitHub 版，Play 版已废弃跑不通).
enum TermuxVariant {
  /// Not installed (or not an Android device).
  absent,

  /// Installed from F-Droid (`org.fdroid.fdroid`) — supported.
  fdroid,

  /// Installed from Google Play (`com.android.vending`) — the **deprecated**
  /// build; package management / RUN_COMMAND don't work, so we warn the user.
  play,

  /// Installed but the installer source is unknown — typically a GitHub /
  /// sideloaded APK, which is the supported case (treated as OK with a hint).
  unknown,
}

/// The result of probing for a Termux install.
class TermuxInstallStatus {
  const TermuxInstallStatus({
    required this.installed,
    required this.variant,
    this.installer,
  });

  /// Whether `com.termux` is present on the device.
  final bool installed;

  /// Best guess at the install source (see [TermuxVariant]).
  final TermuxVariant variant;

  /// The raw installer package name (e.g. `org.fdroid.fdroid`), or null.
  final String? installer;

  /// True when the install is the deprecated Play build that can't run the
  /// setup script.
  bool get isUnsupportedPlayBuild => variant == TermuxVariant.play;
}

/// Thrown by [TermuxApi.runCommand] when the RUN_COMMAND intent is rejected.
/// [externalAppsDisabled] means Termux 端没开 allow-external-apps=true；
/// [permissionDenied] means 用户拒了本机的 RUN_COMMAND 运行时权限。UI 据此
/// 引导用户开启/授权后重试。
class TermuxRunCommandException implements Exception {
  const TermuxRunCommandException(
    this.message, {
    this.externalAppsDisabled = false,
    this.permissionDenied = false,
  });

  final String message;
  final bool externalAppsDisabled;
  final bool permissionDenied;

  @override
  String toString() => message;
}

/// Detects whether (and how) Termux is installed, so the Termux one-tap flow can
/// guide the user (设计文档 §10.5 / Termux-A 步骤 a)，and（Termux-B / 方式 B）
/// asks Termux to run a script via the RUN_COMMAND intent.
///
/// Android-only via a platform channel; implementations live under `impl/`. The
/// interface stays pure Dart so callers depend on the abstraction and tests can
/// substitute a fake (ADR-0007).
abstract interface class TermuxApi {
  Future<TermuxInstallStatus> detect();

  /// 让 Termux 在前台会话里代跑 [script]（bash -c）。发送即返回，不等执行结果；
  /// 首次会先弹系统权限申请（RUN_COMMAND 是运行时权限）；发不出去时抛
  /// [TermuxRunCommandException]。
  Future<void> runCommand(String script);

  /// 把 Termux 带到前台（快速跳转，方便去粘贴命令/看代跑进度）。失败抛
  /// [TermuxRunCommandException]。
  Future<void> openApp();
}
