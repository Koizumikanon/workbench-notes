# Ubuntu 22.04 Server 更新并安装精简桌面

> 最后更新：2026-07-21 | 类型：场景配方
>
> 关键词：`Ubuntu Server`、`GNOME`、`Netplan`、`SSH`、`systemd-networkd`

把一台远程维护的 Ubuntu Server 改成带桌面的系统，风险不只来自桌面包本身。显示管理器会改变启动行为，NetworkManager 可能改变网络管理边界，大量依赖会占用磁盘，而内核更新又要求重启。

本文面向 Ubuntu 22.04，目标是在保留 SSH 兜底路径的前提下安装 `ubuntu-desktop-minimal`。示例假定当前网络由 `systemd-networkd` 管理；如果机器本来就使用 NetworkManager，应按现有设计调整，不要照搬 renderer 配置。

## 推荐拆分为三个维护窗口

1. 清点并处理重启后无法恢复的进程、容器和临时部署。
2. 更新 Ubuntu 22.04，重启并验证原有服务。
3. 安装 `ubuntu-desktop-minimal`，再次重启并验证桌面与网络。

不要把系统更新、桌面安装、网络迁移和远程桌面配置压缩成一次不可分辨的变更。每个阶段都应有明确的成功条件和回滚点。

## 一、更新前门禁

### 准备回滚与独立入口

- 为虚拟机创建快照；物理机应准备可启动备份或其他恢复介质。
- 确认虚拟机控制台、带外控制台或本地键盘可用。
- 保留一个独立 SSH 客户端，用于验证“新建连接”，不要只依赖当前会话。
- 保存当前网络配置，但不要把地址、密钥或内部拓扑复制到普通工单或公开日志。

### 盘点会话、服务和容器

```bash
date
uptime
who
systemctl --failed --no-pager
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
df -h / /boot
free -h
```

特别检查：

- 进程的 `WorkingDirectory`、可执行文件或虚拟环境是否仍存在。
- systemd unit 是持久单元还是 `/run` 下的 transient unit。
- 容器的 restart policy，以及 Compose 文件是否位于持久目录。
- 其他用户、自动化工具和长任务是否已经保存并退出。

当前仍在运行不等于重启后可以恢复。恢复来源已经丢失的进程必须先重建、迁移或明确废弃。

### 检查包管理器和空间

```bash
sudo dpkg --audit
apt-mark showhold
df -h / /boot
```

`/boot` 应能同时容纳新内核和至少一个可回退内核。桌面安装前建议至少保留 15～20 GiB 根分区余量，但应以实际模拟结果为准。

没有 Swap 的机器需要额外关注容器和桌面并发负载。不要只看 `used`，还要看 `available` 和是否出现 OOM 记录。

## 二、更新 Ubuntu 22.04

刷新索引并查看候选更新：

```bash
sudo apt update
apt list --upgradable
sudo apt-get -s full-upgrade
```

模拟结果至少应确认：

- 没有意外删除 SSH、网络、Docker 或开发工具链关键包。
- 没有切换发行版。
- 新内核和新增依赖符合预期。

`full-upgrade` 是当前 Ubuntu 22.04 内的包更新，不等于 `do-release-upgrade`。

执行更新：

```bash
sudo apt full-upgrade
```

遇到 SSH、网络或 Docker 配置文件提示时，不要未经比较直接覆盖本地配置。此阶段不要顺手执行宽泛的 `apt autoremove`，先保留旧内核用于回退。

重启前检查：

```bash
sudo dpkg --audit
sudo sshd -t
systemctl --failed --no-pager
test -f /var/run/reboot-required && cat /var/run/reboot-required
```

由维护者在确认快照、控制台、恢复命令和会话状态后执行重启。重启后验证新内核、SSH、容器和原有服务，再进入桌面安装阶段。

## 三、评估桌面安装影响

先模拟：

```bash
sudo apt-get -s install ubuntu-desktop-minimal
```

`minimal` 仍会引入大量组件，通常包括：

- GNOME Shell、GDM、Xorg 和 Wayland。
- Nautilus、终端和基础桌面工具。
- NetworkManager、音频、打印、网络发现和桌面密钥环。
- Firefox Snap 及其图形运行时。
- GNOME Remote Desktop 组件。

检查新增包数、下载量、安装后空间、显示管理器选择和是否删除现有包。包数量与体积会随镜像和更新时间变化，不要使用固定数字作为门槛。

## 四、保护 SSH 和网络管理边界

先确认当前 renderer：

```bash
sudo netplan get renderer
systemctl is-active ssh systemd-networkd NetworkManager
```

如果服务器应继续由 networkd 管理，可以用一个高优先级 Netplan 文件明确 renderer。先备份现有文件，并根据真实接口名替换 `<server-interface>`：

```yaml
# /etc/netplan/99-local-networkd.yaml
network:
  version: 2
  renderer: networkd
```

应用网络配置必须使用安全试运行：

```bash
sudo netplan generate
sudo netplan try --timeout 120
```

