# Prometheus 命令

> 最后更新：2026-07-10 | 类型：命令速查
>
> 关键词：`prometheus`、`metrics`、`targets`、`promql`

## 服务与就绪状态

```bash
systemctl status prometheus --no-pager
curl -fsS http://<prometheus-host>:<port>/-/ready
curl -fsS http://<prometheus-host>:<port>/-/healthy
```

## 查询 API

查询当前可抓取目标：

```bash
curl -sG \
  --data-urlencode 'query=up' \
  http://<prometheus-host>:<port>/api/v1/query | jq .
```

精确查询一个 exporter：

```bash
curl -sG \
  --data-urlencode 'query=up{instance="<host>:<exporter-port>"}' \
  http://<prometheus-host>:<port>/api/v1/query | jq .
```

`up` 是 Prometheus 自己生成的抓取状态：`1` 表示本次抓取成功，`0` 表示目标已发现但抓取失败。`job` 是 scrape 配置名称，`instance` 通常是完整的 `<host>:<port>`。

查询一条基础指标：

```bash
curl -sG \
  --data-urlencode 'query=node_uname_info{instance="<host>:9100"}' \
  http://<metrics-host>:<port>/api/v1/query | jq .
```

汇总同一机器的多个 sensor 或设备指标：

```bash
curl -sG \
  --data-urlencode 'query=count(<metric_name>{instance="<host>:<port>"})' \
  http://<metrics-host>:<port>/api/v1/query | jq .
```

查询 targets：

```bash
curl -sS http://<prometheus-host>:<port>/api/v1/targets | jq .
curl -sS http://<prometheus-host>:<port>/api/v1/targets | jq '.data.activeTargets[] | {scrapeUrl, health, labels, lastError}'
```

## 告警与规则

```bash
curl -sS http://<prometheus-host>:<port>/api/v1/alerts | jq .
curl -sS http://<prometheus-host>:<port>/api/v1/rules | jq .
curl -fsS http://<alertmanager-host>:9093/-/ready
```

先确认告警的精确 `instance`、规则表达式和当前指标，再决定是否登录目标机。不要因为单条告警直接重启 exporter 或修改阈值。

## 目标机检查

```bash
systemctl status <exporter-service> --no-pager
ss -lntp | rg ':<exporter-port>\b'
curl -fsS http://127.0.0.1:<exporter-port>/metrics | head -30
```

## 配置与规则校验

```bash
promtool check config <prometheus.yml>
promtool check rules <rule-file.yml>
```

!!! warning "配置变更"

    修改 scrape 配置、服务发现、告警规则、exporter、DNS 或 reload/restart Prometheus 都会影响监控。先通过 `promtool` 校验，并确认生效范围和回滚方式。
