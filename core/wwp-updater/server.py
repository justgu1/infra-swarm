"""
server.py — HTTP trigger server para wwp-updater.
n8n chama POST /run (meia-noite); quando termina, envia resultado ao N8N_WEBHOOK_URL.

Endpoints:
  POST /run     → executa o updater e retorna resultado (síncrono, ~10s)
  GET  /health  → retorna status do último run
"""

import logging
import os
import subprocess
import sys
from datetime import datetime, timezone

import requests
import uvicorn
from fastapi import FastAPI
from fastapi.responses import JSONResponse

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger(__name__)

app = FastAPI(title="wwp-updater", version="1.0")

N8N_WEBHOOK_URL = os.getenv("N8N_WEBHOOK_URL", "")

_last_run: dict | None = None


def _notify_n8n(payload: dict) -> None:
    if not N8N_WEBHOOK_URL:
        logger.warning("N8N_WEBHOOK_URL not set — skipping webhook")
        return
    try:
        resp = requests.post(N8N_WEBHOOK_URL, json=payload, timeout=15)
        resp.raise_for_status()
        logger.info(f"n8n webhook notified ({resp.status_code})")
    except Exception as exc:
        logger.warning(f"Failed to notify n8n: {exc}")


@app.post("/run")
def trigger_run():
    global _last_run
    started_at = datetime.now(timezone.utc)
    error: str | None = None
    output: str = ""

    logger.info("=== wwp-updater starting ===")
    try:
        result = subprocess.run(
            ["python3", "/app/update_whatsapp_version.py"],
            capture_output=True, text=True, timeout=120,
        )
        output = result.stdout + result.stderr
        if result.returncode != 0:
            error = f"exit code {result.returncode}: {result.stderr.strip()}"
            logger.error(error)
        else:
            logger.info("wwp-updater completed successfully")
    except Exception as exc:
        error = str(exc)
        logger.error(f"wwp-updater failed: {exc}")

    finished_at = datetime.now(timezone.utc)
    duration_s = round((finished_at - started_at).total_seconds(), 1)

    _last_run = {
        "started_at": started_at.isoformat(),
        "finished_at": finished_at.isoformat(),
        "duration_s": duration_s,
        "output": output[-2000:] if output else "",
        "error": error,
        "success": error is None,
    }

    logger.info(f"=== wwp-updater finished in {duration_s}s ===")
    _notify_n8n({"service": "wwp-updater", **_last_run})
    return _last_run


@app.get("/health")
def health():
    return {"status": "ok", "last_run": _last_run}


if __name__ == "__main__":
    uvicorn.run("server:app", host="0.0.0.0", port=8002, log_level="info")
