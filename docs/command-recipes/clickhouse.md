# ClickHouse 命令

> 最后更新：2026-07-10 | 类型：命令速查
>
> 关键词：`clickhouse`、`database`、`sql`、`container`

## 连接

本机客户端：

```bash
clickhouse-client --host <host> --port <native-port> --user <user> --password
```

容器内客户端：

```bash
docker exec -it <clickhouse-container> clickhouse-client --user <user> --password
```

HTTP 查询：

```bash
curl -u '<user>:<password>' \
  --data-binary 'SELECT version()' \
  http://<host>:<http-port>/
```

## 服务与端口

ClickHouse 常同时提供 native、HTTP 和 MySQL-compatible 协议。不要把 HTTP 或 MySQL-compatible 端口传给 `clickhouse-client`；先查看实际配置或监听状态。

```bash
docker ps --filter 'name=<clickhouse-container>'
ss -lntp | rg ':(<native-port>|<http-port>|<mysql-port>)\b'
docker exec <clickhouse-container> clickhouse-client --query 'SELECT version()'
```

## 常用只读 SQL

```sql
SELECT version();
SHOW DATABASES;
SHOW TABLES FROM <database>;
SHOW CREATE TABLE <database>.<table>;
SELECT name, engine, total_rows, total_bytes
FROM system.tables
WHERE database = '<database>';
```

查看用户与授权：

```sql
SHOW USERS;
SHOW GRANTS FOR <user>;
```

## 创建数据库与用户

```sql
CREATE DATABASE IF NOT EXISTS <database>;
CREATE USER IF NOT EXISTS <user> IDENTIFIED BY '<strong-password>';
GRANT SELECT, INSERT ON <database>.* TO <user>;
SHOW GRANTS FOR <user>;
```

!!! warning "权限与数据"

    用户、授权、`DROP`、`ALTER`、分区操作和集群级 DDL 都可能影响数据或业务。先确认实例、数据库、集群作用域和回滚方案。
