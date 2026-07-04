"""Valheim/ComfyNetworkSense development tools.

These tools read local files only. They do not connect to Valheim, mutate the
world, or require the game to be running.
"""

from __future__ import annotations

import json
import os
import time
from pathlib import Path
from statistics import mean
from typing import Callable

from comfy_gateway.toolsurface.inference import local_generate

DEFAULT_VALHEIM_DIR = Path(os.environ.get(
    "COMFY_VALHEIM_DIR",
    r"C:\Program Files (x86)\Steam\steamapps\common\Valheim",
))
NETWORK_SENSE_DIR = Path(os.environ.get(
    "COMFY_NETWORK_SENSE_DIR",
    str(DEFAULT_VALHEIM_DIR / "BepInEx" / "config" / "comfy-network-sense"),
))
BEPINEX_LOG = Path(os.environ.get(
    "COMFY_BEPINEX_LOG",
    str(DEFAULT_VALHEIM_DIR / "BepInEx" / "LogOutput.log"),
))
NETWORK_SENSE_CFG = Path(os.environ.get(
    "COMFY_NETWORK_SENSE_CFG",
    str(DEFAULT_VALHEIM_DIR / "BepInEx" / "config" / "djcdevelopment.valheim.comfynetworksense.cfg"),
))
MAX_TAIL_LINES = 200
DEV_NOTES_PATH = Path(os.environ.get(
    "COMFY_VALHEIM_NOTES",
    str(Path(__file__).resolve().parents[3] / "var" / "valheim-dev-notes.jsonl"),
))


def _safe_child(root: Path, file_name: str) -> Path:
    if not file_name or Path(file_name).name != file_name:
        raise ValueError("file_name must be a plain file name")
    path = (root / file_name).resolve()
    root_resolved = root.resolve()
    if path.parent != root_resolved:
        raise ValueError("file_name must stay inside the NetworkSense directory")
    return path


def _tail_lines(path: Path, limit: int) -> list[str]:
    if limit <= 0:
        raise ValueError("limit must be positive")
    limit = min(limit, MAX_TAIL_LINES)
    if not path.exists():
        return []
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    return lines[-limit:]


def _tail_json(path: Path, limit: int) -> list[dict]:
    entries = []
    for line in _tail_lines(path, limit):
        try:
            entries.append(json.loads(line))
        except json.JSONDecodeError:
            entries.append({"_parse_error": True, "raw": line[:500]})
    return entries


def _file_info(path: Path) -> dict:
    if not path.exists():
        return {"exists": False, "path": str(path)}
    stat = path.stat()
    return {
        "exists": True,
        "path": str(path),
        "bytes": stat.st_size,
        "modified_utc": stat.st_mtime,
    }


def valheim_networksense_files() -> dict:
    """List ComfyNetworkSense telemetry files and sizes."""
    root = NETWORK_SENSE_DIR
    files = []
    if root.exists():
      files = [
          {
              "name": path.name,
              "bytes": path.stat().st_size,
              "modified_utc": path.stat().st_mtime,
          }
          for path in sorted(root.iterdir())
          if path.is_file()
      ]
    return {
        "network_sense_dir": str(root),
        "exists": root.exists(),
        "files": files,
        "bepinex_log": _file_info(BEPINEX_LOG),
    }


def valheim_tail_networksense(file_name: str = "telemetry-client.jsonl", lines: int = 20) -> dict:
    """Tail a ComfyNetworkSense JSONL file by plain file name."""
    path = _safe_child(NETWORK_SENSE_DIR, file_name)
    return {
        "file": str(path),
        "entries": _tail_json(path, lines),
    }


def valheim_tail_bepinex_log(lines: int = 80, filter_text: str = "ComfyNetworkSense") -> dict:
    """Tail BepInEx LogOutput.log, optionally filtering lines by text."""
    raw_lines = _tail_lines(BEPINEX_LOG, lines)
    if filter_text:
        raw_lines = [line for line in raw_lines if filter_text.lower() in line.lower()]
    return {"file": str(BEPINEX_LOG), "lines": raw_lines}


