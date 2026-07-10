# Claude Code

> 最后更新：2026-07-10 | 类型：CLI 速查
>
> 关键词：`claude-code`、`agents`、`mcp`、`plugins`

## 启动与继续会话

```bash
claude
claude "先读取项目规则，只做分析，不修改文件。"
claude --continue
claude --resume
claude --worktree <name>
```

非交互运行：

```bash
claude -p "总结当前 Git 差异，不要修改文件。"
```

## 控制权限与范围

```bash
claude --permission-mode plan
claude --add-dir <additional-directory>
claude --allowed-tools 'Read,Glob,Grep'
```

`plan` 适合先理解任务。不要日常使用 `--dangerously-skip-permissions` 或 `--allow-dangerously-skip-permissions`。

## 交互式斜杠命令

进入 Claude Code 后输入 `/help` 查看当前版本可用命令。当前本机版本可重点使用：

| 目的 | 常用命令 |
| --- | --- |
| 模型与状态 | `/model`、`/status`、`/permissions`、`/usage` |
| 上下文 | `/compact`、`/clear`、`/memory` |
| 项目工作 | `/init`、`/review`、`/agents`、`/skills` |
| 扩展与设置 | `/mcp`、`/plugin`、`/config` |
| 诊断 | `/doctor`、`/help` |

```text
/model    # 选择模型
/compact  # 压缩上下文
/clear    # 开始新的话题
/mcp      # 查看、认证或重连 MCP
/plugin   # 管理 plugins 和 marketplace
/config   # 调整会话或用户设置
```

插件和实验功能的具体命令会随版本变化，以 `/help` 和命令自身提示为准。

## 扩展与诊断

```bash
claude mcp --help
claude plugin --help
claude agents --help
claude doctor
claude --help
```

项目规则通常写在 `CLAUDE.md`。运行前确认当前目录和 Git 状态；第三方 plugin、MCP 和 hooks 都应先检查数据权限。
