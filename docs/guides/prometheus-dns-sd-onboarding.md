# 使用 DNS-SD 接入 Prometheus 监控目标

> 最后更新：2026-07-11 | 类型：运维指南
>
> 关键词：`prometheus`、`dns-sd`、`bind`、`node-exporter`、`grafana`
>
> 经验标签：`FT`

DNS 服务发现（DNS-SD）适合把一批同类 exporter 交给 Prometheus 自动发现。它减少了静态 target 列表，但 DNS、Prometheus 与 exporter 必须一起验证。

## 工作模型

```text
host-a:9100 exporter
      ↓
DNS A + SRV record
      ↓
Prometheus dns_sd_configs
      ↓
metrics storage
      ↓
Grafana dashboard
```

## 先检查目标机器

在目标机执行：

```bash
systemctl is-active node_exporter
ss -lntp | grep ':9100\b'
curl -fsS http://127.0.0.1:9100/metrics | head -30
```

GPU exporter 应使用独立端口和独立的服务发现名称，避免让普通 node job 去抓 GPU 端口：

```bash
systemctl is-active nvidia_gpu_exporter
ss -lntp | grep ':9835\b'
curl -fsS http://127.0.0.1:9835/metrics | head -30
```

## DNS 记录示例

普通 node exporter 的 zone 片段：

```dns
host-a                IN A   192.0.2.10
_prometheus.ops.example. IN SRV 10 500 9100 host-a
```

GPU exporter 使用另一个 SRV owner 或独立 zone：

```dns
gpu-a                    IN A   192.0.2.20
_prometheus.gpu.example. IN SRV 10 500 9835 gpu-a
```

不要把 9100 和 9835 混进同一个被同一 scrape job 查询的 SRV 记录集合；否则 Prometheus 会把错误的 exporter 类型抓到错误端口。

## 安全变更顺序

```bash
# 1. 备份生效 zone
sudo cp /etc/bind/zones/db.ops.example /var/backups/db.ops.example.before

# 2. 在候选文件中修改 A/SRV 和 SOA serial
cp /var/backups/db.ops.example.before /tmp/db.ops.example.candidate
$EDITOR /tmp/db.ops.example.candidate

# 3. 先校验候选
named-checkzone ops.example /tmp/db.ops.example.candidate

# 4. 安装、再校验、仅 reload 本 zone
sudo install -o root -g bind -m 0644 /tmp/db.ops.example.candidate /etc/bind/zones/db.ops.example
sudo named-checkzone ops.example /etc/bind/zones/db.ops.example
sudo rndc reload ops.example
sudo rndc zonestatus ops.example
```

若候选校验或 reload 后的 zone serial 不符合预期，立刻恢复备份文件，再校验和 reload；不要在失败文件上继续追加记录。

## 验证顺序

```bash
# DNS 是否实际生效
dig +short @127.0.0.1 host-a.ops.example A
dig +short @127.0.0.1 _prometheus.ops.example SRV

# Prometheus 是否发现并抓取
curl -sS http://monitor.example:9090/api/v1/targets | jq \
  '.data.activeTargets[] | select(.labels.instance == "host-a.ops.example:9100") | {health,lastError,scrapeUrl}'

# 指标是否进入查询层
curl -sG http://metrics.example:8428/api/v1/query \
  --data-urlencode 'query=up{instance="host-a.ops.example:9100"}' | jq .
```

DNS-SD 通常有刷新间隔。第一次 target 查询为空时，先等待一个刷新周期并检查 DNS；不要立刻重复部署 exporter。

## 容量规划

有些 BIND 配置会限制一个同名 SRV RRset 的记录数。接入前统计当前数量：

```bash
dig +short @127.0.0.1 _prometheus.ops.example SRV | wc -l
```

接近上限时，新建规则化的 shard，例如 `ops01.example`、`ops02.example`，并把新 SRV 名称加入对应 Prometheus job 的 `dns_sd_configs`。不要把所有机器持续追加到一个接近上限的 SRV 集合。

## Textfile collector 的数据新鲜度

有些硬件或业务指标通过 cron 写入 node exporter 的 textfile collector。此时 exporter 服务正常、指标也存在，并不代表指标是新的；检查生成文件的修改时间：

```bash
systemctl is-active cron
stat -c '%n|mtime=%y|size=%s' /var/lib/node_exporter/textfile_collector/<collector>.prom
head -20 /var/lib/node_exporter/textfile_collector/<collector>.prom
```

如果文件时间明显早于当前时间，应先排查 cron、采集命令、写入权限和原子写入工具，再把数据用于硬件告警判断。

## 常见误区

- Grafana 下拉框没有机器，不等于 Grafana 出问题；先查 exporter、DNS、Prometheus target 和查询层指标。
- `up=1` 只代表抓取成功，仍要确认 dashboard 实际依赖的指标存在。
- textfile 指标存在不代表新鲜，必须检查生成文件的更新时间。
- IPMI textfile 指标、GPU exporter、node exporter 的部署副作用不同；先按机器能力分类，再批量执行。
- 批量数据面部署可以并发；同一个 DNS zone 或 Prometheus 配置文件的修改必须串行、备份并校验。
