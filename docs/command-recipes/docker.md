# Docker 命令

> 最后更新：2026-07-10 | 类型：命令速查
>
> 关键词：`docker`、`container`、`compose`、`logs`

## 查找容器

```bash
docker ps
docker ps -a
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
```

按名称过滤：

```bash
docker ps --filter 'name=<container-name>'
docker ps --format '{{.Names}}' | rg '<keyword>'
```

## 查看日志与状态

```bash
docker logs --tail 200 <container-name>
docker logs -f --tail 100 <container-name>
docker inspect <container-name>
docker inspect -f '{{.State.Status}} {{.State.Health.Status}}' <container-name>
```

## 进入容器

优先尝试 bash：

```bash
docker exec -it <container-name> bash
```

精简镜像没有 bash 时使用 sh：

```bash
docker exec -it <container-name> sh
```

执行单条命令，不进入交互 shell：

```bash
docker exec <container-name> env
docker exec <container-name> ls -la /
```

## Compose 服务

在包含 `docker-compose.yml` 或 `compose.yml` 的目录中：

```bash
docker compose ps
docker compose logs --tail 200 <service-name>
docker compose exec <service-name> sh
docker compose config
```

!!! warning "写操作"

    `docker compose up`、`down`、`restart`、`pull`、`rm` 和 `system prune` 会改变运行状态。先确认影响范围和回滚方式。
