# Slurm 命令

> 最后更新：2026-07-11 | 类型：命令速查
>
> 关键词：`slurm`、`scheduler`、`jobs`、`cluster`
>
> 经验标签：`FT`

## 分区与节点

```bash
sinfo
sinfo -o '%P %a %l %D %t %N'
sinfo -p <partition>
scontrol show partition <partition>
scontrol show node <node>
```

## 队列与作业

```bash
squeue
squeue -u "$USER"
squeue -j <job-id>
squeue -o '%.18i %.12P %.30j %.8u %.2t %.10M %.6D %R'
scontrol show job <job-id>
sacct -j <job-id> --format=JobID,JobName,State,ExitCode,Elapsed,AllocTRES
```

## 提交批处理作业

`job.sh`：

```bash
#!/usr/bin/env bash
#SBATCH --job-name=<job-name>
#SBATCH --partition=<partition>
#SBATCH --cpus-per-task=<cpu-count>
#SBATCH --mem=<memory>
#SBATCH --time=<HH:MM:SS>
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

set -euo pipefail
hostname
<command>
```

```bash
mkdir -p logs
sbatch job.sh
```

## 交互式资源

```bash
srun --partition=<partition> --cpus-per-task=<cpu-count> --mem=<memory> --time=<HH:MM:SS> --pty bash
```

申请 GPU 时按集群约定补充资源参数：

```bash
srun --partition=<gpu-partition> --gres=gpu:<count> --pty bash
```

## 输出与排队原因

```bash
tail -f logs/<job-name>-<job-id>.out
tail -f logs/<job-name>-<job-id>.err
squeue -j <job-id> -o '%.18i %.2t %R'
scontrol show job <job-id> | rg 'JobState|Reason|StdOut|StdErr'
```

## 取消自己的作业

```bash
scancel <job-id>
scancel -u "$USER"
```

## 节点维护与恢复

以下命令会改变调度状态，只能由获得授权的运维人员执行。先确认节点没有作业、没有未确认的本机工作负载，并完成角色服务验收。

```bash
scontrol show node <node>
squeue -w <node>
scontrol update NodeName=<node> State=DRAIN Reason='scheduled maintenance'
```

开机后先确认调度 agent 已恢复并监听：

```bash
systemctl is-active slurmd
ss -ltnp
scontrol show node <node>
```

若节点显示资源注册无效，比较本机上报和控制端定义，再修正控制端配置：

```bash
slurmd -C
scontrol show node <node>
```

确认节点不再是 `DOWN`、`NOT_RESPONDING` 或 `INVALID_REG` 后恢复：

```bash
scontrol update NodeName=<node> State=RESUME
scontrol show node <node>
```

`RESUME` 不会删除 reservation；节点可能恢复为 `IDLE+RESERVED`，这是正常结果。

!!! warning "会申请或取消资源"

    `sbatch` 和 `srun` 会创建作业，`scancel` 会终止作业。不要执行节点状态修改、配置刷新或服务管理命令，除非已获得明确运维授权。
