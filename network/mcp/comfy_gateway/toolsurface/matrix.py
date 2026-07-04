"""Era16 baseline-matrix check-in / dispatch loop.

A staggered swarm of instrumented clients checks in here to collect one matrix
cell at a time: `checkout` hands the client the next pending cell (a density band
coordinate + observer range offset + event profile + benchmark window), the client
runs it and `report`s the captured NetworkSense benchmark, then loops. This turns a
swarm into a continuous, resumable collector for the era16-density-pressure-matrix
without an operator driving each client.

State is a single plan file plus an append-only results log under the gateway var
dir, so a run is inspectable and survives a gateway restart.
"""

from __future__ import annotations

import csv
import json
import os
import threading
import time
from pathlib import Path
from statistics import mean
from typing import Callable, Optional

_VAR_DIR = Path(os.environ.get(
    "COMFY_MATRIX_VAR_DIR",
    str(Path(__file__).resolve().parents[2] / "var" / "matrix"),
))
_PLAN_PATH = _VAR_DIR / "plan.json"
_RESULTS_PATH = _VAR_DIR / "results.jsonl"

# Modeled backstop (the 9,600-row era16 pressure matrix) staged where the gateway can read it,
# and the server-side heartbeat telemetry the dedicated server writes (mounted at /lab/state).
_MODELED_CSV = Path(os.environ.get(
    "COMFY_MATRIX_MODELED_CSV", str(_VAR_DIR / "modeled-pressure-matrix.csv")))
_SERVER_TELEMETRY = Path(os.environ.get(
    "COMFY_SERVER_TELEMETRY",
    "/lab/state/server/config/bepinex/comfy-network-sense/telemetry-server.jsonl"))
# The modeled slice measured cells are compared against (the clean-room row).
_BASELINE_SLICE = {"actor_players": "1", "rtt_ms": "0", "server_process_ms": "2"}

# Density band -> world (x, z). Defaults mirror the teleport-route.tsv fixtures; an
# override TSV keeps this in sync with whatever fixtures a run actually targets.
_ROUTE_TSV = Path(os.environ.get(
    "COMFY_MATRIX_ROUTE_TSV",
    str(Path(__file__).resolve().parents[4]
        / "fieldlab" / "autonomous" / "state" / "client-shared"
        / "comfy-network-sense" / "teleport-route.tsv"),
))
_DEFAULT_DENSITY_COORDS = {
    "open_control": (0.0, 0.0),
    "sparse": (1250.0, 7750.0),
    "light": (-10250.0, 7750.0),
    "mixed": (-1750.0, 13250.0),
    "dense": (-4250.0, 14250.0),
    "extreme": (3250.0, 2250.0),
}
# Observer range -> approximate offset from the fixture in meters (AoI bands).
_OBSERVER_OFFSETS = {"self": 0.0, "near": 32.0, "mid": 96.0, "far": 256.0}
_EVENT_PROFILES = ["movement_only", "build_social", "combat_build", "event_surge"]

_lock = threading.Lock()


def _density_coords() -> dict[str, tuple[float, float]]:
    coords = dict(_DEFAULT_DENSITY_COORDS)
    try:
        if _ROUTE_TSV.exists():
            for line in _ROUTE_TSV.read_text(encoding="utf-8-sig").splitlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split("\t") if "\t" in line else line.split(",")
                if len(parts) < 3 or parts[0].strip().lower() == "id":
                    continue
                band = parts[0].strip().split("_", 2)[-1]  # route_05_dense -> dense
                try:
                    coords[band] = (float(parts[1]), float(parts[2]))
                except ValueError:
                    continue
    except OSError:
        pass
    return coords


def _generate_cells(
    density_bands: list[str],
    observer_ranges: list[str],
    event_profiles: list[str],
    benchmark_seconds: int,
) -> list[dict]:
    coords = _density_coords()
    cells: list[dict] = []
    for band in density_bands:
        base_x, base_z = coords.get(band, (0.0, 0.0))
        for observer in observer_ranges:
            offset = _OBSERVER_OFFSETS.get(observer, 0.0)
            for profile in event_profiles:
                cells.append({
                    "cell_id": f"{band}.{observer}.{profile}",
                    "density_band": band,
                    "observer_range": observer,
                    "event_profile": profile,
                    "x": base_x + offset,
                    "z": base_z,
                    "observer_offset_m": offset,
                    "benchmark_seconds": benchmark_seconds,
                    "status": "pending",
                    "client": None,
                    "assigned_at": None,
                    "done_at": None,
                })
    return cells


def _load_plan() -> Optional[dict]:
    if not _PLAN_PATH.exists():
        return None
    try:
        return json.loads(_PLAN_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def _save_plan(plan: dict) -> None:
    _VAR_DIR.mkdir(parents=True, exist_ok=True)
    tmp = _PLAN_PATH.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(plan, indent=2), encoding="utf-8")
    tmp.replace(_PLAN_PATH)


