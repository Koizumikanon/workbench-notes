# 单台 NVIDIA GPU 主机接入 Prometheus 与 Grafana

> 最后更新：2026-07-12 | 类型：场景配方
>
> 关键词：`nvidia`、`gpu-exporter`、`prometheus`、`grafana`、`systemd`
>
> 经验标签：`FT`

本文把一台 NVIDIA GPU 主机接入监控拆成四个可独立验收的阶段：部署 exporter、选择可达的 Prometheus、登记 target、让 Grafana 自动发现标签。命令使用示例域名和文档保留地址，执行前必须替换变量并获得对应环境的变更授权。

本文负责单机端到端流程。跨网络采集端的取舍见[跨网络接入 Prometheus](prometheus-regional-scrape.md)，DNS-SD 控制面细节见[使用 DNS-SD 接入 Prometheus](prometheus-dns-sd-onboarding.md)。

## 先理解成功标准

```text
目标机 nvidia_gpu_exporter :9835
                 ↓
可访问目标机的 Prometheus collector
                 ↓
Prometheus 查询 API
                 ↓
Grafana Prometheus datasource
```

四层必须分别验证：

| 层 | 成功标准 | 不能代替它的证据 |
| --- | --- | --- |
| GPU 与 exporter | `nvidia-smi` 正常，service active，`/metrics` 有 GPU 指标 | 仅安装了二进制 |
| Prometheus target | collector 到目标端口可达，target `up=1` | 运维电脑能 `curl` |
| 查询 | `nvidia_info` 等看板依赖指标可查询 | 仅 `up=1` |
| Grafana | 选对 datasource/job/node/GPU 后有数据 | datasource 名称已存在 |

## 1. 设置本次变量

在自己的操作终端设置变量；不要把密码或 API token 放入变量文件、命令历史或 Git：

```bash
export TARGET_HOST='gpu-node-01.example.net'
export TARGET_ADDR='192.0.2.20'
export EXPORTER_PORT='9835'
export EXPORTER_SERVICE='nvidia_gpu_exporter'
export JOB_NAME='gpu_exporter'
export COLLECTOR_HOST='prometheus-edge-01.example.net'
export PROMETHEUS_URL='http://127.0.0.1:9090'
export CHANGE_ID="$(date -u +%Y%m%dT%H%M%SZ)-gpu-onboarding"

printf '%s\n' \
  "target=$TARGET_HOST ($TARGET_ADDR)" \
  "exporter_port=$EXPORTER_PORT" \
  "collector=$COLLECTOR_HOST" \
  "job=$JOB_NAME" \
  "change_id=$CHANGE_ID"
```

停止条件：变量仍是示例值、目标主机未获批准、collector 尚未确定，或不知道变更的备份位置时，不执行后续写操作。

## 2. 目标机只读预检

在目标 GPU 主机执行：

```bash
hostname -f
nvidia-smi -L
systemctl status "$EXPORTER_SERVICE" --no-pager || true
ss -lntp | grep -E ":${EXPORTER_PORT}([[:space:]]|$)" || true
command -v nvidia_gpu_exporter || true
```

如果 `nvidia-smi -L` 失败，先修复 GPU 驱动或设备可见性；exporter 不能替代驱动诊断。如果服务已经存在，先保存当前版本、参数和文件 hash，再决定是否真的需要重装：

```bash
systemctl cat "$EXPORTER_SERVICE" || true
nvidia_gpu_exporter --version 2>&1 || true
sha256sum "$(command -v nvidia_gpu_exporter)" 2>/dev/null || true
curl -fsS --max-time 10 \
  "http://127.0.0.1:${EXPORTER_PORT}/metrics" | \
  grep -E '^nvidia_(info|device_count)' | head -20
```

已有 exporter 同时满足 service active、端口监听和指标 schema 时，可以直接进入第 4 节，不必为了“重新跑一次”而无条件覆盖。

## 3. 部署 exporter

优先使用团队已审核的 Ansible role 或发布包。先固定 inventory 和版本，不要对 `all` 或大组直接执行：

```ini
[approved_gpu]
gpu-node-01.example.net
```

```bash
ansible-inventory -i approved-gpu.ini --graph
ansible-playbook -i approved-gpu.ini deploy-gpu-exporter.yml \
  --syntax-check
ansible-playbook -i approved-gpu.ini deploy-gpu-exporter.yml \
  --limit "$TARGET_HOST" --forks 1 \
  2>&1 | tee "gpu-exporter-${CHANGE_ID}.log"
```

