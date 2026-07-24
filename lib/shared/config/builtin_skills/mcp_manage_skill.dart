import 'package:aetherlink_flutter/shared/domain/skill.dart';

/// 内置 skill：MCP 服务器管理（mcp_manage）的完整用法。
/// 工具本体只带最小 schema，config 格式与安装流程放这里按需加载
/// （渐进披露，对齐 read_skill 模式）。
const Skill kMcpManageSkill = Skill(
  id: 'builtin-mcp-manage',
  name: 'MCP 服务器管理',
  description:
      'mcp_manage 工具的完整用法：添加 stdio/HTTP/SSE MCP 服务器的 '
      'config 格式、终端安装依赖流程、启停与排错',
  emoji: '🧩',
  tags: ['MCP', '工具', '配置'],
  source: SkillSource.builtin,
  version: '1.0.0',
  author: 'AetherLink',
  enabled: true,
  content: '''
## 能力概览

`mcp_manage` 管理全局 MCP 服务器配置（与设置页同一份，所有对话/任务共用，
持久保存）。四个 action：

- `list`：列出已配置的服务器（id、名称、类型、启用状态）。
- `add`：添加服务器（name + config），默认添加后立即启用。
- `remove`：删除服务器（按 name 或 id）。
- `toggle`：启用/停用（name/id + enabled）。

list 免审批；add/remove/toggle 会弹审批卡请用户确认。

## config 格式（Claude Desktop mcpServers 条目同款）

stdio（本地子进程，在内置终端环境里运行）：

```json
{
  "action": "add",
  "name": "filesystem",
  "config": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-filesystem", "/root"],
    "env": {"KEY": "value"}
  }
}
```

Streamable HTTP / SSE（远程服务）：

```json
{
  "action": "add",
  "name": "my-remote",
  "config": {
    "type": "streamableHttp",
    "url": "https://example.com/mcp",
    "headers": {"Authorization": "Bearer xxx"}
  }
}
```

type 可省略：有 `command` 推断为 stdio，有 `url` 推断为 sse。
显式可填：`stdio` / `sse` / `streamableHttp`。

## 标准安装流程（stdio）

1. 先确认运行环境有依赖：stdio 进程跑在内置终端（proot 容器）里，
   `npx`/`uvx` 类命令需要对应运行时。先用终端验证：
   `node --version` / `python3 --version`；缺就先装
   （如 `apk add nodejs npm` / `pkg install nodejs`，视容器发行版而定）。
2. 能直接 `npx -y <包名>` 拉起的服务器不必预装；网络差或反复用的
   建议先 `npm install -g <包名>` 再把 command 写成安装后的命令。
3. `mcp_manage add` 写入配置（默认立即启用并拉起进程）。
4. 验证：启用后该服务器的工具会在下一轮任务/对话装配时并入工具列表；
   本轮内不会立即出现，提醒用户重新发起任务即可使用。
5. 启动失败不会回滚开关：请用户到「设置 → MCP 服务器」查看日志排错，
   或用终端手动跑一遍 command 看报错。

## 注意

- 添加前先 `list` 查重；同名会被拒绝（想改配置：先 remove 再 add）。
- 密钥类配置（headers/env 里的 token）来自用户提供，不要臆造；
  需要时先向用户询问。
- stdio 的 command 是任意命令，添加即意味着未来会执行它——
  只添加用户明确要求或明确同意的服务器。''',
);
