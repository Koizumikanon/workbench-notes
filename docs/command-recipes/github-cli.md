# GitHub CLI 命令

## 登录与身份

```bash
gh --version
gh auth login
gh auth status
gh api user --jq '.login'
```

`gh auth login` 会打开浏览器或要求粘贴一次性授权信息。不要把 token 写进 shell 历史、脚本或文档。

## 仓库

```bash
gh repo view <owner>/<repo>
gh repo clone <owner>/<repo>
gh repo create <repo> --private
gh repo create <repo> --public
```

在当前 Git 仓库中可以省略 `<owner>/<repo>`：

```bash
gh repo view
gh repo sync
```

## Issue 与 Pull Request

```bash
gh issue list --repo <owner>/<repo>
gh issue view <issue-number> --repo <owner>/<repo>
gh pr list --repo <owner>/<repo>
gh pr view <pr-number> --repo <owner>/<repo>
gh pr checks <pr-number> --repo <owner>/<repo>
```

创建前先检查内容，再执行：

```bash
gh issue create --repo <owner>/<repo> --title '<title>' --body '<body>'
gh pr create --repo <owner>/<repo> --title '<title>' --body '<body>'
```

## Actions 与 Pages

```bash
gh run list --repo <owner>/<repo> --limit 10
gh run view <run-id> --repo <owner>/<repo>
gh run watch <run-id> --repo <owner>/<repo> --exit-status
gh api repos/<owner>/<repo>/pages
```

查看失败日志：

```bash
gh run view <run-id> --repo <owner>/<repo> --log-failed
```

## SSH Key

```bash
gh ssh-key list
gh ssh-key add ~/.ssh/<public-key-file>.pub --title '<device-name>'
```

!!! warning "公开性与变更"

    创建 public 仓库、提交 Issue/PR、添加 SSH key、重跑或取消 Actions 都会改变远端状态。上传的必须是公钥，绝不能是私钥。
