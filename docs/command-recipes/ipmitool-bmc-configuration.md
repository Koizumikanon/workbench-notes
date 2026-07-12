# 使用 ipmitool 配置 BMC 网络与用户

> 最后更新：2026-07-12 | 类型：场景配方
>
> 关键词：`ipmitool`、`BMC`、`IPMI`、`network`、`user`
>
> 验证状态：核心网络与用户配置流程已在实际工作中多次执行

适用场景：通过服务器本机操作系统或现场控制台，使用 `ipmitool` 配置 BMC 的静态网络、管理用户和通道权限。

## 0. 快速执行

先确认当前操作是在服务器本机或可靠的现场控制台中进行。修改 BMC 地址后，原有带外连接可能立即中断。

替换以下占位符：

- `<channel-id>`：LAN 通道编号，常见值为 `1`，必须以实际查询结果为准
- `<bmc-ip>`：新的 BMC 地址
- `<netmask>`：BMC 子网掩码
- `<gateway>`：BMC 默认网关；不需要跨网段访问时才考虑 `0.0.0.0`
- `<user-id>`：准备配置的用户 ID，必须先确认没有误占用已有账号
- `<bmc-user>`：BMC 管理用户名
- `<privilege-level>`：权限等级，管理员通常为 `4`

先整段复制只读检查：

```bash
# 查看通道、当前网络和现有用户
sudo ipmitool channel info <channel-id>
sudo ipmitool lan print <channel-id>
sudo ipmitool user list <channel-id>
```

确认通道和目标用户 ID 后，再整段复制写操作：

```bash
# 设置静态网络
sudo ipmitool lan set <channel-id> ipsrc static
sudo ipmitool lan set <channel-id> ipaddr <bmc-ip>
sudo ipmitool lan set <channel-id> netmask <netmask>
sudo ipmitool lan set <channel-id> defgw ipaddr <gateway>

# 设置用户名
sudo ipmitool user set name <user-id> <bmc-user>

# 隐藏输入密码，避免密码直接写入 shell 历史
read -rsp '请输入新的 BMC 密码：' BMC_PASSWORD
echo
sudo ipmitool user set password <user-id> "$BMC_PASSWORD"
unset BMC_PASSWORD

# 设置通道访问权限并启用用户
sudo ipmitool channel setaccess <channel-id> <user-id> \
  callin=on ipmi=on link=on privilege=<privilege-level>
sudo ipmitool user enable <user-id>
```

最后整段复制本机验证：

```bash
sudo ipmitool lan print <channel-id>
sudo ipmitool user list <channel-id>
sudo ipmitool channel getaccess <channel-id> <user-id>
```

从另一台具有网络访问权限的机器验证远程登录，密码通过交互提示输入：

```bash
ipmitool -I lanplus \
  -H <bmc-ip> \
  -U <bmc-user> \
  -a \
  mc info
```

!!! danger "防止失联"

    不要在只有当前 BMC 会话可用时直接修改其 IP、掩码或网关。先确保服务器本机、现场控制台或另一条可靠管理路径可用，并保存原配置。

## 1. 确认执行条件

确认 `ipmitool` 已安装，并且当前系统可以访问本机 BMC：

```bash
command -v ipmitool
sudo ipmitool mc info
```

如果 `mc info` 失败，先检查 IPMI 内核设备和相关模块，不要继续写入网络或用户配置：

```bash
ls -l /dev/ipmi* 2>/dev/null
lsmod | grep -E 'ipmi|ipmi_si|ipmi_devintf'
dmesg | grep -Ei 'ipmi|bmc' | tail -50
```

## 2. 确认 LAN 通道

不同厂商或机型的 LAN 通道不一定都是 `1`。先查询候选通道：

```bash
sudo ipmitool channel info 1
sudo ipmitool channel info 2
sudo ipmitool channel info 3
```

找到介质类型为 `802.3 LAN` 的通道后，再查看当前配置：

```bash
sudo ipmitool lan print <channel-id>
```

保存修改前的配置，便于核对和回滚：

```bash
sudo ipmitool lan print <channel-id> > bmc-lan-before.txt
sudo ipmitool user list <channel-id> > bmc-users-before.txt
```

这些文件可能包含真实管理地址、MAC 和用户名，只能保存在受控位置，不要上传到公开仓库。

## 3. 配置静态网络

