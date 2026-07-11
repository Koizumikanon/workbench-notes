# MySQL 命令

> 最后更新：2026-07-11 | 类型：命令速查
>
> 关键词：`mysql`、`database`、`user`、`privileges`

## 登录

本机 MySQL：

```bash
mysql -h <host> -P <port> -u <user> -p
```

容器内 MySQL：

```bash
docker exec -it <mysql-container> mysql -u <user> -p
```

## 查看状态

```sql
SELECT VERSION();
SHOW DATABASES;
SELECT User, Host FROM mysql.user ORDER BY User, Host;
SHOW GRANTS FOR 'app_user'@'%';
```

## 数据库与用户

```sql
CREATE DATABASE IF NOT EXISTS `app_db`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'app_user'@'%' IDENTIFIED BY '<strong-password>';
GRANT ALL PRIVILEGES ON `app_db`.* TO 'app_user'@'%';
FLUSH PRIVILEGES;
```

## 验证

```sql
SHOW GRANTS FOR 'app_user'@'%';
SELECT User, Host FROM mysql.user WHERE User = 'app_user';
```

## 主从复制检查

在源库和副本库使用拥有复制状态查询权限的账号。不要在未理解拓扑时执行 `START REPLICA`、`STOP REPLICA` 或变更复制源。

```sql
-- source database
SHOW MASTER STATUS\G

-- replica database
SHOW REPLICA STATUS\G
```

副本库重点检查以下字段：

```text
Replica_IO_Running: Yes
Replica_SQL_Running: Yes
Seconds_Behind_Source: <acceptable value>
Last_IO_Error:
Last_SQL_Error:
```

旧版本可能使用 `Slave_IO_Running` 和 `Slave_SQL_Running`。在源库上执行 `SHOW REPLICA STATUS` 返回空集合通常正常，因为源库未必从其他实例复制。

!!! warning "Host 范围"

    `'%'` 允许任意来源连接。能确定来源时，使用更严格的 host 值或网络策略。
