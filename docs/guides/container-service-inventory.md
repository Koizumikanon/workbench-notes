# 容器服务盘点与交接

> 最后更新：2026-07-10 | 类型：运维指南
>
> 关键词：`docker`、`inventory`、`containers`、`handoff`

## 盘点目标

先记录容器的名称、镜像、状态、端口、网络、挂载和启动方式，再判断服务类型。镜像名和容器名只能帮助分类，不能证明服务可以重启或删除。

## 最小只读盘点

```bash
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}'
docker inspect <container-name>
docker inspect -f '{{.HostConfig.NetworkMode}}' <container-name>
docker inspect -f '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' <container-name>
```

## 目录与端口交叉核验

```bash
ss -lntp
find <service-root> -maxdepth 2 -type f \( -name 'compose.yml' -o -name 'docker-compose.yml' -o -name '*control*.sh' \) -print
docker compose -f <compose-file> config
```

常见线索：

- 数据库、缓存、消息队列通常需要同时记录数据卷和监听端口。
- `cron`、`worker`、`scheduler` 等名称提示后台任务，但仍要看实际启动方式。
- host 网络意味着服务端口直接监听在宿主机，不能只依赖 Docker 的端口展示。

## 交接记录

```text
容器：
镜像与版本：
运行状态：
网络与端口：
数据/配置挂载：
启动方式：Compose / systemd / 脚本 / 其他
服务 owner：
只读验证结果：
变更与回滚入口：
```

!!! warning "敏感配置"

    `.env`、密码文件、Webhook、数据库数据和业务日志不属于常规盘点内容。除非获得明确授权，不要读取或复制它们。