def valheim_networksense_report(sample_count: int = 30) -> dict:
    """Build a compact report from recent NetworkSense telemetry and events."""
    sample_count = max(1, min(sample_count, MAX_TAIL_LINES))
    samples = _tail_json(NETWORK_SENSE_DIR / "telemetry-client.jsonl", sample_count)
    events = _tail_json(NETWORK_SENSE_DIR / "event-timeline.jsonl", 20)
    benchmarks = _tail_json(NETWORK_SENSE_DIR / "benchmark-results.jsonl", 5)
    server = _tail_json(NETWORK_SENSE_DIR / "telemetry-server.jsonl", 5)

    valid_samples = [entry for entry in samples if not entry.get("_parse_error")]
    latest = valid_samples[-1] if valid_samples else {}

    def values(name: str) -> list[float]:
        result = []
        for entry in valid_samples:
            value = entry.get(name)
            if isinstance(value, (int, float)):
                result.append(float(value))
        return result

    fps = values("fps")
    p95 = values("frame_time_p95_ms")
    rtt = values("rtt_ms")
    cpu = values("cpu_bound_estimate")

    return {
        "network_sense_dir": str(NETWORK_SENSE_DIR),
        "sample_count": len(valid_samples),
        "latest": latest,
        "averages": {
            "fps": round(mean(fps), 3) if fps else None,
            "frame_time_p95_ms": round(mean(p95), 3) if p95 else None,
            "rtt_ms": round(mean(rtt), 3) if rtt else None,
            "cpu_bound_estimate": round(mean(cpu), 3) if cpu else None,
        },
        "latest_events": events[-8:],
        "latest_benchmark": benchmarks[-1] if benchmarks else None,
        "server_pulse_available": bool(server),
        "latest_server_pulse": server[-1] if server else None,
    }


def _all_json(file_name: str, max_entries: int = 5000) -> list[dict]:
    path = _safe_child(NETWORK_SENSE_DIR, file_name)
    if not path.exists():
        return []
    entries = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines()[-max_entries:]:
        if not line.strip():
            continue
        try:
            entries.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return entries


def _session_id(entry: dict) -> str:
    return str(entry.get("session_id") or "")


def _latest_session_id() -> str:
    samples = _all_json("telemetry-client.jsonl", max_entries=5000)
    for entry in reversed(samples):
        session_id = _session_id(entry)
        if session_id:
            return session_id
    return ""


def valheim_mcp_health() -> dict:
    """Return Comfy gateway health inputs: paths, files, and Ollama endpoint."""
    ollama_endpoint = os.environ.get("COMFY_OLLAMA", "http://127.0.0.1:11434")
    return {
        "ok": True,
        "network_sense_dir": _file_info(NETWORK_SENSE_DIR),
        "bepinex_log": _file_info(BEPINEX_LOG),
        "notes_path": str(DEV_NOTES_PATH),
        "ollama_endpoint": ollama_endpoint,
        "tools": [
            "valheim_networksense_files",
            "valheim_networksense_report",
            "valheim_session_bundle",
            "valheim_compare_clients",
            "valheim_suggest_next_test",
            "valheim_suggest_config",
        ],
    }


def valheim_list_sessions() -> dict:
    """List known NetworkSense session IDs with basic counts."""
    counts: dict[str, dict] = {}
    for file_name, key in [
        ("telemetry-client.jsonl", "client_samples"),
        ("telemetry-server.jsonl", "server_pulses"),
        ("event-timeline.jsonl", "events"),
        ("benchmark-results.jsonl", "benchmarks"),
    ]:
        for entry in _all_json(file_name):
            session_id = _session_id(entry)
            if not session_id:
                continue
            record = counts.setdefault(session_id, {
                "session_id": session_id,
                "client_samples": 0,
                "server_pulses": 0,
                "events": 0,
                "benchmarks": 0,
                "first_timestamp_utc": entry.get("timestamp_utc"),
                "last_timestamp_utc": entry.get("timestamp_utc"),
            })
            record[key] += 1
            timestamp = entry.get("timestamp_utc")
            if timestamp:
                record["first_timestamp_utc"] = min(record["first_timestamp_utc"] or timestamp, timestamp)
                record["last_timestamp_utc"] = max(record["last_timestamp_utc"] or timestamp, timestamp)
    sessions = sorted(counts.values(), key=lambda item: item.get("last_timestamp_utc") or "")
    return {"sessions": sessions, "latest_session_id": sessions[-1]["session_id"] if sessions else ""}


