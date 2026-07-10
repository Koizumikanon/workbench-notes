# Gemini CLI

> 最后更新：2026-07-10 | 类型：CLI 速查
>
> 关键词：`gemini`、`agents`、`extensions`、`mcp`

## 启动与会话

```bash
gemini
gemini "先读取项目规则，只做分析，不修改文件。"
gemini -p "总结当前 Git 差异，不要修改文件。"
gemini --resume latest
gemini --worktree <name>
```

## 权限与目录

```bash
gemini --approval-mode plan
gemini --approval-mode auto_edit
gemini --include-directories <additional-directory>
```

先用 `plan` 或默认确认模式。`--yolo` 会自动接受动作，不适合作为不熟悉项目的默认设置。

## 扩展与诊断

```bash
gemini mcp --help
gemini skills --help
gemini extensions --help
gemini hooks --help
gemini --list-sessions
gemini --help
```

项目规则通常写在 `GEMINI.md`。安装 extension 或配置 MCP 前先审查来源、权限和数据范围。

## 交互式命令

进入 Gemini CLI 后先输入 `/help`。Gemini 的斜杠命令迭代较快，不建议把旧版本命令当固定接口。当前可确认的交互入口包括：

```text
/help  # 查看当前版本命令
/auth  # 查看或处理认证入口
```

模型、会话、工具和配置的具体命令应以 `/help` 为准；需要稳定自动化时，优先使用外部命令 `gemini --help`、`gemini mcp --help`、`gemini skills --help`、`gemini extensions --help` 和 `gemini hooks --help`。
