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
