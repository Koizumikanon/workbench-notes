# 跨网络接入 Prometheus：集中抓取与区域采集端的选择

> 最后更新：2026-07-12 | 类型：运维指南
>
> 关键词：`prometheus`、`gpu-exporter`、`dns-sd`、`grafana`、`regional-scrape`
>
> 经验标签：`FT`

当监控中心无法访问某台 exporter 时，最常见的错误是把它仍然登记到中央 Prometheus：结果只是一个长期 `down` target。正确问题不是“如何让 Grafana 显示机器”，而是“哪个采集端能从自己的网络到达 exporter”。

本文聚焦采集拓扑选择和中央/区域切换。单台主机从 exporter 部署到 Grafana 验收的完整步骤见[单台 NVIDIA GPU 主机接入 Prometheus 与 Grafana](nvidia-gpu-monitoring-onboarding.md)；DNS-SD zone 的完整操作见[使用 DNS-SD 接入 Prometheus](prometheus-dns-sd-onboarding.md)。

## 先分清四层

```text
目标机 exporter
      ↓
Prometheus collector
      ↓
时序数据库 / 查询 API
      ↓
Grafana dashboard
```

这四层需要分别通过：

| 层 | 最小成功条件 | 失败时优先检查 |
| --- | --- | --- |
| exporter | service active、端口监听、`/metrics` 有所需指标 | 驱动、unit 参数、二进制版本 |
| collector | Prometheus target `up=1` | collector 到 exporter 的网络和 target 配置 |
| 查询 | `up` 和看板依赖指标可查询 | datasource、label、采集延迟 |
| Grafana | 选对 datasource、job、node 后显示数据 | dashboard 变量、时间范围、权限 |

Grafana `No data` 不能证明 exporter 有问题；反过来，端口能打开也不能证明 dashboard 的指标 schema 兼容。

## 选择采集模式

```text
中央 Prometheus 能连接 exporter？
  ├─ 能：中央 DNS-SD 或中央 static_configs
  └─ 不能：已有区域 Prometheus 能连接 exporter？
            ├─ 能：区域 Prometheus static_configs
            └─ 不能：新建区域 collector / Prometheus Agent / remote_write 方案
```

### 模式 A：中央 Prometheus + DNS-SD

适用于中央监控网络可直接到达一批同类 exporter 的场景。DNS A/SRV 记录提供目标列表，Prometheus 自动发现。

```text
gpu-node-a:9835
       ↓
DNS A + SRV
       ↓
central Prometheus dns_sd_configs
       ↓
Grafana datasource
```

DNS-SD 适合批量同类节点，但要控制每个 SRV record set 的容量。接近运行时限制时，新建规则化 shard，例如 `gpu-a.monitoring.example`、`gpu-b.monitoring.example`；不要把所有机器持续塞进一个旧集合。

### 模式 B：区域 Prometheus + static_configs

适用于 exporter 只能在局部网络被访问的场景。区域 Prometheus 应直接从同一网络抓取 exporter，Grafana 通过该 Prometheus datasource 查询。

```text
gpu-node-b:9835
       ↓
regional Prometheus:9090
       ↓
Grafana regional datasource
```

这不是降级方案。Prometheus 是 pull 模型，采集端的网络位置决定了它能不能抓到指标。

### 模式 C：新增区域 collector 或 Prometheus Agent

如果中央和任何既有区域 Prometheus 都不能访问 exporter，不要创建一个必然失败的 target。先选择：

- 在目标网络部署受控的 Prometheus/Prometheus Agent；或
- 让区域 collector 通过 `remote_write` 把数据发往中心存储；或
- 处理网络策略后再接入。

在 collector 存在前，将节点记录为“等待采集端”比制造误报警更准确。

## 上线前只读验证

先在目标机确认 exporter，而不是从看板猜测：

```bash
systemctl is-active nvidia_gpu_exporter
ss -lntp | grep ':9835\b'
curl -fsS --max-time 10 http://127.0.0.1:9835/metrics | \
  grep -E '^nvidia_(info|device_count)' | head -20
```

从候选 collector 的网络再测一次。这里的地址必须是 collector 真正可路由的地址，不能使用 SSH tunnel 中的 loopback 地址：

```bash
curl -fsS --connect-timeout 5 --max-time 10 \
  http://gpu-node-a.example.net:9835/metrics | head -30
```

如果 GPU dashboard 依赖 `nvidia_info` 与 `nvidia_device_count`，不要只检查 HTTP 200；这两种 metric 都要存在。二进制版本、SHA-256、CLI 参数和指标 schema 是不同的兼容性检查项。

## 安全变更模板：区域 Prometheus

下例使用候选文件来防止 YAML 或缩进错误破坏 live config。替换路径、权限和 service 名称以符合你的系统。