def valheim_session_bundle(session_id: str = "latest", max_entries: int = 500) -> dict:
    """Collect telemetry/events/benchmarks/server pulses for one NetworkSense session."""
    if session_id == "latest":
        session_id = _latest_session_id()
    if not session_id:
        return {"session_id": "", "error": "no NetworkSense session found"}

    max_entries = max(1, min(max_entries, 2000))

    def matching(file_name: str) -> list[dict]:
        return [entry for entry in _all_json(file_name, max_entries=5000) if _session_id(entry) == session_id][-max_entries:]

    client_samples = matching("telemetry-client.jsonl")
    server_pulses = matching("telemetry-server.jsonl")
    events = matching("event-timeline.jsonl")
    benchmarks = matching("benchmark-results.jsonl")
    return {
        "session_id": session_id,
        "client_samples": client_samples,
        "server_pulses": server_pulses,
        "events": events,
        "benchmarks": benchmarks,
        "summary": {
            "client_samples": len(client_samples),
            "server_pulses": len(server_pulses),
            "events": len(events),
            "benchmarks": len(benchmarks),
            "latest_client_sample": client_samples[-1] if client_samples else None,
            "latest_server_pulse": server_pulses[-1] if server_pulses else None,
            "latest_benchmark": benchmarks[-1] if benchmarks else None,
        },
    }


def _avg(entries: list[dict], key: str) -> float | None:
    values = [float(entry[key]) for entry in entries if isinstance(entry.get(key), (int, float))]
    return round(mean(values), 3) if values else None


def valheim_compare_clients(host_bundle: dict, client_bundle: dict) -> dict:
    """Compare two session bundles from host/client multiplayer tests."""
    host_samples = host_bundle.get("client_samples") or []
    client_samples = client_bundle.get("client_samples") or []
    host_summary = {
        "session_id": host_bundle.get("session_id"),
        "samples": len(host_samples),
        "server_pulses": len(host_bundle.get("server_pulses") or []),
        "avg_fps": _avg(host_samples, "fps"),
        "avg_rtt_ms": _avg(host_samples, "rtt_ms"),
        "avg_cpu_bound": _avg(host_samples, "cpu_bound_estimate"),
    }
    client_summary = {
        "session_id": client_bundle.get("session_id"),
        "samples": len(client_samples),
        "server_pulses": len(client_bundle.get("server_pulses") or []),
        "avg_fps": _avg(client_samples, "fps"),
        "avg_rtt_ms": _avg(client_samples, "rtt_ms"),
        "avg_cpu_bound": _avg(client_samples, "cpu_bound_estimate"),
    }
    findings = []
    if host_summary["server_pulses"] <= 0:
        findings.append("host bundle has no server pulses")
    if client_summary["server_pulses"] <= 0:
        findings.append("client bundle has no received server pulses")
    if host_summary["avg_fps"] is not None and client_summary["avg_fps"] is not None:
        fps_delta = round(abs(host_summary["avg_fps"] - client_summary["avg_fps"]), 3)
        if fps_delta >= 10:
            findings.append(f"large average FPS delta: {fps_delta}")
    if client_summary["avg_rtt_ms"] in (None, 0):
        findings.append("client RTT is missing or zero; verify connected multiplayer session")
    return {"host": host_summary, "client": client_summary, "findings": findings}


def valheim_suggest_next_test(sample_count: int = 30) -> dict:
    """Recommend the next practical in-game test from deterministic telemetry signals."""
    report = valheim_networksense_report(sample_count=sample_count)
    latest = report.get("latest") or {}
    suggestions = []
    if not report.get("server_pulse_available"):
        suggestions.append("Invite one modded client or join a dedicated server to validate server pulse delivery.")
    if latest.get("nearby_build_pieces", 0) < 25:
        suggestions.append("Move into a denser base area and rerun benchmark to collect build-density pressure data.")
    if latest.get("rtt_ms", 0) == 0:
        suggestions.append("Run a non-local multiplayer test to capture real RTT and packet counters.")
    if not report.get("latest_benchmark"):
        suggestions.append("Run network_sense_benchmark and wait 15 seconds for a baseline.")
    if not suggestions:
        suggestions.append("Run a two-player host/client session and compare bundles with valheim_compare_clients.")
    return {"report": report, "suggestions": suggestions}


def valheim_suggest_config(sample_count: int = 30) -> dict:
    """Suggest safe config changes without applying them."""
    report = valheim_networksense_report(sample_count=sample_count)
    latest = report.get("latest") or {}
    recommendations = []
    if latest.get("nearby_entities", 0) >= 25 or latest.get("nearby_build_pieces", 0) >= 200:
        recommendations.append({"key": "liveSampleIntervalSeconds", "value": 1.0, "reason": "reduce JSONL volume in dense scenes"})
    else:
        recommendations.append({"key": "liveSampleIntervalSeconds", "value": 0.5, "reason": "keep default fine-grained dev sampling"})
    if not report.get("server_pulse_available"):
        recommendations.append({"key": "serverPulseIntervalSeconds", "value": 2.0, "reason": "faster feedback during multiplayer pulse validation"})
    recommendations.append({"key": "writeTelemetryLogs", "value": True, "reason": "keep file-first evidence during development"})
    return {"report": report, "recommendations": recommendations, "applied": False}


