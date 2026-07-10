# 命令手册

> 最后更新：2026-07-10 | 类型：命令索引
>
> 关键词：`commands`、`operations`、`quick-reference`

这里放的是高频、可复制、按场景组织的命令配方。

基础命令按产品拆分：

- [Docker](docker.md)
- [MySQL](mysql.md)
- [Redis](redis.md)
- [Linux](linux.md)
- [Slurm](slurm.md)
- [HDFS](hdfs.md)
- [GitHub CLI](github-cli.md)
- [Prometheus](prometheus.md)
- [ClickHouse](clickhouse.md)

跨工具需求按完整流程拆分：

- [Docker MySQL 数据库与用户初始化](docker-mysql-provisioning.md)

## 使用方式

1. 先确认操作对象和权限。
2. 把尖括号中的占位符替换为实际值。
3. 先执行检查命令，再执行写操作。
4. 写操作完成后执行验证命令，并记录结果。

!!! tip "场景配方优先"

    如果需求需要连续跨越 Docker、数据库和权限三个步骤，优先看“场景配方”，不要分别拼凑零散命令。
