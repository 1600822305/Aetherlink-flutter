# AGENTS.md

AI 助手在本仓库（`aetherlink_flutter`）工作时遵循以下约定。

## 验证

改完代码后，至少对改动到的文件跑一次静态分析：

```powershell
flutter analyze <改动的文件...>
```

- 已知存量告警：`lib/features/chat/application/chat_controller.dart:3513` 的
  `curly_braces_in_flow_control_structures`，与新改动无关，不要顺手改它。
- 涉及 `lib/shared/mcp_tools/` 时，相关单测在 `test/shared/mcp_tools/`。

## 提交 / 推送标准流程

环境为 **Windows PowerShell**，没有 bash heredoc，必须按下面的步骤来，避免每次踩坑。

1. 先看状态与改动：`git status --short`、`git diff --stat`、`git log --oneline -5`
   （`git log` 用来对齐提交风格）。
2. **提交信息写到临时文件再提交**（PowerShell 不支持 `$(cat <<'EOF')` heredoc）：
   - 用写文件工具把消息写到 `.git/COMMIT_MSG_TMP.txt`
   - `git add <明确列出改动文件>`（不要用 `git add .`）
   - `git commit -F .git/COMMIT_MSG_TMP.txt`
   - `Remove-Item .git/COMMIT_MSG_TMP.txt`
3. 多条命令在 PowerShell 里用 `;` 连接，不要用 bash 的 `&&`/heredoc。
4. 仅在用户**明确要求**时才推送：`git push origin main`。

### 提交信息规范

- 采用 Conventional Commits，**正文用中文**：`feat(scope): 简述` /
  `fix(scope): ...` / `refactor(scope): ...`（常见 scope：`chat`、`settings`）。
- 正文说明「为什么」，可用要点列出关键改动。
- 结尾固定附带署名 trailer：

```
Generated with [Devin](https://devin.ai)

Co-Authored-By: Devin <158243242+devin-ai-integration[bot]@users.noreply.github.com>
```

### Git 注意事项

- 不修改 git config；不使用交互式 `-i`；无改动时不提交。
- 行尾会有 `LF will be replaced by CRLF` 的 warning，属正常，可忽略。
