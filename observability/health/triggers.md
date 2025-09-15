### Health triggers per service

This file defines what constitutes "unhealthy" and "degraded" for each service role. These map to Grafana alert rules and notification policies.

Thresholds are initial defaults; tune per environment.

#### Common log signals (for Loki)
- Error spike: `level=error` count > 2 in 60s window → warn; > 5 → critical
- Explicit health fail: `HEALTH_CHECK_FAIL` log presence → critical for the corresponding check
- DB out of sync: log message containing `DB out of sync` → critical

#### monitor (blockchain/indexer/monitor)
- Unhealthy:
  - Database connectivity check fails
  - Chain RPC dependency check fails
  - Queue lag > 120s for critical topics
  - No blocks/events ingested in last 120s while expected
  - Error logs > 5 in 60s
- Degraded:
  - Queue lag 30s–120s
  - RPC latency p95 > 1500ms for 5m
  - Error logs 3–5 in 60s
  - Re-org rate spikes above baseline by 3x for 15m

#### cron (scheduled tasks)
- Unhealthy:
  - Scheduler drift > 5m for any critical job
  - Last successful run age > 2x schedule interval for critical jobs
  - Database connectivity check fails
  - Error logs > 5 in 60s
- Degraded:
  - Scheduler drift 2–5m
  - Last successful run age between 1x–2x schedule interval
  - Error logs 3–5 in 60s

#### worker (queues/background processors)
- Unhealthy:
  - Queue backlog above `maxBacklogCritical` or oldest message age > 5m
  - Dead-letter rate spikes above 5/min for 5m
  - Database or cache connectivity fails
  - Error logs > 5 in 60s
- Degraded:
  - Queue backlog above `maxBacklogWarn` or oldest message age 2–5m
  - Dead-letter rate 1–5/min for 5m
  - Error logs 3–5 in 60s

#### server (API/web)
- Unhealthy:
  - Database connectivity fails
  - p50 latency > 2s and p95 > 5s for 5m with RPS > 1
  - 5xx rate > 2% for 5m with >= 50 requests total
  - Error logs > 5 in 60s
- Degraded:
  - p95 latency 1–2s for 5m
  - 5xx rate 0.5%–2% for 5m
  - Error logs 3–5 in 60s

#### Notes
- All database-using services must include the `DatabaseConnectivityCheck` in readiness.
- Use labels `service`, `env`, and `severity` in logs and metrics to power routing.
- Where native metrics are missing, rely on log-based alerts temporarily.

