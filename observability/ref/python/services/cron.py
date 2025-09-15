from __future__ import annotations

import os
import time
from fastapi import FastAPI, Response, status
from healthsdk.health import HealthRegistry, make_simple_check


app = FastAPI(title="cron")
registry = HealthRegistry(service_name="cron", version={"gitSha": os.getenv("GIT_SHA", "dev")})


LAST_SUCCESS = {"criticalJob": time.time()}
SCHEDULE_SEC = {"criticalJob": 300}


def db_ping():
    return True


def scheduler_drift():
    now = time.time()
    age = now - LAST_SUCCESS["criticalJob"]
    return {"lastSuccessAgeSec": age}


def validate_drift(v):
    return v["lastSuccessAgeSec"] < 600


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
        name="schedulerDrift",
        component_type="scheduler",
        severity="critical",
        fn=scheduler_drift,
        validator=validate_drift,
        expected={"lastSuccessAgeSecLt": 600},
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

