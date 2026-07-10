# Docker MySQL：创建数据库、用户并授权

> 最后更新：2026-07-10 | 类型：场景配方
>
> 关键词：`docker`、`mysql`、`database`、`privileges`

适用场景：需求方需要在 Docker 容器运行的 MySQL 中，为应用创建一个数据库和独立用户。

## 先确认容器

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
docker logs --tail 100 <mysql-container>
```

确认容器运行正常后，再进入 MySQL。

## 登录 MySQL

```bash
docker exec -it <mysql-container> mysql -u <admin-user> -p
```

如果客户端需要指定容器内端口：

```bash
docker exec -it <mysql-container> mysql -u <admin-user> -p -P <mysql-port>
```

## 执行初始化 SQL

把以下占位符替换成实际值：

- `app_db`：数据库名
- `app_user`：应用用户名
- `<strong-password>`：从密码管理器生成的随机密码
- `%`：允许来源；能限制时改为更严格的 host

```sql
CREATE DATABASE IF NOT EXISTS `app_db`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'app_user'@'%' IDENTIFIED BY '<strong-password>';
GRANT ALL PRIVILEGES ON `app_db`.* TO 'app_user'@'%';
FLUSH PRIVILEGES;
```

## 验证

仍在 MySQL 交互界面中执行：

```sql
SHOW DATABASES LIKE 'app_db';
SHOW GRANTS FOR 'app_user'@'%';
SELECT User, Host FROM mysql.user WHERE User = 'app_user';
```

退出 MySQL：

```sql
exit
```

## 用新用户测试

```bash
docker exec -it <mysql-container> mysql -u app_user -p app_db
```

进入后可以执行：

```sql
SELECT DATABASE();
SHOW TABLES;
```

## 变更记录

完成后记录数据库名、用户名、授权范围、密码保存位置、执行时间和验证结果。不要把密码写进命令历史、shell 脚本或聊天记录。
