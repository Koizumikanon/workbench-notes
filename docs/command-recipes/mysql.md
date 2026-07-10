# MySQL 命令

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

!!! warning "Host 范围"

    `'%'` 允许任意来源连接。能确定来源时，使用更严格的 host 值或网络策略。
