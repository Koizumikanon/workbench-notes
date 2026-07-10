# 测试

发布前至少运行：

```bash
scripts/audit-public-docs.sh docs
mkdocs build --strict
```

GitHub Actions 会重复执行审核脚本和构建。