在倒计时内，从独立机器建立一条全新的 SSH 连接。只有新连接、路由和 DNS 都正常时才接受配置；否则让 Netplan 自动回滚。

安装 NetworkManager 后，它可以保持 active，但服务器主接口不应同时被两个管理器控制：

```bash
networkctl status <server-interface> --no-pager
nmcli -g GENERAL.STATE,GENERAL.NM-MANAGED \
  device show <server-interface>
```

预期结果是接口由 networkd 配置并可路由，NetworkManager 显示该接口为 unmanaged。

### wait-online 长时间等待的诊断

如果接口已经可达，但启动仍卡在 `systemd-networkd-wait-online`：

```bash
networkctl status <server-interface> --no-pager
systemctl status systemd-networkd-wait-online --no-pager
```

`routable (configuring)` 常见于某个地址族仍在等待。检查是否真的拥有全局 IPv6 和 IPv6 默认路由：

```bash
ip -6 -o addr show dev <server-interface> scope global
ip -6 route show default dev <server-interface>
sudo netplan get ethernets.<server-interface>.dhcp6
```

只有同时满足以下条件时，才考虑关闭 DHCPv6：

- 网络设计确认不提供 DHCPv6。
- 没有全局 IPv6 地址。
- 没有 IPv6 默认路由。
- 应用和运维入口都不依赖 IPv6。

覆盖示例：

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    <server-interface>:
      dhcp6: false
```

这不会自动禁用 IPv6 link-local。修改后仍须重新执行 `netplan generate`、`netplan try` 和独立 SSH 回连验证。

不要把禁用 wait-online、缩短超时或把接口整体设为 optional 当作首选修复。它们可能让依赖 `network-online.target` 的服务在网络真正可用前启动。

## 五、安装精简桌面

确认前述门禁满足后安装：

```bash
sudo DEBIAN_FRONTEND=noninteractive \
  apt-get install -y ubuntu-desktop-minimal
```

如果机器已经安装多个显示管理器，建议去掉 noninteractive，在控制台明确选择显示管理器。安装期间不要并行运行第二个 apt 或 dpkg。

安装完成、重启前检查：

```bash
sudo dpkg --audit
sudo sshd -t

dpkg-query -W \
  ubuntu-desktop-minimal \
  gdm3 \
  gnome-shell \
  network-manager \
  gnome-remote-desktop

systemctl is-active ssh systemd-networkd NetworkManager
systemctl is-enabled ssh systemd-networkd NetworkManager display-manager.service
systemctl get-default
sudo netplan get renderer
systemctl --failed --no-pager
```

GDM 在首次重启前可能仍为 inactive；确认 `display-manager.service` 已指向预期显示管理器即可。

## 六、重启后验收

```bash
uname -r
uptime
systemctl get-default
systemctl is-active ssh systemd-networkd NetworkManager gdm3
systemctl --failed --no-pager
sudo netplan get renderer
networkctl status <server-interface> --no-pager
nmcli -g GENERAL.STATE,GENERAL.NM-MANAGED \
  device show <server-interface>
df -h / /boot
free -h
```

验收标准：

- 新内核启动，`reboot-required` 已清除。
- GDM 和 GNOME Shell 正常运行，默认 target 为 `graphical.target`。
- SSH active 且 enabled，并从独立机器新建连接成功。
- 主接口仍由预期的网络管理器控制。
- wait-online 成功，没有失败 systemd unit。
- 磁盘和可用内存仍有安全余量。

SSH 主机密钥应按既有信任流程校验。不要为了测试使用永久的 `StrictHostKeyChecking=no`，也不要在脚本或文档中保存真实地址、指纹或私钥。

## 七、桌面访问方式

安装完成后，最简单的首次验收方式是虚拟机控制台或本机显示器。

- `gnome-remote-desktop` 包存在不代表远程桌面已经启用。
- GNOME 自带远程桌面、xrdp 和 VNC 的会话模型、安全边界不同，应作为独立变更评估。
- 远程桌面需要单独考虑防火墙、监听地址、认证、加密、无人登录场景和堡垒入口。
- 不要为了图形访问修改已经验证正常的 SSH 兜底路径。

## 八、清理与回滚

稳定运行一段时间后，可以先模拟自动清理：

```bash
sudo apt-get -s autoremove --purge
```

确认当前内核，并至少保留一个已知可启动的旧内核，再决定是否删除旧内核。APT 下载缓存可以单独清理：

```bash
sudo apt clean
```

不要假定卸载 `ubuntu-desktop-minimal` 元包就能完整恢复纯 Server 状态；大量依赖和服务不会自动按原样回退。若桌面安装造成网络、启动或依赖问题，优先使用维护前快照恢复。必须原地卸载时，先模拟并逐项审核删除列表。

## 最小成功标准

一次合格交付至少需要保存以下证据：

1. 安装前后的包管理器完整性检查。
2. 新内核与显示管理器状态。
3. renderer、接口管理者和 wait-online 状态。
4. 独立机器新建 SSH 会话成功。
5. 失败单元、磁盘和内存检查。
6. 快照或其他可执行回滚路径。
