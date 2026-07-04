"""Shared gateway context."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from comfy_gateway.kernel.auth import Caller
from comfy_gateway.kernel.ledger import Ledger


@dataclass
class ComfyContext:
    repo_root: Path
    ledger: Ledger
    caller: Optional[Caller] = None

