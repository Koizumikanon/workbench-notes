# 站点架构

```text
Markdown docs
  -> public audit script
  -> MkDocs Material build
  -> GitHub Actions
  -> GitHub Pages
```

源码在 `docs/`，站点配置在 `mkdocs.yml`。GitHub Actions 会先运行公开审核脚本，再构建静态 HTML 并部署到 Pages。

private source workspace 通过 Git subtree 仅导出本站目录到 public repository。源工作区其余目录不会进入公开仓库。
