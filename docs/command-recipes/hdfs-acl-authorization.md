# Kerberos HDFS ACL 批量授权

> 最后更新：2026-07-12 | 类型：场景配方
>
> 关键词：`HDFS`、`Kerberos`、`ACL`、`setfacl`、`permissions`
>
> 验证状态：核心鉴权与 ACL 授权流程已在实际工作中多次执行

适用场景：HDFS 目录所有者或需求负责人明确批准后，为一个或多个用户递归增加现有目录权限，并通过默认 ACL 让以后新建的文件和子目录继承权限。

## 0. 快速执行

公开示例只配置两个用户。实际执行时可以按相同格式继续追加，但必须先核对完整人员名单、目标路径和权限范围。

替换以下占位符：

- `<hadoop-home>`：鉴权 HDFS 客户端目录
- `<admin-principal>`：有权修改目标 ACL 的 Kerberos principal
- `<target-path>`：需要授权的 HDFS 目录
- `<user-a>`、`<user-b>`：需要授权的用户
- `<existing-child>`：目标目录中用于抽查的现有文件或子目录

先整段复制环境和只读检查：

```bash
# 使用明确的鉴权客户端，避免误连其他 HDFS 命名空间
export HADOOP_HOME='<hadoop-home>'
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"

# 获取 Kerberos 票据并确认身份、有效期
kinit '<admin-principal>'
klist

# 设置目标路径
export TARGET_PATH='<target-path>'

# 确认目标是目录，并查看普通权限和现有 ACL
"$HADOOP_HOME/bin/hdfs" dfs -test -d "$TARGET_PATH" \
  && echo "目标目录存在：$TARGET_PATH"
"$HADOOP_HOME/bin/hdfs" dfs -ls -d "$TARGET_PATH"
"$HADOOP_HOME/bin/hdfs" dfs -getfacl "$TARGET_PATH"
```

确认 Kerberos 身份、HDFS 命名空间、目标目录和授权名单后，再整段复制写操作：

```bash
# 现有目录、文件递归增加访问 ACL
export ACCESS_ACL='user:<user-a>:rwx,user:<user-b>:rwx'
"$HADOOP_HOME/bin/hdfs" dfs -setfacl -R -m \
  "$ACCESS_ACL" \
  "$TARGET_PATH"

# 目标目录增加默认 ACL，让以后新建内容继承权限
export DEFAULT_ACL='default:user:<user-a>:rwx,default:user:<user-b>:rwx'
"$HADOOP_HOME/bin/hdfs" dfs -setfacl -m \
  "$DEFAULT_ACL" \
  "$TARGET_PATH"
```

最后整段复制验证：

```bash
# 验证目标目录
"$HADOOP_HOME/bin/hdfs" dfs -ls -d "$TARGET_PATH"
"$HADOOP_HOME/bin/hdfs" dfs -getfacl "$TARGET_PATH"

# 抽查一个已经存在的文件或子目录
export SAMPLE_CHILD="$TARGET_PATH/<existing-child>"
"$HADOOP_HOME/bin/hdfs" dfs -getfacl "$SAMPLE_CHILD"

unset ACCESS_ACL DEFAULT_ACL SAMPLE_CHILD TARGET_PATH
```

!!! danger "递归写操作"

    `-setfacl -R` 会修改目标树中大量现有文件和目录。执行前必须确认目标路径没有复制错误，并获得目录所有者或需求负责人的明确授权。先检查再写入，禁止根据相似目录名猜测。

## 1. 确认授权范围

执行前至少确认以下信息：

- 需求方是否为目录所有者，或已获得所有者批准。
- 目标是单个目录、整个目录树，还是仅以后新建的内容。
- 每个用户需要 `r`、`rw` 还是 `rwx`。
- 是否允许修改 owner；ACL 授权和 owner 变更是两项不同操作。
- 目标目录位于哪个 HDFS 命名空间，应使用哪套鉴权客户端配置。

多人授权时，把最终名单整理为一行并再次与需求方确认。不要直接从聊天记录复制未经核对的旧名单。

HDFS 对单个对象的 ACL 条目数量有限制：访问 ACL 最多 32 条，默认 ACL 最多 32 条。人员较多时应先统计现有条目，避免执行到一半才因数量上限失败。

## 2. 进入正确的鉴权环境

```bash
export HADOOP_HOME='<hadoop-home>'
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"

"$HADOOP_HOME/bin/hdfs" version
"$HADOOP_HOME/bin/hdfs" getconf -confKey fs.defaultFS
"$HADOOP_HOME/bin/hdfs" getconf -confKey hadoop.security.authentication
```

显式调用 `"$HADOOP_HOME/bin/hdfs"`，可以避免当前 `PATH` 中存在另一套 Hadoop 客户端时误连错误命名空间。

## 3. 获取并检查 Kerberos 票据

```bash
kinit '<admin-principal>'
klist
```

检查 `Default principal`、票据有效期和 realm。不要因为 `kinit` 没报错，就跳过 `klist` 身份确认。

## 4. 检查目标路径

```bash
export TARGET_PATH='<target-path>'

"$HADOOP_HOME/bin/hdfs" dfs -test -d "$TARGET_PATH" \
  && echo "目标目录存在：$TARGET_PATH"
"$HADOOP_HOME/bin/hdfs" dfs -ls -d "$TARGET_PATH"
"$HADOOP_HOME/bin/hdfs" dfs -getfacl "$TARGET_PATH"
```

如果需要确认父目录和用户目录，逐级读取，不要直接开始递归授权：

