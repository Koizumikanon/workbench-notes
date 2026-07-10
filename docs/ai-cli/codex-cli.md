# Codex CLI

> 最后更新：2026-07-10 | 类型：CLI 速查
>
> 关键词：`codex`、`openai`、`agents`、`mcp`、`plugins`

## 启动与上下文

在项目根目录启动交互式会话：

```bash
codex
codex "先阅读项目规则并说明风险，不要修改文件。"
codex -C <project-directory>
```

恢复或分叉会话：

```bash
codex resume
codex resume --last
codex fork --last
```

## 常用工作方式

非交互执行：

```bash
codex exec "检查测试失败原因，只读分析并给出修复建议。"
codex review
```

给 prompt 写清四件事：目标、允许范围、禁止事项、验证方式。

```text
修复 <问题>。只修改 <目录>；不要碰配置和生产数据；完成后运行 <测试> 并总结结果。
```

## 交互式斜杠命令

在 Codex 输入框中输入 `/help` 可查看当前版本和账号实际可用的命令。以下分组已在 Codex CLI v0.144.1 验证：

| 目的 | 常用命令 |
| --- | --- |
| 模型与会话状态 | `/model`、`/status`、`/usage`、`/permissions` |
| 上下文控制 | `/compact`、`/new`、`/clear`、`/plan`、`/goal <objective>` |
| 工作区与结果 | `/init`、`/mention <file>`、`/diff`、`/review` |
| 扩展能力 | `/skills`、`/mcp`、`/plugins`、`/hooks`、`/experimental` |
| 会话管理 | `/rename`、`/resume`、`/fork`、`/archive`、`/delete` |
| 界面与诊断 | `/config`、`/statusline`、`/raw`、`/keymap`、`/feedback` |

最常用的几个：

```text
/model       # 选择模型和推理强度
/compact     # 压缩长对话，释放上下文
/status      # 查看模型、权限和 token 使用
/permissions # 调整当前会话的命令权限
/review      # 审查当前 Git 改动
/skills      # 查看和开关可用 skills
/mcp         # 查看 MCP 工具；可用 /mcp verbose 查看详情
/diff        # 查看 Git 差异，包括未跟踪文件
```

命令随版本、账号权限和实验功能变化；陌生命令优先执行 `/help`，不要凭旧教程猜参数。

## 权限与目录

```bash
codex -s read-only
codex -s workspace-write
codex --add-dir <additional-directory>
codex --search
```

不要把 `--dangerously-bypass-approvals-and-sandbox` 当作日常选项。它会跳过审批和 sandbox，只适合外层已经可靠隔离的自动化环境。

## Rules、Skills、MCP、Plugins

- `AGENTS.md`：仓库长期规则、验证命令和协作约定。
- Skill：可复用流程，例如公开文档审核或工作经验沉淀。
- MCP：连接外部文档、代码托管或其他服务。
- Plugin：可安装能力包，可能包含多个 skills、工具或配置。

```bash
codex mcp list
codex mcp get <server-name>
codex plugin marketplace list
codex plugin list
codex plugin add <plugin>@<marketplace>
codex plugin remove <plugin>@<marketplace>
```

安装 plugin 前先确认来源、包含的 hooks/MCP、需要的权限和可访问的数据。优先从已配置 marketplace 选择；不要为“看起来方便”安装来源不明的 bundle。

## Plugin 选择

先不必为了“功能更多”安装 plugin。只有普通 CLI、skills 和 `gh` 已经无法覆盖需求时，再按场景选择：

| 场景 | 可评估的 plugin | 注意事项 |
| --- | --- | --- |
| 需要在 agent 内处理 Issue、PR、Actions | `github` | 先审查仓库与授权范围；已有 `gh` 能完成的简单操作不必安装 |
| 需要专项安全代码审查 | `codex-security` | 作为审查补充，不替代人工判断 |
| 开始制作复杂前端或 Web 产品 | `build-web-apps` | 先确认是否与项目现有框架和 skill 重叠 |

这些名称来自当前已配置 marketplace，具体内容和版本可能变化。查看后再安装：

```bash
codex plugin marketplace list
codex plugin list
codex plugin add github@openai-api-curated
```

## 诊断与更新

```bash
codex --help
codex doctor
codex login
codex update
```

文档访问异常时，先检查直连和 `codex mcp list`；不要自行启用全局代理。
