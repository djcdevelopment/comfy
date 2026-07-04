"""Caller identity for the Comfy MCP gateway."""

from __future__ import annotations

import hashlib
import json
import socket
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from comfy_gateway.kernel.ledger import Ledger, new_event

HEADER_NAME = "X-Comfy-Key"
AUTH_TOOL = "__auth__"
DEFAULT_CALLERS_PATH = Path(__file__).resolve().parents[1] / "etc" / "callers.json"
RUNNER_CLASSES = ("human", "mod", "agent")


@dataclass(frozen=True)
class Caller:
    id: str
    runner_class: str
    node: str

    def as_dict(self) -> dict:
        return {"id": self.id, "runner_class": self.runner_class, "node": self.node}


def _fingerprint(key: Optional[str]) -> str:
    if key is None:
        return "absent"
    return "sha256:" + hashlib.sha256(key.encode("utf-8")).hexdigest()[:16]


class AuthRegistry:
    def __init__(self, callers_path: Optional[Path | str] = None, ledger: Optional[Ledger] = None) -> None:
        self.callers_path = Path(callers_path) if callers_path else DEFAULT_CALLERS_PATH
        self.ledger = ledger
        self._callers = self._load()

    def _load(self) -> dict[str, Caller]:
        raw = json.loads(self.callers_path.read_text(encoding="utf-8"))
        callers = {}
        for key, entry in raw.items():
            if entry.get("runner_class") not in RUNNER_CLASSES:
                raise ValueError(f"caller {entry.get('id')!r}: invalid runner_class")
            callers[key] = Caller(
                id=entry["id"],
                runner_class=entry["runner_class"],
                node=entry["node"],
            )
        return callers

    def resolve(self, key: Optional[str]) -> Optional[Caller]:
        caller = self._callers.get(key) if key is not None else None
        if caller is not None:
            return caller
        if self.ledger is not None:
            self.ledger.append(new_event(
                {"id": "__unauthenticated__", "runner_class": "human", "node": socket.gethostname()},
                AUTH_TOOL,
                ok=False,
                error=f"auth: unknown or missing {HEADER_NAME} key ({_fingerprint(key)})",
            ))
        return None

