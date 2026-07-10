# Redis 命令

## 登录与连通性

本机或远端 Redis：

```bash
redis-cli -h <host> -p <port> ping
redis-cli -h <host> -p <port> -a '<password>' ping
```

容器内 Redis：

```bash
docker exec -it <redis-container> redis-cli ping
```

## 基础检查

```bash
redis-cli info server
redis-cli info memory
redis-cli info replication
redis-cli dbsize
redis-cli slowlog get 20
```

## Key 查询

开发或小数据量环境可以：

```bash
redis-cli --scan --pattern 'prefix:*'
```

生产或大数据量环境避免 `KEYS *`；优先 `SCAN`：

```bash
redis-cli --scan --pattern 'prefix:*' | head -100
```

## 常用读写

```bash
redis-cli get <key>
redis-cli ttl <key>
redis-cli type <key>
redis-cli hgetall <hash-key>
redis-cli lrange <list-key> 0 -1
```

!!! warning "写操作"

    `DEL`、`FLUSHDB`、`FLUSHALL`、`CONFIG SET` 和 `ACL SETUSER` 都会影响数据或服务行为。先确认实例、库编号和影响范围。
