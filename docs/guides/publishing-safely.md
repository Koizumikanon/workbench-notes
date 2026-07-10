# 公开技术文档前的审核

公开技术文档的价值在于分享方法，而不是暴露环境。发布前至少做两层审核。

## 第一层：自动扫描

站点仓库提供：

```bash
scripts/audit-public-docs.sh docs
```

它会拦截常见的私钥、公钥、token、密码赋值和 RFC1918 内网 IP。扫描通过不代表文档一定安全。

## 第二层：人工审核

发布前逐项确认：

- 没有真实公司名、客户名、项目代号。
- 没有真实主机名、域名、账号、邮箱、工号。
- 没有内网 IP、跳板路径、SSH config、VPN 信息。
- 没有命令输出、截图或日志里的业务数据。
- 没有凭据、key、token、密码、授权链接。
- 没有正在进行的维护时间、生产容量、服务拓扑或故障细节。

## 可公开与不可公开的写法

可公开：

```text
通过标准 SSH ProxyJump 进入内网目标机。
在维护前检查作业调度、用户进程、磁盘挂载和网络配置。
```

不可公开：

```text
ssh user@real-host.example.internal
Host production-jump
  HostName 172.16.x.x
```

## 安全的替换方式

| 原始类型 | 公开替换方式 |
|---|---|
| 主机名 | `host-a`、`compute-node-01` |
| 内网 IP | `192.0.2.10`、`198.51.100.20` |
| 用户名 | `operator`、`deploy` |
| 域名 | `bastion.example.com` |
| 业务服务 | `service-a`、`scheduler`、`storage-node` |

!!! warning "不要用前端密码保护代替脱敏"

    静态站点上的 JavaScript 密码框不能保护源码。真正不该公开的内容必须不被部署。
