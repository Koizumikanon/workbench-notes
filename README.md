# workbench-notes

## 用途

`workbench-notes` 是公开的技术笔记站点源码，使用 MkDocs Material 构建并通过 GitHub Actions 发布到 GitHub Pages。

这个目录可以在私有源工作区中维护，再通过 Git subtree 单独导出到 public GitHub repository。公开站只包含经过审核的通用内容，不能引用源工作区中的内部资料。

## 本地预览

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
scripts/audit-public-docs.sh docs
mkdocs serve
```

## 发布路径

公开仓库 remote 名称为 `workbench-notes`。不要把源工作区主分支直接推送到这个 remote；只能导出本站目录：

```bash
git remote add workbench-notes git@github.com:Koizumikanon/workbench-notes.git
git subtree push --prefix=projects/workbench-notes workbench-notes main
```

首次导出后，在公开仓库的 Settings -> Pages 中选择 GitHub Actions。每次 public repository 的 `main` 更新，workflow 会构建并部署站点。

## 审核规则

- 发布前运行 `scripts/audit-public-docs.sh docs`。
- 通用扫描会阻止私钥、公钥、token、常见凭据和 RFC1918 内网 IP。
- 仍需人工检查真实公司名、主机名、域名、账号、架构图、日志和业务上下文。
- 更严格的私有 denylist 可以放在 `.local/`，并作为第二个参数传给审核脚本。
- 每个公开页面开头都写可见的“最后更新、类型、关键词”，方便快速判断内容和检索。
- 已验证的工作需求可先记录到 private `memory/work-experience/`，再按脱敏规则补充现有页面或创建公开草稿；公开推送仍需确认。

## 状态

- 负责人：dev
- 状态：第一版站点骨架
- 创建时间：2026-07-10

## 目录结构

- `spec/`：需求、约束和计划
- `tasks/`：待办事项和执行记录
- `notes/`：工作笔记
- `src/`：源文件
- `tests/`：测试或验证资料
- `docs/`：面向用户或项目的文档
- `artifacts/`：生成产物
- `.local/`：仅本机使用的临时文件
