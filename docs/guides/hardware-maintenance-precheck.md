# 硬件维护前的系统预检

> 最后更新：2026-07-11 | 类型：维护指南
>
> 关键词：`hardware`、`maintenance`、`precheck`、`systems`
>
> 经验标签：`FT`

硬件维护不是“确认能关机”这么简单。关机、更换网卡、调整磁盘或移动设备前，需要建立可验证的前后状态，避免影响正在运行的任务、存储服务或网络路径。

本文使用泛化示例。执行前请根据实际设备、服务依赖和变更窗口补全检查项。

## 维护前的四类检查

### 1. 工作负载与使用人

先检查调度系统任务，再检查本机用户进程。调度队列为空不代表机器没人使用，手工任务、容器、终端会话和后台服务都可能仍在运行。

```bash
hostname
date
who
ps -eo user,pid,ppid,stat,pcpu,pmem,etime,comm,args --sort=-pcpu | head -80
```

如果存在活跃用户进程，先通知使用人并明确维护窗口。不要把“没有调度任务”当作关机许可。

### 2. 磁盘与挂载

维护前记录设备名、序列号、挂载点、文件系统和 UUID。现场拆盘必须以序列号、槽位和挂载关系为准，不能只依赖 `/dev/sdX`。

```bash
lsblk -e7 -o NAME,KNAME,TYPE,SIZE,MODEL,SERIAL,ROTA,TRAN,MOUNTPOINTS,FSTYPE,LABEL,UUID
findmnt -rn -o TARGET,SOURCE,FSTYPE,OPTIONS,UUID | sort
```

特别要区分系统盘、RAID 成员盘、业务数据盘、临时数据盘和分布式存储数据盘。

### 3. 服务角色与依赖

确认机器在集群中的角色，例如调度节点、存储节点、日志仲裁节点、数据库副本或普通计算节点。任何高可用组件都要确认维护期间仍满足多数派或副本数量要求。

```bash
pgrep -af 'service-a|service-b|scheduler|storage-daemon' || true
ss -ltn
systemctl --failed
```

不要在不了解角色的情况下临时停止服务。写操作应当单独获得授权，并记录回滚方案。

### 4. 网络与回连路径

更换网卡或调整网络配置前，保存当前接口、地址、路由和配置文件。应用网络变更前，要确认现场控制台、BMC 或备用网络路径可用。

```bash
ip -br link
ip -br address
ip route show
```

维护后至少从独立跳板路径回连一次，验证网络、DNS、关键端口和服务恢复。

需要调整带外管理网络或账号时，参考[使用 ipmitool 配置 BMC 网络与用户](../command-recipes/ipmitool-bmc-configuration.md)，并确保修改前已有现场控制台或其他可靠回连路径。

## 开机后的恢复门槛

开机并不等于维护结束。先保持调度节点处于维护状态，按下面顺序确认恢复结果：

1. 确认磁盘、RAID、地址、路由、网关和 DNS。
2. 确认容器运行时、认证服务、角色服务和关键端口。
3. 确认监控和消息服务的实际进程；同一个端口被其他服务监听不能作为恢复证据。
4. 完成角色专项检查，再恢复调度或业务流量。

```bash
findmnt -rn -o TARGET,SOURCE,FSTYPE,OPTIONS | sort
cat /proc/mdstat
ip -br address
ip route show
systemctl is-active <container-runtime> <scheduler-agent> <auth-service>
ss -ltnp
pgrep -af '<monitor-process>|<message-process>' || true
```

如果永久拆除了磁盘，也检查 boot-time 挂载来源。除了 `/etc/fstab`，还可能有 cron、systemd mount unit 或应用启动脚本。

```bash
findmnt --verify --verbose
sudo crontab -l
systemctl list-unit-files --type=mount
```

## 网络迁移

不要根据旧接口名推断新网卡。先通过驱动、PCI 总线、MAC、链路和速率识别目标接口，再迁移地址。

```bash
ip -br link
ip -br address
lspci -nnk | grep -A3 -Ei 'ethernet|network'
ethtool -i <new-interface>
ethtool <new-interface> | grep -E 'Speed:|Link detected:'
```

保存旧配置后，在控制台或备用回连路径上应用变更。保留非目标网段；若存在多个默认路由，为每条路由设置明确 metric。

```bash
sudo netplan generate
sudo netplan try --timeout 120
ip route show
ping -c 3 -I <new-interface> <gateway>
```

## 角色专项检查

### 仲裁或日志 quorum

维护一个成员前，确认其余成员仍满足多数派。恢复后验证本机进程、监听端口和上层 HA 状态。落后成员从健康成员同步日志是常见恢复行为；出现错误退出才应停止恢复流程。

### 调度计算节点

调度 agent 可能在网络或控制端尚不可达时启动失败。网络恢复后，在节点仍处于维护状态时重新启动 agent，并确认其已向控制端注册。

如果节点被标记为资源注册无效，比较本机硬件上报和控制端节点定义：

```bash
<scheduler-agent> -C
<scheduler-controller> show node <node>
```

修正控制端的单节点资源定义并按批准流程刷新配置；不要修改本机缓存或全局放宽资源校验。

### 数据库主备

在主库查询写入状态，在备库查询复制状态。主库上没有复制上游时，复制状态为空通常正常。

```sql
-- source
SHOW MASTER STATUS;

-- replica
SHOW REPLICA STATUS;
```

备库的 IO/SQL 复制线程应运行、延迟可接受且没有复制错误。凭据只在受控交互会话中输入。

## 推荐维护流程

1. 通知维护窗口、影响范围和中断边界。
2. 保存只读快照：作业、用户进程、磁盘、网络、服务状态。
3. 等待或处理已确认可中断的工作负载。
4. 执行经过授权的维护操作。
5. 开机后先验证硬件、挂载、网络和基础服务。
6. 再恢复调度或业务流量。
7. 发布恢复通知，并记录异常和后续事项。

## 应用注意事项

实际执行时，应在变更记录中保存维护对象、服务依赖、当前任务、设备信息、执行时间、验证结果和回滚结论。
