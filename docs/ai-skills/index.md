# AI Skills

> 最后更新：2026-07-10 | 类型：工作流指南
>
> 关键词：`ai`、`skills`、`agents`、`automation`

Skill 是给 AI agent 复用的任务工作流。它比单次提示词更持久，比插件更轻量：通常只包含一份 `SKILL.md`，必要时再带脚本、参考资料或模板。

## 适合做成 Skill 的内容

- 有稳定步骤的审核、发布、排障或交付流程。
- 每次都要重复解释的领域规则和安全边界。
- 需要在多项目、多 AI CLI 之间复用的操作方式。

不适合的内容：单次聊天结论、真实凭据、内部主机清单、长篇项目背景。

## 最小结构

```text
my-skill/
├─ SKILL.md
├─ agents/
│  └─ openai.yaml
└─ references/       # 可选：较长的按需资料
```

`SKILL.md` 的最小模板：

```markdown
---
name: my-skill
description: 说明这个 skill 做什么，以及哪些用户请求应触发它。
---

# 标题

1. 给出必须执行的步骤。
2. 写清验证方式和安全边界。
3. 将冗长背景资料放入 references/，按需读取。
```

## Skill、Plugin 与 MCP

| 类型 | 适合解决的问题 |
| --- | --- |
| Skill | 可复用的提示、流程、检查清单和本地规则 |
| Plugin | 可安装的能力包，可能包含 skills、命令、MCP、hooks 或资源 |
| MCP | 让 AI 安全连接外部数据和操作，例如文档、代码托管或项目管理系统 |

## 公开前检查

公开 skill 时删除公司名、主机、账号、私有路径、token、真实配置和生产日志。保留通用流程、示例占位符、验证和风险说明。

可参考：

- [公开文档审核 Skill](public-docs-review.md)
- [工作经验沉淀 Skill](work-experience-pages.md)