```bash
change_id="$(date -u +%Y%m%dT%H%M%SZ)-gpu"
backup_dir="/var/backups/prometheus/$change_id"

sudo install -d -m 0700 "$backup_dir"
sudo cp -a /etc/prometheus/prometheus.yml "$backup_dir/prometheus.yml"
sudo cp -a /etc/prometheus/prometheus.yml "/tmp/prometheus.yml.$change_id"
sudo chown "$USER":"$(id -gn)" "/tmp/prometheus.yml.$change_id"
```

在候选文件的 `scrape_configs:` 下添加独立 job。不要把 GPU exporter 混入 node exporter job：

```yaml
  - job_name: gpu_exporter
    metrics_path: /metrics
    static_configs:
      - targets:
          - gpu-node-a.example.net:9835
        labels:
          monitoring_scope: regional
```

验证并生效：

```bash
sudo promtool check config "/tmp/prometheus.yml.$change_id"
diff -u "$backup_dir/prometheus.yml" "/tmp/prometheus.yml.$change_id"

sudo install -o root -g root -m 0644 \
  "/tmp/prometheus.yml.$change_id" /etc/prometheus/prometheus.yml
sudo promtool check config /etc/prometheus/prometheus.yml
curl -fsS -X POST http://127.0.0.1:9090/-/reload
```

使用 reload 而不是没有理由的 service restart。若候选校验失败，live 文件尚未改动；先修候选。若生效后验证失败，恢复同一 `change_id` 的备份、再次 `promtool`、再 reload。

## DNS-SD 的安全变更模板

DNS-SD 的完整基础知识见[使用 DNS-SD 接入 Prometheus 监控目标](prometheus-dns-sd-onboarding.md)。关键顺序是：

```text
backup → 编辑候选 zone → named-checkzone → 安装 live zone →
named-checkzone → zone reload → zonestatus → dig SRV → Prometheus targets
```

示例记录：

```dns
gpu-node-a                 IN A   192.0.2.20
_prometheus.gpu.example.  IN SRV 10 500 9835 gpu-node-a
```

候选文件语法通过不代表 DNS server 已加载它；reload 后必须检查运行中 zone 状态和实际 `dig` 返回。Prometheus DNS-SD 也有刷新周期，第一次没有 target 时先检查 DNS 并等待一个周期，不要立刻重复部署 exporter。

## 验收：从 target 到 Grafana

在 collector 上检查 target 和指标：

```bash
curl -sS http://127.0.0.1:9090/api/v1/targets | jq \
  '.data.activeTargets[] | select(.labels.instance == "gpu-node-a.example.net:9835") |
   {health,lastError,scrapeUrl,labels}'

curl -sG http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=up{job="gpu_exporter",instance="gpu-node-a.example.net:9835"}' | jq .

curl -sG http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=nvidia_info{job="gpu_exporter",instance="gpu-node-a.example.net:9835"}' | jq .
```

Grafana dashboard 有多个 Prometheus datasource 时，变量应遵循：

```text
Datasource → Job → Node → GPU
```

Datasource 与 job 都应对使用者可见；node/gpu 查询应使用当前 datasource，而不是固定到中央数据源。新增 datasource 前先从 Grafana 网络确认能访问对应 Prometheus `:9090`，否则下拉框里只会多出一个无数据选项。

Job、Node 和 GPU 可以用 `label_values(nvidia_info, ...)` 在当前 datasource 内自动发现。Datasource 变量本身只能按类型或名称 regex 过滤，不能逐个查询 Prometheus 是否存在 `nvidia_info` 后自动隐藏无 GPU 的 datasource。实际使用时应采用统一命名规则，或维护一个已验证 GPU datasource 的小型白名单。

## 常见失败与恢复

| 现象 | 常见根因 | 正确处理 |
| --- | --- | --- |
| service failed | binary CLI 参数与 unit 不兼容 | 恢复批准的 binary/unit，验证 metrics schema |
| target `down` | collector 无法连接 exporter | 从 collector 网络测试；改用区域 collector，不要强行中央登记 |
| DNS 看见记录、Prometheus 未发现 | DNS-SD 缓存或刷新周期 | 先查 `dig`，等待刷新，再查 targets |
| `promtool` 失败 | YAML 缩进/结构错误 | 修候选文件，live 文件不动 |
| Grafana No data | datasource/job/node 不匹配，或 datasource 网络不通 | 先验证 collector API 与 query，再查变量 |
| 双份数据/告警混乱 | 同一 exporter 同时进入两条 scrape job | 迁移时先确认旧登记已移除，再启用新登记 |

## 建议的交付表字段

每个 target 一行，至少保留：

```text
host role | exporter health | collection mode | collector | datasource |
job | instance | up result/time | change ID | backup ID | blocker
```

这样可以清楚区分“exporter 已部署”“已被 Prometheus 抓取”“Grafana 已可展示”，也使下一位操作者能定位回滚备份。