def _summarize(plan: dict) -> dict:
    counts = {"pending": 0, "assigned": 0, "done": 0}
    for cell in plan.get("cells", []):
        counts[cell.get("status", "pending")] = counts.get(cell.get("status", "pending"), 0) + 1
    return counts


def _reclaim_stale(plan: dict, now: float, lease_seconds: float) -> None:
    """Return assigned-but-abandoned cells to the pool so a dead client can't strand them."""
    for cell in plan.get("cells", []):
        if (cell.get("status") == "assigned"
                and cell.get("assigned_at") is not None
                and now - cell["assigned_at"] > lease_seconds):
            cell["status"] = "pending"
            cell["client"] = None
            cell["assigned_at"] = None


def valheim_matrix_seed(
    reset: bool = False,
    benchmark_seconds: int = 60,
    density_bands: Optional[list[str]] = None,
    observer_ranges: Optional[list[str]] = None,
    event_profiles: Optional[list[str]] = None,
) -> dict:
    """Create the matrix plan if missing (or rebuild it with `reset=True`)."""
    with _lock:
        if _load_plan() is not None and not reset:
            plan = _load_plan()
            return {"ok": True, "created": False, "cells": len(plan.get("cells", [])), "counts": _summarize(plan)}

        bands = density_bands or list(_DEFAULT_DENSITY_COORDS.keys())
        ranges = observer_ranges or list(_OBSERVER_OFFSETS.keys())
        profiles = event_profiles or list(_EVENT_PROFILES)
        cells = _generate_cells(bands, ranges, profiles, benchmark_seconds)
        plan = {
            "schema_version": 1,
            "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "benchmark_seconds": benchmark_seconds,
            "axes": {"density_bands": bands, "observer_ranges": ranges, "event_profiles": profiles},
            "cells": cells,
        }
        _save_plan(plan)
        return {"ok": True, "created": True, "cells": len(cells), "counts": _summarize(plan)}


def valheim_matrix_checkout(client: str = "unknown", lease_seconds: float = 900.0) -> dict:
    """Assign the next pending cell to `client`. Returns the cell, or an idle/done status."""
    with _lock:
        plan = _load_plan()
        if plan is None:
            return {"status": "no_plan", "detail": "Seed the matrix first via valheim_matrix_seed."}

        now = time.time()
        _reclaim_stale(plan, now, lease_seconds)

        for cell in plan.get("cells", []):
            if cell.get("status") == "pending":
                cell["status"] = "assigned"
                cell["client"] = client
                cell["assigned_at"] = now
                _save_plan(plan)
                return {"status": "assigned", "cell": {k: cell[k] for k in (
                    "cell_id", "density_band", "observer_range", "event_profile",
                    "x", "z", "observer_offset_m", "benchmark_seconds")}}

        counts = _summarize(plan)
        # Nothing pending: either everything is done, or peers are still finishing.
        return {"status": "done" if counts.get("assigned", 0) == 0 else "idle", "counts": counts}


def valheim_matrix_report(client: str = "unknown", cell_id: str = "", metrics: Optional[dict] = None) -> dict:
    """Mark a cell done and append the reported benchmark metrics to the results log."""
    with _lock:
        plan = _load_plan()
        if plan is None:
            return {"ok": False, "detail": "no plan"}

        matched = None
        for cell in plan.get("cells", []):
            if cell.get("cell_id") == cell_id:
                matched = cell
                break
        if matched is None:
            return {"ok": False, "detail": f"unknown cell_id {cell_id}"}

        matched["status"] = "done"
        matched["done_at"] = time.time()
        _save_plan(plan)

        _VAR_DIR.mkdir(parents=True, exist_ok=True)
        row = {
            "reported_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "client": client,
            "cell_id": cell_id,
            "density_band": matched.get("density_band"),
            "observer_range": matched.get("observer_range"),
            "event_profile": matched.get("event_profile"),
            "metrics": metrics or {},
        }
        with _RESULTS_PATH.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(row) + "\n")

        return {"ok": True, "cell_id": cell_id, "counts": _summarize(plan)}


def valheim_matrix_status() -> dict:
    """Report matrix progress: counts by status and per-client assignment."""
    with _lock:
        plan = _load_plan()
        if plan is None:
            return {"status": "no_plan"}
        by_client: dict[str, dict[str, int]] = {}
        for cell in plan.get("cells", []):
            c = cell.get("client") or "unassigned"
            slot = by_client.setdefault(c, {"assigned": 0, "done": 0})
            if cell.get("status") in slot:
                slot[cell["status"]] += 1
        return {
            "status": "ok",
            "generated_at": plan.get("generated_at"),
            "total_cells": len(plan.get("cells", [])),
            "counts": _summarize(plan),
            "by_client": by_client,
            "results_log": str(_RESULTS_PATH),
        }


