import 'dart:convert';

/// Assembles the one-shot Termux setup script (设计文档 §10.5 方式 A / Termux-A).
///
/// The user runs this once inside Termux; it installs `openssh`, drops the
/// app-generated public key into `~/.ssh/authorized_keys` (password-less login),
/// makes `sshd` listen on `127.0.0.1:[port]`, and wires up autostart/keep-alive
/// (termux-services + Termux:Boot + wake-lock). Afterwards the app dials
/// `127.0.0.1:[port]` with the matching private key — Termux is just a local SSH
/// target (§1 白嫖), reusing `RemoteSshBackend` with zero new backend code.
///
/// Pure string assembly so it is trivially unit-testable. Two delivery shapes
/// (设计文档 §10.5「脚本可内置/分享到共享存储」):
///   · [buildScript]   — the full script, e.g. shared as a file the user runs
///     with `bash aetherlink-termux-setup.sh`.
///   · [buildOneLiner] — a self-contained, **offline** one-liner that base64-
///     decodes the whole script and pipes it to bash (no download, no file).
abstract final class TermuxSetup {
  /// Termux's default sshd port (and what the app dials).
  static const int defaultPort = 8022;

  /// Suggested filename when sharing the script as a file.
  static const String scriptFileName = 'aetherlink-termux-setup.sh';

  /// 开启 allow-external-apps（Termux-B / RUN_COMMAND 的前提）的一条命令：
  /// 用户在 Termux 里跑一次，之后本 App 才能通过 intent 代跑脚本。
  static const String allowExternalAppsCommand =
      'mkdir -p ~/.termux && '
      'printf "\\nallow-external-apps=true\\n" >> ~/.termux/termux.properties'
      ' && termux-reload-settings';

  /// Android shared storage root (相册/下载/文档 etc.). Termux can only reach it
  /// after `termux-setup-storage` has granted the storage permission; the app
  /// offers this as an alternate workspace root so users can browse `/sdcard`.
  static const String sharedStorageRoot = '/storage/emulated/0';

  /// The full setup script. [authorizedKey] is the single-line public key
  /// (`ssh-ed25519 AAAA… comment`) to authorize; it must not contain a single
  /// quote (generated keys never do) so it can be embedded in a `'…'` literal.
  static String buildScript({
    required String authorizedKey,
    int port = defaultPort,
  }) {
    return '''
#!/data/data/com.termux/files/usr/bin/bash
# Aetherlink Termux 一键接入 (Termux-A)。由 App 生成，内含一次性公钥。
# 作用：装 openssh、写入公钥免密登录、让 sshd 监听 127.0.0.1:$port、设置自启/保活。
set -e

PORT=$port
AUTHORIZED_KEY='$authorizedKey'

echo '==> Aetherlink：开始配置 Termux SSH ...'

# 1) 安装 openssh / termux-services（首次需联网；国内慢可先 termux-change-repo 换源）
echo '==> 安装 openssh / termux-services ...'
pkg install -y openssh termux-services

# 2) 写入公钥，开启免密码登录
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
if grep -qF "\$AUTHORIZED_KEY" ~/.ssh/authorized_keys 2>/dev/null; then
  echo '==> 公钥已存在，跳过写入'
else
  echo "\$AUTHORIZED_KEY" >> ~/.ssh/authorized_keys
  echo '==> 已写入公钥到 ~/.ssh/authorized_keys'
fi

# 3) 确保 sshd 监听指定端口
SSHD_CONFIG="\$PREFIX/etc/ssh/sshd_config"
if [ -f "\$SSHD_CONFIG" ]; then
  if grep -q '^Port ' "\$SSHD_CONFIG"; then
    sed -i "s/^Port .*/Port \$PORT/" "\$SSHD_CONFIG"
  else
    echo "Port \$PORT" >> "\$SSHD_CONFIG"
  fi
fi

# 4) 自启 / 保活：Termux:Boot 启动脚本 + termux-services
mkdir -p ~/.termux/boot
cat > ~/.termux/boot/start-sshd.sh <<'BOOT'
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
sshd
BOOT
chmod +x ~/.termux/boot/start-sshd.sh
sv-enable sshd 2>/dev/null || true

# 5) 立即启动（保活 + 重启 sshd）
termux-wake-lock 2>/dev/null || true
pkill sshd 2>/dev/null || true
sshd

# 6) 授权访问手机共享存储（相册/下载/文档）。会弹一次系统授权框，同意后才能在
#    App 里浏览 /sdcard；拒绝/取消不影响 SSH 连接，仅家目录可用。
echo '==> 申请共享存储权限（termux-setup-storage）...'
termux-setup-storage 2>/dev/null || true

echo ''
echo "==> 完成！sshd 已在 127.0.0.1:\$PORT 启动。"
echo '==> 若刚才弹了授权框并同意，App 即可浏览 /sdcard（相册/下载/文档）。'
echo '==> 回到 Aetherlink 点「完成 / 测试连接」即可使用。'
echo '==> 提示：请关闭 Termux 的电池优化，并安装 Termux:Boot 以便开机自启保活。'
''';
  }

  /// A self-contained one-liner the user pastes into Termux: it base64-decodes
  /// the entire [buildScript] output and pipes it to bash. Fully offline — the
  /// script (and the embedded public key) travel inside the command itself, so
  /// nothing is downloaded and no file is needed.
  static String buildOneLiner({
    required String authorizedKey,
    int port = defaultPort,
  }) {
    final script = buildScript(authorizedKey: authorizedKey, port: port);
    final encoded = base64.encode(utf8.encode(script));
    return 'echo $encoded | base64 -d | bash';
  }
}
