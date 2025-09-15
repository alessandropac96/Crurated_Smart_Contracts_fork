from __future__ import annotations

import os
from fastapi import FastAPI, Response, status
from healthsdk.health import HealthRegistry, make_simple_check


app = FastAPI(title="server")
registry = HealthRegistry(service_name="server", version={"gitSha": os.getenv("GIT_SHA", "dev")})


# Example checks (replace with real db/cache implementations)
def db_ping():
    return True  # Replace with SELECT 1


def cache_ping():
    return True


registry.register(
    make_simple_check(
        name="database",
        component_type="database",
        severity="critical",
        fn=db_ping,
        expected={"latencyMsLt": 150},
    )
)

registry.register(
    make_simple_check(
        name="redis",
        component_type="cache",
        severity="non_critical",
        fn=cache_ping,
        expected={"latencyMsLt": 100},
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

