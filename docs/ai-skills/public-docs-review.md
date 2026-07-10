# 公开文档审核 Skill

> 最后更新：2026-07-10 | 类型：公开 Skill 模板
>
> 关键词：`ai`、`skills`、`security`、`documentation`

下面是一个可复制后按团队规则调整的通用 `SKILL.md`。它只描述审核方法，不包含任何内部环境。

````markdown
---
name: public-docs-review
description: Review Markdown, runbooks, screenshots, and technical articles before publishing them to a public repository or documentation site. Use when a user asks to publish, export, share, deploy Pages, or assess whether internal material may be public.
---

# Public Documentation Review

1. Read the document and all linked configuration snippets, images, logs, and URLs.
2. Classify it as public, publishable after sanitization, or private only.
3. Remove credentials, keys, tokens, passwords, internal addresses, account names, host names, customer data, production logs, and current operational state.
4. Replace details with role names and safe placeholders such as `<host>`, `<user>`, and `192.0.2.10`.
5. Run an automated scan, then do a human review. A scan alone is not enough.
6. Keep the public page concise: commands, prerequisites, verification, and warnings.
7. Publish only after the reviewer and owner approve the result.
````

发布时还应为页面添加最后更新、类型和关键词，方便后续搜索与维护。
