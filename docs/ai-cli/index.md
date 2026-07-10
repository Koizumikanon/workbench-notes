# AI Coding CLI

> 最后更新：2026-07-10 | 类型：工具索引
>
> 关键词：`ai`、`cli`、`coding-agent`、`terminal`

这些工具都能在终端中理解代码、编辑文件和运行命令，但命令、权限模型和扩展方式不同。先在项目根目录启动，先阅读仓库规则，再让 agent 操作。

| 工具 | 入口 | 适合先查什么 |
| --- | --- | --- |
| Codex CLI | `codex` | `AGENTS.md`、skills、MCP、plugins |
| Claude Code | `claude` | `CLAUDE.md`、权限模式、MCP、plugins |
| Gemini CLI | `gemini` | `GEMINI.md`、approval mode、extensions、skills |
| DeepSeek 客户端 | 取决于具体客户端 | 客户端来源、版本、配置与权限 |

## 通用开始方式

```bash
pwd
git status --short --branch
<tool> --help
<tool> "先阅读项目规则，说明你将检查哪些文件；不要修改。"
```

不要在不熟悉的仓库一开始就启用无确认权限、全局代理或全局插件。先用只读或计划模式确认范围，再逐步授予编辑和命令权限。
