# Linux 命令

## 当前环境

```bash
pwd
whoami
hostname
uname -a
uptime
date -Is
```

## 文件与目录

```bash
ls -lah
find <directory> -maxdepth 2 -type f | head -100
du -sh <path>
du -sh <directory>/* | sort -h
stat <path>
file <path>
```

## 磁盘、内存与进程

```bash
df -hT
lsblk -f
free -h
ps aux --sort=-%mem | head -20
ps aux --sort=-%cpu | head -20
pgrep -a <process-name>
```

## 网络与端口

```bash
ip -br addr
ip route
ss -lntp
ss -lunp
getent hosts <hostname>
curl -I --connect-timeout 5 https://<host>/
```

## systemd 与日志

```bash
systemctl status <service> --no-pager
systemctl is-active <service>
systemctl is-enabled <service>
journalctl -u <service> -n 200 --no-pager
journalctl -u <service> -f
```

## 文本与日志

```bash
rg -n -i '<keyword>' <path>
tail -n 200 <log-file>
tail -f <log-file>
less <file>
```

!!! warning "写操作"

    `rm`、`mv`、`chmod`、`chown`、`kill`、`systemctl restart` 和 `systemctl stop` 会改变文件、进程或服务状态。执行前确认对象和影响范围。