```bash
"$HADOOP_HOME/bin/hdfs" dfs -ls <parent-path>
"$HADOOP_HOME/bin/hdfs" dfs -ls <user-home-path>
"$HADOOP_HOME/bin/hdfs" dfs -ls -d "$TARGET_PATH"
```

记录修改前的 owner、group、普通权限、访问 ACL、默认 ACL 和 `mask`。目录很大时不要盲目执行全树 `getfacl -R`，应先评估输出规模和保存位置。

## 5. 为现有内容递归增加 ACL

两个用户的示例：

```bash
export ACCESS_ACL='user:<user-a>:rwx,user:<user-b>:rwx'

"$HADOOP_HOME/bin/hdfs" dfs -setfacl -R -m \
  "$ACCESS_ACL" \
  "$TARGET_PATH"
```

需要增加更多用户时，在同一个 ACL 规格中继续追加：

```text
user:<user-a>:rwx,user:<user-b>:rwx,user:<user-c>:rwx
```

`-R` 会递归修改已有目录和文件。对大型目录树，应提前评估对象数量、执行时间和 NameNode 压力，并在变更窗口内执行。

## 6. 设置以后新建内容的继承权限

```bash
export DEFAULT_ACL='default:user:<user-a>:rwx,default:user:<user-b>:rwx'

"$HADOOP_HOME/bin/hdfs" dfs -setfacl -m \
  "$DEFAULT_ACL" \
  "$TARGET_PATH"
```

访问 ACL 与默认 ACL 的作用不同：

| 类型 | 作用 |
| --- | --- |
| `user:<user>:rwx` | 控制用户对当前对象的访问权限 |
| `default:user:<user>:rwx` | 只用于目录，控制以后新建内容继承的 ACL |

只递归设置访问 ACL，不会自动保证未来新建内容继续继承；只设置默认 ACL，也不会补齐已经存在的历史文件和目录。

默认 ACL 在创建子项时复制。新建子目录还会继续继承默认 ACL；新建文件或目录的最终有效权限仍可能被创建 mode 过滤，因此新文件不一定保留 `x`，必须通过实际新建内容验证。

## 7. 检查 ACL mask 和有效权限

```bash
"$HADOOP_HOME/bin/hdfs" dfs -getfacl "$TARGET_PATH"
```

重点检查：

- 目标用户条目是否存在。
- `mask::` 是否允许预期权限。
- 输出中是否出现 `effective:`，且有效权限是否被 mask 限制。
- 目标目录是否同时存在访问 ACL 和默认 ACL。

命名用户即使显示为 `rwx`，最终有效权限仍可能被 ACL mask 限制，不能只看用户条目本身。

## 8. 抽查现有内容和继承结果

抽查一个已经存在的文件或子目录：

```bash
export SAMPLE_CHILD="$TARGET_PATH/<existing-child>"
"$HADOOP_HOME/bin/hdfs" dfs -getfacl "$SAMPLE_CHILD"
```

如果变更窗口允许，由目录所有者或获授权用户创建测试子目录，再检查继承结果。不要为了验证在生产目录随意创建无归属文件。

验证至少满足：

- 目标目录包含两个用户的访问 ACL。
- 现有子目录或文件已经获得递归 ACL。
- 目标目录包含两个用户的默认 ACL。
- 新建内容能够继承预期 ACL。
- 获授权用户可以完成需求中明确批准的读、写或进入目录操作。

## 9. 可选 owner 变更

`chown` 会改变目录树所有权，不属于普通 ACL 授权。只有需求明确要求并单独确认影响后才执行：

```bash
"$HADOOP_HOME/bin/hdfs" dfs -chown -R \
  <new-owner>:<new-group> \
  "$TARGET_PATH"
```

如果只需要更换 owner、不修改 group：

```bash
"$HADOOP_HOME/bin/hdfs" dfs -chown -R \
  <new-owner> \
  "$TARGET_PATH"
```

执行前记录旧 owner 和 group。不要为了“确保用户能访问”而顺手改变所有权，ACL 已经能够表达多人访问需求。

## 10. 回滚新增 ACL

只有确认这些 ACL 条目是本次新加、此前不存在时，才能按下面方式移除：

```bash
export ACCESS_REMOVE='user:<user-a>,user:<user-b>'
export DEFAULT_REMOVE='default:user:<user-a>,default:user:<user-b>'

# 移除现有目录树上的指定访问 ACL
"$HADOOP_HOME/bin/hdfs" dfs -setfacl -R -x \
  "$ACCESS_REMOVE" \
  "$TARGET_PATH"

# 移除目标目录上的指定默认 ACL
"$HADOOP_HOME/bin/hdfs" dfs -setfacl -x \
  "$DEFAULT_REMOVE" \
  "$TARGET_PATH"
```

如果用户在变更前已经拥有 ACL，不能直接使用上述删除命令；应根据修改前记录逐项恢复。owner 变更也必须使用已记录的旧 owner 和 group 单独回滚。

## 11. 安全与记录

- 不公开真实 principal、用户名、HDFS 路径、Hadoop 安装目录或内部命名空间。
- Kerberos ticket cache 属于认证材料，不要复制或上传。
- 记录需求方、目录所有者确认、授权名单、目标路径、权限范围、是否递归、是否设置默认 ACL 和验证结果。
- 大规模递归 ACL 变更应记录开始和结束时间、异常输出以及抽查结果。
- 不要把 `chown`、删除 ACL 或其他回滚命令放进默认快速执行区。
