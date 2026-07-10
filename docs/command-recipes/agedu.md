# Agedu 磁盘占用分析

> 最后更新：2026-07-10 | 类型：场景配方
>
> 关键词：`agedu`、`disk`、`cleanup`、`ssh-tunnel`
>
> 经验标签：`FT`

## 快速流程

### 1. 源机器 root：生成报告

```bash
cd /tmp

agedu -s / \
  --exclude /proc \
  --exclude /sys \
  --exclude /dev \
  --exclude /run

chmod 644 agedu.dat
```

### 2. 跳板机：下载并启动网页

```bash
mkdir -p ~/agedu-report
cd ~/agedu-report

scp <source-host>:/tmp/agedu.dat .

agedu -f agedu.dat \
  -w \
  --address 127.0.0.1:57853 \
  --auth none \
  --no-eof
```

保持该终端运行。

### 3. 个人 PC：建立本地隧道

```bash
ssh -N -L 127.0.0.1:57854:127.0.0.1:57853 <jump-host>
```

浏览器打开：

```text
http://127.0.0.1:57854/
```

### 4. 文本筛选

```bash
agedu -f agedu.dat \
  -t <path> \
  -a 2d |
awk '{printf "%.2f GiB\t%s\n", $1/1024/1024, $2}' |
sort -nr |
head -40
```

## 收尾

网页服务使用 `Ctrl+C` 停止。确认跳板机上的文件可用后，再由源机器 root 删除 `/tmp/agedu.dat`。

!!! warning "清理数据"

    Agedu 只提供候选目录。删除前必须联系路径 owner 确认，不能仅按访问时间直接删除。
