// 终端命令 → 权限 pattern 的解析（审批重构 PR1，纯 Dart 可单测）。
//
// 对标 OpenCode permission/arity.ts + Claude Code 的 Bash 前缀规则：
// - 按 `&&` `||` `;` `|` `&` 换行拆子命令，每段独立参与权限判定；
// - 用 arity 词典提取「人类可理解的命令头」（git → 2 个 token、
//   npm run → 3 个），生成 `npm run *` 粒度的授权建议；
// - 检测到命令替换/进程替换（`$()`、反引号、`<()`、`>()`）等静态解析
//   看不穿的注入特征时，放弃前缀归纳，整条原文作为唯一 pattern
//   （等价于强制 ask，除非用户精确允许过同一条命令）。

/// 注入特征：命令替换 / 进程替换 / eval。内层可执行任意命令，
/// 前缀归纳对它们失效。
final RegExp _kInjectionPattern = RegExp(r'\$\(|`|<\(|>\(|(^|[\s;&|])eval\b');

/// 按 `;` `&&` `||` `|` `&` 与换行切分子命令段。
Iterable<String> splitShellSegments(String command) => command
    .split(RegExp(r'\|\||&&|[;|&\n]'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty);

/// 一次终端调用参与权限判定的 patterns：每个子命令段的规范化原文
/// （空白折叠）。规则里写 `npm run *` 即可覆盖 `npm  run dev` 等变体。
/// 检出注入特征时返回整条命令原文单元素列表。
List<String> terminalPermissionPatterns(String command) {
  final trimmed = command.trim();
  if (trimmed.isEmpty) return const [];
  if (_kInjectionPattern.hasMatch(trimmed)) return [_normalize(trimmed)];
  return [for (final segment in splitShellSegments(trimmed)) _normalize(segment)];
}

/// 审批卡「始终允许」的授权建议 pattern：每个子命令段按 arity 词典
/// 提取命令头 + ` *`（如 `npm run dev` → `npm run *`）。检出注入特征时
/// 返回空列表（不给宽泛授权建议，只能精确允许本条）。
List<String> terminalAlwaysPatterns(String command) {
  final trimmed = command.trim();
  if (trimmed.isEmpty || _kInjectionPattern.hasMatch(trimmed)) return const [];
  final result = <String>[];
  for (final segment in splitShellSegments(trimmed)) {
    final prefix = shellCommandPrefix(segment);
    if (prefix.isEmpty) continue;
    final pattern = '${prefix.join(' ')} *';
    if (!result.contains(pattern)) result.add(pattern);
  }
  return result;
}

/// 提取单个子命令的「命令头」token 列表：跳过前导环境变量赋值，
/// 忽略旗标（`-` 开头不计入 arity），按最长前缀命中 arity 词典决定
/// 取几个 token；词典无命中默认取 1 个。
List<String> shellCommandPrefix(String segment) {
  final tokens = _normalize(segment)
      .split(' ')
      .where((t) => t.isNotEmpty)
      .skipWhile((t) => RegExp(r'^[A-Za-z_][A-Za-z0-9_]*=').hasMatch(t))
      .where((t) => !t.startsWith('-'))
      .toList(growable: false);
  if (tokens.isEmpty) return const [];
  for (var len = tokens.length; len > 0; len--) {
    final prefix = tokens.sublist(0, len).join(' ');
    final arity = _kArity[prefix];
    if (arity != null) {
      return tokens.sublist(0, arity > tokens.length ? tokens.length : arity);
    }
  }
  return tokens.sublist(0, 1);
}

String _normalize(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

/// 命令前缀 → 构成「命令头」的 token 数（旗标不计）。
/// 移植自 OpenCode permission/arity.ts，最长前缀优先。
const Map<String, int> _kArity = {
  'cat': 1,
  'cd': 1,
  'chmod': 1,
  'chown': 1,
  'cp': 1,
  'echo': 1,
  'env': 1,
  'export': 1,
  'grep': 1,
  'kill': 1,
  'killall': 1,
  'ln': 1,
  'ls': 1,
  'mkdir': 1,
  'mv': 1,
  'ps': 1,
  'pwd': 1,
  'rm': 1,
  'rmdir': 1,
  'sleep': 1,
  'source': 1,
  'tail': 1,
  'touch': 1,
  'unset': 1,
  'which': 1,
  'aws': 3,
  'az': 3,
  'bazel': 2,
  'brew': 2,
  'bun': 2,
  'bun run': 3,
  'bun x': 3,
  'cargo': 2,
  'cargo add': 3,
  'cargo run': 3,
  'cdk': 2,
  'cf': 2,
  'cmake': 2,
  'composer': 2,
  'consul': 2,
  'consul kv': 3,
  'crictl': 2,
  'deno': 2,
  'deno task': 3,
  'doctl': 3,
  'docker': 2,
  'docker builder': 3,
  'docker compose': 3,
  'docker container': 3,
  'docker image': 3,
  'docker network': 3,
  'docker volume': 3,
  'eksctl': 2,
  'eksctl create': 3,
  'firebase': 2,
  'flutter': 2,
  'flutter pub': 3,
  'flyctl': 2,
  'gcloud': 3,
  'gh': 3,
  'git': 2,
  'git config': 3,
  'git remote': 3,
  'git stash': 3,
  'go': 2,
  'gradle': 2,
  'helm': 2,
  'heroku': 2,
  'hugo': 2,
  'ip': 2,
  'ip addr': 3,
  'ip link': 3,
  'ip netns': 3,
  'ip route': 3,
  'kind': 2,
  'kind create': 3,
  'kubectl': 2,
  'kubectl kustomize': 3,
  'kubectl rollout': 3,
  'kustomize': 2,
  'make': 2,
  'mc': 2,
  'mc admin': 3,
  'minikube': 2,
  'mongosh': 2,
  'mysql': 2,
  'mvn': 2,
  'ng': 2,
  'npm': 2,
  'npm exec': 3,
  'npm init': 3,
  'npm run': 3,
  'npm view': 3,
  'nvm': 2,
  'nx': 2,
  'openssl': 2,
  'openssl req': 3,
  'openssl x509': 3,
  'pip': 2,
  'pipenv': 2,
  'pnpm': 2,
  'pnpm dlx': 3,
  'pnpm exec': 3,
  'pnpm run': 3,
  'poetry': 2,
  'podman': 2,
  'podman container': 3,
  'podman image': 3,
  'psql': 2,
  'pulumi': 2,
  'pulumi stack': 3,
  'pyenv': 2,
  'python': 2,
  'rake': 2,
  'rbenv': 2,
  'redis-cli': 2,
  'rustup': 2,
  'serverless': 2,
  'sfdx': 3,
  'skaffold': 2,
  'sls': 2,
  'sst': 2,
  'swift': 2,
  'systemctl': 2,
  'terraform': 2,
  'terraform workspace': 3,
  'tmux': 2,
  'turbo': 2,
  'ufw': 2,
  'vault': 2,
  'vault auth': 3,
  'vault kv': 3,
  'vercel': 2,
  'volta': 2,
  'wp': 2,
  'yarn': 2,
  'yarn dlx': 3,
  'yarn run': 3,
};
