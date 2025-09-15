from __future__ import annotations

import os
from fastapi import FastAPI, Response, status
from healthsdk.health import HealthRegistry, make_simple_check


app = FastAPI(title="monitor")
registry = HealthRegistry(service_name="monitor", version={"gitSha": os.getenv("GIT_SHA", "dev")})


def db_ping():
    return True


def rpc_head():
    return {"reachable": True, "latencyMs": 100}


def validate_rpc(v):
    return v.get("reachable") and v.get("latencyMs", 10_000) < 1500


registry.register(
    make_simple_check(
        name="database",
        component_type="database",
        severity="critical",
        fn=db_ping,
    )
)

registry.register(
    make_simple_check(
        name="chainRpc",
        component_type="http",
        severity="critical",
        fn=rpc_head,
        validator=validate_rpc,
        expected={"latencyMsLt": 1500},
    )
)


@app.get("/health/live")
def live():
    return {"ok": True}


@app.get("/health/ready")
def ready(response: Response):
    ok = registry.readiness_ok()
    response.status_code = status.HTTP_200_OK if ok else status.HTTP_503_SERVICE_UNAVAILABLE
    return {"ready": ok}


@app.get("/health")
def health(httpStatusFromStatus: bool = False, response: Response = None):
    report = registry.evaluate()
    if httpStatusFromStatus and response is not None:
        if report["status"] == "healthy":
            response.status_code = status.HTTP_200_OK
        elif report["status"] == "degraded":
            response.status_code = status.HTTP_429_TOO_MANY_REQUESTS
        else:
            response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    return report