def _load_modeled_baseline() -> dict:
    """Modeled backstop, filtered to the baseline slice, keyed density.observer.profile."""
    out: dict = {}
    if not _MODELED_CSV.exists():
        return out
    try:
        with _MODELED_CSV.open(newline="", encoding="utf-8") as handle:
            for row in csv.DictReader(handle):
                if any(row.get(k) != v for k, v in _BASELINE_SLICE.items()):
                    continue
                key = f"{row.get('density_band')}.{row.get('observer_range')}.{row.get('event_profile')}"
                out[key] = row
    except OSError:
        pass
    return out


def _load_measured_by_cell() -> dict:
    """Aggregate the collected client reports (results.jsonl) per cell_id."""
    agg: dict = {}
    if not _RESULTS_PATH.exists():
        return agg
    try:
        lines = _RESULTS_PATH.read_text(encoding="utf-8").splitlines()
    except OSError:
        return agg
    for line in lines:
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        cid = row.get("cell_id")
        if not cid:
            continue
        metrics = row.get("metrics") or {}
        slot = agg.setdefault(cid, {"reports": 0, "bytes_out": [], "load_time": [], "fps": [], "rtt": []})
        slot["reports"] += 1
        for src, dst in (("bytes_out_per_sec", "bytes_out"), ("load_time_ms", "load_time"),
                         ("avg_fps", "fps"), ("p95_rtt_ms", "rtt")):
            val = metrics.get(src)
            if isinstance(val, (int, float)):
                slot[dst].append(float(val))
    return agg


def _server_context() -> dict:
    """Latest server-side heartbeat = the global measured server baseline."""
    if not _SERVER_TELEMETRY.exists():
        return {"available": False}
    last = None
    try:
        for line in _SERVER_TELEMETRY.read_text(encoding="utf-8").splitlines():
            if "server_heartbeat" in line:
                last = line
    except OSError:
        return {"available": False}
    if not last:
        return {"available": False}
    try:
        h = json.loads(last)
    except json.JSONDecodeError:
        return {"available": False}
    return {
        "available": True,
        "timestamp_utc": h.get("timestamp_utc"),
        "region_player_count": h.get("region_player_count"),
        "bytes_sent_per_sec": h.get("bytes_sent_per_sec"),
        "messages_sent_per_sec": h.get("messages_sent_per_sec"),
        "world_zdos": h.get("region_entity_count"),
    }


def valheim_matrix_baseline() -> dict:
    """Matrix-on-matrix: join the modeled pressure-matrix baseline slice with collected
    server + client measurements. Per cell: modeled estimate, measured value, delta, and
    whether it is covered. The wide known backstop before inviting real players."""
    modeled = _load_modeled_baseline()
    if not modeled:
        return {"ok": False, "detail": f"modeled matrix not found at {_MODELED_CSV}"}
    measured = _load_measured_by_cell()

    cells = []
    covered = 0
    ratios = []
    for key in sorted(modeled):
        row = modeled[key]
        est_kbps = float(row.get("estimated_udp_kbps") or 0.0)
        cell = {
            "cell": key,
            "density_band": row.get("density_band"),
            "observer_range": row.get("observer_range"),
            "event_profile": row.get("event_profile"),
            "modeled": {
                "estimated_udp_kbps": est_kbps,
                "movement_events_per_sec": float(row.get("modeled_movement_events_per_sec") or 0.0),
                "reliable_events_per_sec": float(row.get("modeled_reliable_events_per_sec") or 0.0),
                "total_zdos_500m": int(row.get("total_zdos_500m") or 0),
                "priority_expectation": row.get("priority_expectation"),
            },
            "covered": False,
        }
        m = measured.get(key)
        if m and m["reports"] > 0:
            covered += 1
            meas_kbps = round(mean(m["bytes_out"]) * 8 / 1000, 2) if m["bytes_out"] else None
            cell["covered"] = True
            cell["measured"] = {
                "reports": m["reports"],
                "kbps": meas_kbps,
                "load_time_ms": round(mean(m["load_time"]), 1) if m["load_time"] else None,
                "fps": round(mean(m["fps"]), 1) if m["fps"] else None,
                "rtt_ms": round(mean(m["rtt"]), 1) if m["rtt"] else None,
            }
            if meas_kbps is not None and est_kbps > 0:
                ratio = meas_kbps / est_kbps
                ratios.append(ratio)
                cell["delta"] = {
                    "kbps_measured_minus_modeled": round(meas_kbps - est_kbps, 2),
                    "kbps_ratio": round(ratio, 3),
                }
        cells.append(cell)

    total = len(modeled)
    return {
        "ok": True,
        "modeled_csv": str(_MODELED_CSV),
        "baseline_slice": _BASELINE_SLICE,
        "modeled_cells": total,
        "covered_cells": covered,
        "coverage_pct": round(100 * covered / total, 1) if total else 0.0,
        "mean_kbps_ratio_measured_over_modeled": round(mean(ratios), 3) if ratios else None,
        "server_context": _server_context(),
        "cells": cells,
    }


def get_tools() -> list[Callable]:
    return [
        valheim_matrix_seed,
        valheim_matrix_checkout,
        valheim_matrix_report,
        valheim_matrix_status,
        valheim_matrix_baseline,
    ]
