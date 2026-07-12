# Docker MySQL：创建数据库、用户并授权

> 最后更新：2026-07-12 | 类型：场景配方
>
> 关键词：`docker`、`mysql`、`database`、`privileges`

适用场景：需求方需要在 Docker 容器运行的 MySQL 中，为应用创建一个数据库和独立用户。

## 0. 快速执行

先把以下占位符全部替换成实际值：

- `<mysql-container>`：MySQL 容器名称
- `<admin-user>`：MySQL 管理员用户
- `<database-name>`：需要创建的数据库名称
- `<database-user>`：需要创建或复用的数据库用户
- `<strong-password>`：从密码管理器生成的随机密码
- `%`：允许连接的来源；能限制时应改成更严格的 host

先复制下面这段，确认容器后登录 MySQL：

```bash
# 确认容器名称、状态和端口映射
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

# 登录容器中的 MySQL，密码通过交互提示输入
docker exec -it <mysql-container> mysql -u <admin-user> -p
```

登录成功后，整段复制下面的 SQL：

```sql
-- 检查用户是否已经存在
SELECT User, Host
FROM mysql.user
WHERE User = '<database-user>';

-- 用户不存在时创建；已经存在时跳过，不修改原密码
CREATE USER IF NOT EXISTS '<database-user>'@'%'
IDENTIFIED BY '<strong-password>';

-- 检查数据库是否已经存在
SELECT SCHEMA_NAME
FROM INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME = '<database-name>';

-- 数据库不存在时创建
CREATE DATABASE IF NOT EXISTS `<database-name>`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- 授予该用户目标数据库的全部权限
GRANT ALL PRIVILEGES
ON `<database-name>`.*
TO '<database-user>'@'%';

-- 验证数据库和授权结果
SHOW CREATE DATABASE `<database-name>`;
SHOW GRANTS FOR '<database-user>'@'%';

EXIT;
```

最后使用新用户登录验证：

```bash
docker exec -it <mysql-container> mysql \
  -u <database-user> \
  -p \
  -D <database-name> \
  -e 'SELECT DATABASE(), CURRENT_USER(), NOW();'
```

!!! warning "执行前检查"

    快速执行区包含创建用户、创建数据库和授权等写操作。执行前必须确认容器、数据库名、用户名和允许来源已经全部替换，避免把旧需求中的名称复制到新环境。

## 1. 确认容器

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
docker logs --tail 100 <mysql-container>
```

确认容器运行正常后，再进入 MySQL。

## 2. 登录 MySQL

```bash
docker exec -it <mysql-container> mysql -u <admin-user> -p
```

如果客户端需要指定容器内端口：

```bash
docker exec -it <mysql-container> mysql \
  -u <admin-user> \
  -h 127.0.0.1 \
  -P <mysql-internal-port> \
  -p
```

主机映射端口不一定等于容器内 MySQL 的监听端口。只有确认容器内部确实使用特殊端口时，才增加 `-P`。

## 3. 检查现有用户和数据库

```sql
SELECT User, Host
FROM mysql.user
WHERE User = '<database-user>';

SELECT SCHEMA_NAME
FROM INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME = '<database-name>';
```

同名用户可能存在多个 Host 记录，例如 `localhost`、某个网段和 `%`。授权前必须确认应用实际使用哪一条用户记录。

## 4. 创建用户、数据库并授权

把以下占位符替换成实际值：

- `<database-name>`：数据库名
- `<database-user>`：应用用户名
- `<strong-password>`：从密码管理器生成的随机密码
- `%`：允许来源；能限制时改为更严格的 host

```sql
CREATE USER IF NOT EXISTS '<database-user>'@'%'
  IDENTIFIED BY '<strong-password>';

CREATE DATABASE IF NOT EXISTS `<database-name>`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

GRANT ALL PRIVILEGES
ON `<database-name>`.*
TO '<database-user>'@'%';
```

`CREATE USER IF NOT EXISTS` 会在用户已经存在时跳过创建，不会修改已有密码。只有明确需要重置密码时才执行：

```sql
ALTER USER '<database-user>'@'%'
  IDENTIFIED BY '<new-strong-password>';
```

使用 `CREATE USER` 和 `GRANT` 后权限会立即生效，通常不需要额外执行 `FLUSH PRIVILEGES`。

## 5. 验证

仍在 MySQL 交互界面中执行：

```sql
SHOW CREATE DATABASE `<database-name>`;
SHOW GRANTS FOR '<database-user>'@'%';

SELECT User, Host
FROM mysql.user
WHERE User = '<database-user>';
```

退出 MySQL：

```sql
exit
```

## 6. 使用新用户测试

```bash
docker exec -it <mysql-container> mysql \
  -u <database-user> \
  -p \
  -D <database-name> \
  -e 'SELECT DATABASE(), CURRENT_USER(), NOW();'
```

验证结果应满足：

- 命令能够使用新用户成功登录。
- `DATABASE()` 返回目标数据库。
- `CURRENT_USER()` 返回预期的用户和 Host 范围。

## 7. 回滚

以下命令会撤销权限或删除数据，只能在明确确认需要回滚时执行。

```sql
REVOKE ALL PRIVILEGES
ON `<database-name>`.*
FROM '<database-user>'@'%';

DROP DATABASE IF EXISTS `<database-name>`;
DROP USER IF EXISTS '<database-user>'@'%';
```

如果用户还被其他数据库或应用使用，不要执行 `DROP USER`。回滚前先使用 `SHOW GRANTS` 检查其全部权限。

## 8. 安全与记录

- 不要把真实密码写进命令历史、脚本、文档或聊天记录。
- `'<database-user>'@'%'` 允许从任意来源连接；能够确定应用来源时，应限制为具体地址或网段。
- 不要直接复用旧需求中的数据库名、用户名和端口，每次执行前逐项核对。
- 不要因为用户已经存在就自动执行 `ALTER USER`，否则可能中断正在使用该账号的程序。

完成后记录数据库名、用户名、授权范围、密码保存位置、执行时间和验证结果。不要把密码写进命令历史、shell 脚本或聊天记录。
