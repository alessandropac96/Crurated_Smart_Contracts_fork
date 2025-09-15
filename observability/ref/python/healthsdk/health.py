from __future__ import annotations

import json
import time
from dataclasses import dataclass, field, asdict
from typing import Any, Callable, Dict, List, Optional


@dataclass
class HealthCheckResult:
    name: str
    componentType: str
    status: str  # pass | fail | warn
    severity: str  # critical | non_critical
    observedValue: Any = None
    expected: Any = None
    timeMs: float = 0.0
    output: Optional[str] = None


def compute_overall_status(checks: List[HealthCheckResult]) -> str:
    has_critical_fail = any(c.status == "fail" and c.severity == "critical" for c in checks)
    if has_critical_fail:
        return "unhealthy"
    has_warn = any(c.status == "warn" for c in checks)
    if has_warn:
        return "degraded"
    return "healthy"


def summarize(checks: List[HealthCheckResult]) -> Dict[str, int]:
    counts = {"pass": 0, "warn": 0, "fail": 0}
    for c in checks:
        counts[c.status] = counts.get(c.status, 0) + 1
    return counts


class HealthRegistry:
    def __init__(self, service_name: str, version: Optional[Dict[str, Any]] = None):
        self.service_name = service_name
        self.version = version or {}
        self._checks: List[Callable[[], HealthCheckResult]] = []

    def register(self, check: Callable[[], HealthCheckResult]) -> None:
        self._checks.append(check)

    def evaluate(self) -> Dict[str, Any]:
        results: List[HealthCheckResult] = []
        for check in self._checks:
            start = time.time()
            try:
                res = check()
                res.timeMs = (time.time() - start) * 1000.0
                results.append(res)
            except Exception as exc:
                results.append(
                    HealthCheckResult(
                        name=getattr(check, "__name__", "check"),
                        componentType="other",
                        status="fail",
                        severity="critical",
                        output=str(exc),
                        timeMs=(time.time() - start) * 1000.0,
                    )
                )
        overall = compute_overall_status(results)
        return {
            "service": self.service_name,
            "status": overall,
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "version": self.version,
            "checks": [asdict(r) for r in results],
            "summary": summarize(results),
        }

    def readiness_ok(self) -> bool:
        report = self.evaluate()
        for c in report["checks"]:
            if c["severity"] == "critical" and c["status"] != "pass":
                return False
        return True


def make_simple_check(
    name: str,
    component_type: str,
    severity: str,
    fn: Callable[[], Any],
    validator: Optional[Callable[[Any], bool]] = None,
    expected: Any = None,
) -> Callable[[], HealthCheckResult]:
    def _run() -> HealthCheckResult:
        value = fn()
        ok = validator(value) if validator else bool(value)
        return HealthCheckResult(
            name=name,
            componentType=component_type,
            status="pass" if ok else "fail",
            severity=severity,
            observedValue=value,
            expected=expected,
        )

    _run.__name__ = name  # helpful for error reporting
    return _run

