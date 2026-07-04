"""Append-only JSONL ledger for Comfy MCP tool calls."""

from __future__ import annotations

import hashlib
import json
import os
import threading
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Optional

REPO_ROOT = Path(__file__).resolve().parents[4]
SCHEMA_ID = "comfy-mcp-event.v1"
ARGS_PREVIEW_CHARS = 400


def comfy_mcp_root() -> Path:
    env = os.environ.get("COMFY_MCP_ROOT")
    return Path(env).resolve() if env else REPO_ROOT / "network" / "mcp"


def default_ledger_dir() -> Path:
    return comfy_mcp_root() / "var" / "ledger"


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def json_dumps(value: Any) -> str:
    return json.dumps(value, sort_keys=True, default=str, ensure_ascii=False)


def sha256_digest(value: Any) -> str:
    return "sha256:" + hashlib.sha256(json_dumps(value).encode("utf-8")).hexdigest()


def new_event(
    caller: Mapping[str, str],
    tool: str,
    *,
    args: Any = None,
    result: Any = None,
    ok: bool = True,
    error: Optional[str] = None,
    duration_ms: float = 0,
    task_id: Optional[str] = None,
) -> dict:
    args_json = json_dumps(args)
    return {
        "schema": SCHEMA_ID,
        "event_id": str(uuid.uuid4()),
        "ts": utc_now_iso(),
        "caller": {
            "id": caller["id"],
            "runner_class": caller["runner_class"],
            "node": caller["node"],
        },
        "tool": tool,
        "args_digest": sha256_digest(args),
        "args_preview": args_json[:ARGS_PREVIEW_CHARS],
        "result_digest": sha256_digest(result),
        "ok": bool(ok),
        "error": error,
        "duration_ms": round(float(duration_ms), 3),
        "task_id": task_id,
    }


class Ledger:
    def __init__(self, ledger_dir: Optional[Path | str] = None) -> None:
        self.dir = Path(ledger_dir) if ledger_dir else default_ledger_dir()
        self.dir.mkdir(parents=True, exist_ok=True)
        self.events_path = self.dir / "events.jsonl"
        self._lock = threading.Lock()

    def append(self, event: dict) -> str:
        line = json.dumps(event, ensure_ascii=False) + "\n"
        with self._lock:
            with self.events_path.open("a", encoding="utf-8") as fh:
                fh.write(line)
        return event["event_id"]

    def query(self, limit: int = 100) -> list[dict]:
        if not self.events_path.exists():
            return []
        lines = self.events_path.read_text(encoding="utf-8").splitlines()
        return [json.loads(line) for line in lines[-max(1, limit):] if line.strip()]