执行前应阅读 role，明确它是否还会安装软件包、覆盖 node exporter、创建用户、修改 cron 或 restart 其他服务。“幂等”表示收敛到期望状态，不表示重复执行没有副作用。

如果环境没有批准的自动化流程，只能在明确授权后按发布包的说明手工安装。至少要做到：

1. 保存旧 binary、unit 和环境文件；
2. 校验批准 artifact 的 SHA-256；
3. 用 `--help` 确认当前版本的监听参数；
4. 先 `systemd-analyze verify`，再 `daemon-reload` 和启动；
5. 首次安装和覆盖升级使用不同回滚方案。

不要凭版本号猜 CLI。不同版本可能分别使用 `--web-listen-address`、`--web.listen-address` 或其他参数；binary、unit 参数与 Grafana 依赖的 metrics schema 必须作为一组验证。

## 4. 验证目标机 exporter

在目标机执行：

```bash
systemctl is-active "$EXPORTER_SERVICE"
ss -lntp | grep -E ":${EXPORTER_PORT}([[:space:]]|$)"
curl -fsS --max-time 10 \
  "http://127.0.0.1:${EXPORTER_PORT}/metrics" | \
  grep -E '^nvidia_(info|device_count)' | head -20
```

应同时看到：

- service 为 `active`；
- 端口正在监听；
- `nvidia_info` 与 `nvidia_device_count` 都存在。

HTTP 200 但没有看板依赖指标仍然不合格。保存本次 exporter 版本、binary hash、unit `ExecStart` 和指标样例，作为后续升级的兼容性基线。

## 5. 从 collector 网络验证可达性

登录真正准备抓取该目标的 Prometheus 主机，再执行：

```bash
curl -fsS --connect-timeout 5 --max-time 10 \
  "http://${TARGET_ADDR}:${EXPORTER_PORT}/metrics" | \
  grep -E '^nvidia_(info|device_count)' | head -20
```

这里必须使用 collector 实际可路由的目标地址。SSH tunnel 的 `127.0.0.1`、个人电脑能访问的别名以及跳板机端口转发，都不能证明 Prometheus 能访问目标。

选择规则：

```text
中央 Prometheus 可达 → 中央 static_configs 或 DNS-SD
中央不可达、区域 Prometheus 可达 → 区域 static_configs
所有现有 collector 都不可达 → 暂记 no-collector，先解决采集端
```

不要把必然不可达的 target 强行登记到中央 Prometheus，它只会制造长期 `down` 和无效告警。

## 6. 在 Prometheus 登记单个 target

本节演示区域 Prometheus 的 `static_configs`。如果目标属于已有 DNS-SD 池，跳到[DNS-SD 指南](prometheus-dns-sd-onboarding.md)按其候选文件、zone 校验和 reload 顺序操作。

在 collector 上备份 live 配置并创建候选文件：

```bash
export PROMETHEUS_CONFIG='/etc/prometheus/prometheus.yml'
export BACKUP_DIR="/var/backups/prometheus/${CHANGE_ID}"
export CANDIDATE="/tmp/prometheus.yml.${CHANGE_ID}"

sudo install -d -m 0700 "$BACKUP_DIR"
sudo cp -a "$PROMETHEUS_CONFIG" "$BACKUP_DIR/prometheus.yml"
sudo cp -a "$PROMETHEUS_CONFIG" "$CANDIDATE"
sudo chown "$(id -un):$(id -gn)" "$CANDIDATE"
```

在候选文件的 `scrape_configs:` 下添加独立 job，或把 target 加入已经存在且参数相同的 `gpu_exporter` job：

```yaml
  - job_name: gpu_exporter
    scrape_interval: 15s
    metrics_path: /metrics
    static_configs:
      - targets:
          - gpu-node-01.example.net:9835
        labels:
          monitoring_scope: production
```

不要把 GPU exporter 放进 node exporter job。保存候选文件后执行：

```bash
sudo promtool check config "$CANDIDATE"
sudo diff -u "$BACKUP_DIR/prometheus.yml" "$CANDIDATE"
```

人工确认 diff 只包含本次 target 后，安装并 reload：

```bash
sudo install -o root -g root -m 0644 \
  "$CANDIDATE" "$PROMETHEUS_CONFIG"
sudo promtool check config "$PROMETHEUS_CONFIG"
curl -fsS -X POST "${PROMETHEUS_URL}/-/reload"
```

若 Prometheus 未启用 HTTP lifecycle reload，应使用该环境批准的 reload 方式；不要因此直接 restart 整台主机。

