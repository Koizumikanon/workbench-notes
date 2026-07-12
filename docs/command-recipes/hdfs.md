# HDFS 命令

> 最后更新：2026-07-12 | 类型：命令速查
>
> 关键词：`hdfs`、`hadoop`、`storage`、`kerberos`
>
> 经验标签：`FT`

## 客户端与认证

```bash
hdfs version
hdfs getconf -confKey fs.defaultFS
hdfs getconf -confKey hadoop.security.authentication
klist
kinit <principal>
```

需要指定配置目录时：

```bash
export HADOOP_CONF_DIR=<hadoop-conf-dir>
hdfs dfs -ls /
```

## 文件与目录查询

```bash
hdfs dfs -ls /
hdfs dfs -ls -h <path>
hdfs dfs -du -h <path>
hdfs dfs -count -h <path>
hdfs dfs -find <path> -maxdepth 2 -type f | head -100
hdfs dfs -stat '%n %b %r %o' <path>
```

## 读取文件

```bash
hdfs dfs -cat <path>
hdfs dfs -cat <path> | head -100
hdfs dfs -text <path> | head -100
hdfs dfs -get <hdfs-path> <local-path>
hdfs dfs -getmerge <hdfs-directory> <local-file>
```

## 上传与目录创建

```bash
hdfs dfs -mkdir -p <path>
hdfs dfs -put <local-file> <hdfs-directory>/
hdfs dfs -copyFromLocal <local-file> <hdfs-directory>/
hdfs dfs -cp <source-path> <target-path>
```

## 权限与副本

```bash
hdfs dfs -ls -d <path>
hdfs dfs -chmod <mode> <path>
hdfs dfs -chown <owner>:<group> <path>
hdfs dfs -setrep -w <replication> <path>
```

## ACL 权限

```bash
hdfs dfs -getfacl <path>
hdfs dfs -setfacl -m user:<user>:rwx <path>
hdfs dfs -setfacl -m default:user:<user>:rwx <directory>
```

需要通过 Kerberos 管理员身份为多个用户递归授权，并让以后新建内容继承权限时，使用完整场景配方：[Kerberos HDFS ACL 批量授权](hdfs-acl-authorization.md)。

## 集群只读状态

```bash
hdfs dfsadmin -report
hdfs haadmin -ns <nameservice> -getAllServiceState
hdfs getconf -confKey dfs.nameservices
```

!!! warning "写操作"

    `-mkdir`、`-put`、`-cp`、`-chmod`、`-chown`、`-setfacl`、`-setrep`、`-rm` 和 `-rm -r` 会改变 HDFS。确认路径、命名空间、权限和配额后再执行。