CONFIG_PROFILES = {
    "default_dev": {
        "liveSampleIntervalSeconds": "0.5",
        "serverPulseIntervalSeconds": "3",
        "writeTelemetryLogs": "true",
    },
    "dense_base": {
        "liveSampleIntervalSeconds": "1",
        "serverPulseIntervalSeconds": "3",
        "writeTelemetryLogs": "true",
    },
    "multiplayer_pulse": {
        "liveSampleIntervalSeconds": "0.5",
        "serverPulseIntervalSeconds": "2",
        "writeTelemetryLogs": "true",
    },
}


def valheim_apply_config_profile(profile: str = "default_dev") -> dict:
    """Apply a whitelisted NetworkSense config profile to the BepInEx cfg file."""
    if profile not in CONFIG_PROFILES:
        return {
            "ok": False,
            "error": f"unknown profile {profile!r}",
            "available_profiles": sorted(CONFIG_PROFILES),
        }
    if not NETWORK_SENSE_CFG.exists():
        return {"ok": False, "error": "NetworkSense cfg not found", "path": str(NETWORK_SENSE_CFG)}

    text = NETWORK_SENSE_CFG.read_text(encoding="utf-8", errors="replace")
    changes = []
    for key, value in CONFIG_PROFILES[profile].items():
        prefix = f"{key} = "
        lines = text.splitlines()
        replaced = False
        for index, line in enumerate(lines):
            if line.startswith(prefix):
                old = line[len(prefix):]
                lines[index] = prefix + value
                replaced = True
                changes.append({"key": key, "old": old, "new": value})
                break
        if replaced:
            text = "\n".join(lines) + "\n"
    NETWORK_SENSE_CFG.write_text(text, encoding="utf-8")
    return {
        "ok": True,
        "profile": profile,
        "path": str(NETWORK_SENSE_CFG),
        "changes": changes,
        "next_step": "Run network_sense_reload_config in Valheim.",
    }


def valheim_record_note(text: str, tags: list[str] | None = None) -> dict:
    """Append a developer note to network/mcp/var/valheim-dev-notes.jsonl."""
    if not isinstance(text, str) or not text.strip():
        raise ValueError("text must be a non-empty string")
    tags = tags or []
    if not isinstance(tags, list) or any(not isinstance(tag, str) for tag in tags):
        raise ValueError("tags must be a list of strings")
    DEV_NOTES_PATH.parent.mkdir(parents=True, exist_ok=True)
    entry = {
        "timestamp_unix": time.time(),
        "text": text.strip(),
        "tags": tags,
        "latest_session_id": _latest_session_id(),
    }
    with DEV_NOTES_PATH.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(entry, ensure_ascii=False) + "\n")
    return {"ok": True, "path": str(DEV_NOTES_PATH), "entry": entry}


def valheim_explain_networksense(sample_count: int = 30, model: str = "qwen3-coder:30b") -> dict:
    """Ask local Ollama for a short explanation of the latest NetworkSense report."""
    report = valheim_networksense_report(sample_count=sample_count)
    prompt = (
        "You are helping debug a local Valheim BepInEx mod named ComfyNetworkSense. "
        "Explain the telemetry in 5 concise bullets. Call out likely causes, missing data, "
        "and the next useful command or test. Do not suggest productionizing MCP.\n\n"
        + json.dumps(report, ensure_ascii=False, indent=2)[:12000]
    )
    result = local_generate(
        prompt=prompt,
        model=model,
        system="You are a pragmatic game networking/tools engineer. Be concrete and concise.",
        max_tokens=700,
        timeout_s=120,
    )
    return {"report": report, "explanation": result}


def get_tools() -> list[Callable]:
    return [
        valheim_mcp_health,
        valheim_networksense_files,
        valheim_tail_networksense,
        valheim_tail_bepinex_log,
        valheim_networksense_report,
        valheim_explain_networksense,
        valheim_list_sessions,
        valheim_session_bundle,
        valheim_compare_clients,
        valheim_suggest_next_test,
        valheim_suggest_config,
        valheim_apply_config_profile,
        valheim_record_note,
    ]