## 7. 验证 Prometheus target 与指标

在 collector 上执行：

```bash
curl -sS "${PROMETHEUS_URL}/api/v1/targets" | jq \
  --arg instance "${TARGET_HOST}:${EXPORTER_PORT}" \
  '.data.activeTargets[] |
   select(.labels.instance == $instance) |
   {health,lastError,scrapeUrl,labels}'

curl -sG "${PROMETHEUS_URL}/api/v1/query" \
  --data-urlencode \
  "query=up{job=\"${JOB_NAME}\",instance=\"${TARGET_HOST}:${EXPORTER_PORT}\"}" | jq .

curl -sG "${PROMETHEUS_URL}/api/v1/query" \
  --data-urlencode \
  "query=nvidia_info{job=\"${JOB_NAME}\",instance=\"${TARGET_HOST}:${EXPORTER_PORT}\"}" | jq .
```

验收要求：target `health` 为 `up`、`lastError` 为空、`up` 的值为 `1`，并且 `nvidia_info` 返回至少一条序列。新 target 可能需要等待一个 discovery/scrape 周期；先等待并复查，不要立即重装 exporter。

## 8. Grafana 变量与自动发现

推荐的变量顺序是：

```text
Datasource → Job → Node → GPU
```

所有 panel datasource 使用 `${datasource}`，避免固定到中央 Prometheus。变量可使用：

```text
Datasource: type=Datasource, datasource type=Prometheus
Job:        label_values(nvidia_info, job)
Node:       label_values(nvidia_info{job="$job"}, instance)
GPU:        label_values(nvidia_info{job="$job",instance="$node"}, index)
```

Job、Node 和 GPU 能通过当前 Prometheus datasource 中的 `nvidia_info` 自动发现。新 target 指标入库后，刷新 dashboard 变量即可出现，不必为每台机器修改 panel。

Datasource 有一个重要限制：Grafana 的 datasource 变量能按类型或名称 regex 列出 datasource，但不能原生地逐个查询 datasource 中是否存在 `nvidia_info`，再动态隐藏没有 GPU 指标的 datasource。因此通常有两种做法：

- 使用统一命名规则，例如 `/^prometheus-gpu-/`；
- 维护一个只包含已验证 GPU datasource 的名称 regex，例如 `/^(prometheus-core|prometheus-edge-[a-z0-9-]+)$/`。

第二种不是完全自动发现：新增一个全新 GPU datasource 时，需要先验证它能查询 `nvidia_info`，再更新 regex。不要清空 regex 后让所有无 GPU 的 Prometheus 都出现在 GPU 看板中。

如果 datasource 尚不存在，先从 Grafana 所在网络验证它能访问对应 Prometheus，再由管理员通过受控 UI 或 API 创建。凭据使用 secret 管理，不写进教程、脚本或 shell history。

## 9. Grafana 验收

在 dashboard 依次选择：

```text
Datasource = 实际抓取该目标的 Prometheus
Job        = gpu_exporter
Node       = gpu-node-01.example.net:9835
GPU        = 对应 index
```

如果 Node 下拉没有目标，按下面顺序排查：

```text
目标机 /metrics
→ collector 到目标端口
→ Prometheus /api/v1/targets
→ Prometheus 查询 nvidia_info
→ Grafana datasource
→ Job / Node / GPU 变量
→ dashboard 时间范围
```

不要从 `No data` 直接跳到重装或重启。

## 10. 回滚 Prometheus 登记

若本次新增 target 导致配置或采集异常，在 collector 上使用同一 `CHANGE_ID` 的备份：

```bash
sudo install -o root -g root -m 0644 \
  "$BACKUP_DIR/prometheus.yml" "$PROMETHEUS_CONFIG"
sudo promtool check config "$PROMETHEUS_CONFIG"
curl -fsS -X POST "${PROMETHEUS_URL}/-/reload"
```

随后确认 target 已恢复到变更前状态。exporter 的回滚必须区分：

- 覆盖升级：恢复旧 binary、unit 和环境文件；
- 首次安装：停止并 disable 服务，再按批准方案删除新建 unit、binary 和专用用户。

只有“恢复旧文件”的脚本不能安全撤销首次安装，不能把两类回滚混用。

## 11. 交付记录

每台主机至少保留：

```text
target | GPU/driver | exporter version/hash | service/listener |
metrics schema | collection mode | collector | datasource |
job | instance | up result/time | change ID | backup | blocker
```

完成标准不是 Ansible 显示 `ok`，而是 exporter、collector、查询和 Grafana 四层都有可复核证据。
