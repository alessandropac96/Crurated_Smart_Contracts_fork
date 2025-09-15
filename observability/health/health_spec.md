### Health abstraction specification

This document defines a small, implementation-agnostic health abstraction and wire protocol for services to report liveness, readiness, and detailed component health, without code duplication across services.

#### Endpoints
- `/health/live`: Returns 200 when the process is alive. Should be cheap, avoid external I/O. Returns 503 when not alive.
- `/health/ready`: Returns 200 only when all critical readiness checks pass (e.g., DB connectivity, essential dependencies). Returns 503 otherwise.
- `/health`: Returns a structured JSON payload with detailed checks. Should return 200 with a JSON body containing overall status; optionally support `?httpStatusFromStatus=true` to also reflect status via HTTP status code: `healthy=200`, `degraded=429`, `unhealthy=503`.

#### JSON schema (summary)
- `service`: Service name (e.g., `monitor`, `cron`, `worker`, `server`).
- `status`: One of `healthy`, `degraded`, `unhealthy`.
- `timestamp`: RFC3339 UTC timestamp of evaluation.
- `version`: Optional version/commit/build info.
- `checks[]`: List of component checks:
  - `name`: Human-friendly identifier (e.g., `database`, `queueLag`, `redis`, `chainRpc`)
  - `componentType`: Category of dependency (e.g., `database`, `queue`, `cache`, `http`, `scheduler`, `filesystem`)
  - `status`: `pass`, `fail`, `warn`
  - `severity`: `critical` or `non_critical` (controls readiness gate)
  - `observedValue`: Any JSON-serializable measurement (e.g., ms latency, queue depth)
  - `expected`: Human-readable expectation or numeric threshold(s)
  - `timeMs`: Duration spent in the check
  - `output`: Optional error text for failures/warns
- `summary`: Aggregated counts per status

See `schemas/health.schema.json` for the full JSON schema.

#### Aggregation rules
- Overall `status` is computed from checks using the following precedence:
  - If any `critical` check has `fail` -> `unhealthy`
  - Else if any check has `warn` -> `degraded`
  - Else -> `healthy`

#### Readiness gate
- `/health/ready` must return 503 unless all `critical` checks are `pass`.
- Non-critical failed checks should not block readiness, but should surface in `/health` and metrics/logs.

#### Common checks (shared logic)
- `DatabaseConnectivityCheck`: Attempts a lightweight query (e.g., `SELECT 1` or ping). Times out fast.
- `QueueLagCheck`: Measures lag or oldest message age; compares against thresholds.
- `CacheConnectivityCheck`: PING/PONG or `SET/GET` tiny key with TTL.
- `HttpDependencyCheck`: HEAD/GET with timeout and expected status/window.
- `SchedulerDriftCheck` (cron): Compares now vs last successful run; warns if drift exceeds tolerance.
- `ErrorRateCheck` (log-derived): Fails/warns based on error count in window; typically from metrics/logs, not inline.

#### Minimal wire example
```json
{
  "service": "server",
  "status": "degraded",
  "timestamp": "2025-09-15T12:00:00Z",
  "version": { "gitSha": "abc123", "build": "2025-09-15.1" },
  "checks": [
    {
      "name": "database",
      "componentType": "database",
      "status": "pass",
      "severity": "critical",
      "observedValue": { "latencyMs": 12 },
      "expected": { "latencyMsLt": 150 },
      "timeMs": 13
    },
    {
      "name": "redis",
      "componentType": "cache",
      "status": "warn",
      "severity": "non_critical",
      "observedValue": { "latencyMs": 180 },
      "expected": { "latencyMsLt": 100 },
      "timeMs": 182,
      "output": "PING slow"
    }
  ],
  "summary": { "pass": 1, "warn": 1, "fail": 0 }
}
```

#### Implementation guidance
- Keep all common check types in a shared library to avoid duplication.
- Services should compose the shared checks with service-specific checks.
- Always timebox checks with short timeouts and guard against cascading failures.
- Emit one-line logs for check failures to feed Loki alerts, e.g., `HEALTH_CHECK_FAIL service=server check=database error=...`.