```bash
sudo ipmitool lan set <channel-id> ipsrc static
sudo ipmitool lan set <channel-id> ipaddr <bmc-ip>
sudo ipmitool lan set <channel-id> netmask <netmask>
sudo ipmitool lan set <channel-id> defgw ipaddr <gateway>
```

设置完成后重新读取配置：

```bash
sudo ipmitool lan print <channel-id>
```

只有确定 BMC 不需要跨网段访问时，才把网关设为 `0.0.0.0`。需要从其他网段或远程管理网络访问时，必须配置正确网关。

## 4. 确认用户 ID

```bash
sudo ipmitool user list <channel-id>
```

必须同时核对 `ID`、`Name`、启用状态和权限。不要仅凭历史命令猜测用户 ID，也不要因为注释写着某个 ID，就直接修改另一个 ID 的密码。

选择用户 ID 时遵守以下原则：

- 已经有业务用途的账号不得覆盖。
- 空用户名不一定代表该 ID 可以安全使用，需结合设备说明确认。
- 用户 ID `1` 在部分设备上具有特殊含义，不应默认用作普通管理账号。
- 如果只是重置已有账号密码，先确认用户名与目标 ID 完全一致。

## 5. 设置用户和密码

```bash
sudo ipmitool user set name <user-id> <bmc-user>

read -rsp '请输入新的 BMC 密码：' BMC_PASSWORD
echo
sudo ipmitool user set password <user-id> "$BMC_PASSWORD"
unset BMC_PASSWORD
```

`ipmitool user set password <user-id>` 在省略密码参数时会把密码清空，并不会弹出设置提示，因此不能单独执行。上面的 `read -s` 可以避免密码进入 shell 历史；但 `ipmitool` 执行期间密码仍会短暂作为进程参数存在，应只在受控的管理员终端中操作，完成后立即 `unset` 变量。

部分 BMC 对密码长度有 16 或 20 字符限制；遇到拒绝时，应查设备限制并重新生成密码，不要改成容易猜测的短密码。

## 6. 设置权限并启用用户

```bash
sudo ipmitool channel setaccess <channel-id> <user-id> \
  callin=on ipmi=on link=on privilege=<privilege-level>

sudo ipmitool user enable <user-id>
```

常见权限等级：

| 等级 | 含义 | 使用建议 |
| --- | --- | --- |
| `2` | User | 只需要基础查询时使用 |
| `3` | Operator | 需要部分操作权限时使用 |
| `4` | Administrator | 仅管理账号使用 |

按实际需求授予最低权限，不要把所有账号都设为管理员。

## 7. 验证

先在服务器本机检查网络、用户和权限：

```bash
sudo ipmitool lan print <channel-id>
sudo ipmitool user list <channel-id>
sudo ipmitool channel getaccess <channel-id> <user-id>
```

再从另一台机器进行带外连接验证：

```bash
ipmitool -I lanplus \
  -H <bmc-ip> \
  -U <bmc-user> \
  -a \
  mc info
```

验证结果应满足：

- BMC 地址、掩码、网关和地址来源符合预期。
- 目标用户已启用，用户名和用户 ID 对应正确。
- 通道允许 IPMI 和链路认证，权限等级符合预期。
- 从独立机器能够通过 `lanplus` 登录并读取 BMC 信息。

## 8. 回滚

根据修改前保存的配置恢复原网络参数：

```bash
sudo ipmitool lan set <channel-id> ipsrc static
sudo ipmitool lan set <channel-id> ipaddr <old-bmc-ip>
sudo ipmitool lan set <channel-id> netmask <old-netmask>
sudo ipmitool lan set <channel-id> defgw ipaddr <old-gateway>
```

如果原来使用 DHCP：

```bash
sudo ipmitool lan set <channel-id> ipsrc dhcp
```

禁用本次新建且确认不再需要的用户：

```bash
sudo ipmitool user disable <user-id>
```

不要删除或覆盖仍被其他维护流程使用的管理账号。回滚后重新执行本机检查和远程 `lanplus` 验证。

## 9. 安全与记录

- BMC 属于高权限带外管理面，应使用独立管理网络和严格访问控制。
- 真实 BMC 地址、MAC、用户名和密码不得写入公开文档或 Git。
- 不要在命令行中直接携带密码，优先使用交互提示。
- 记录变更对象、旧配置、新配置、用户 ID、权限等级和验证结果，但不要记录明文密码。
- 修改网络前保留本机或现场控制台路径，修改后必须从独立机器验证。
