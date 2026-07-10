"""Valheim/ComfyNetworkSense development tools.

These tools read local files only. They do not connect to Valheim, mutate the
world, or require the game to be running.
"""

from __future__ import annotations

import hashlib
import json
import os
import shlex
import subprocess
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
AUTONOMOUS_STATE = Path(os.environ.get(
    "COMFY_AUTONOMOUS_STATE",
    "",
))

# --- am4 dedicated server (netcode probe source of record) ---------------------------
# The headless Valheim server runs on am4 (native Linux Docker, tailnet). Its probe jsonl
# and container logs are read over key-based ssh (BatchMode: never prompts, fails fast).
AM4_SSH_HOST = os.environ.get("COMFY_AM4_SSH", "derek@am4")
AM4_CONTAINER = os.environ.get(
    "COMFY_AM4_CONTAINER", "comfy-valheim-server-am4-valheim-server-1",
)
AM4_PROBE_PATH = os.environ.get(
    "COMFY_AM4_PROBE_PATH",
    "~/comfy-valheim-lab/server-state/config/bepinex/comfy-network-sense/netcode-probe.jsonl",
)
NETCODE_PROBE_FILE = "netcode-probe.jsonl"
SSH_TIMEOUT_S = int(os.environ.get("COMFY_SSH_TIMEOUT_S", "20"))
# Counter fields the probe emits only on an authoritative lifecycle stop/status row.
_PROBE_COUNTER_KEYS = (
    "recv_funnel_calls", "recv_zdo_rows", "recv_parse_errors",
    "send_zdos_calls", "send_zdos_flushed", "create_sync_list_calls", "send_zdo_rows",
)
# Default filter for server log tail: peer join/connect + probe lifecycle lines.
_SERVER_LOG_DEFAULT_FILTER = "join|peer|connect|Netcode probe|ComfyNetworkSense"


def _run_ssh(remote_cmd: str, timeout_s: int = SSH_TIMEOUT_S) -> tuple[int, str, str]:
    """Run a command on am4 over key-based ssh. BatchMode => no password prompt / no hang."""
    proc = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", AM4_SSH_HOST, remote_cmd],
        capture_output=True, text=True, timeout=timeout_s,
    )
    return proc.returncode, proc.stdout, proc.stderr


def _parse_jsonl_text(text: str) -> list[dict]:
    entries = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entries.append(json.loads(line))
        except json.JSONDecodeError:
            entries.append({"_parse_error": True, "raw": line[:500]})
    return entries


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


def _client_name(client: str) -> str:
    value = str(client or "").strip().lower()
    if value.isdigit():
        number = int(value)
        if 1 <= number <= 99:
            return f"client{number:02d}"
    if value.startswith("client") and len(value) == 8 and value[6:].isdigit():
        number = int(value[6:])
        if 1 <= number <= 99:
            return f"client{number:02d}"
    raise ValueError("client must be a number or clientNN")


def _client_install_dir(client: str) -> Path:
    if not str(AUTONOMOUS_STATE):
        raise ValueError("COMFY_AUTONOMOUS_STATE is not configured")
    name = _client_name(client)
    return AUTONOMOUS_STATE / name / "games" / "GameLibrary" / "Steam" / "steamapps" / "common" / "Valheim"


def _client_networksense_dir(client: str) -> Path:
    return _client_install_dir(client) / "BepInEx" / "config" / "comfy-network-sense"


def valheim_swarm_clients(max_clients: int = 4) -> dict:
    """List autonomous lab clients and their NetworkSense telemetry paths."""
    max_clients = max(1, min(int(max_clients), 16))
    clients = []
    for index in range(1, max_clients + 1):
        name = f"client{index:02d}"
        install_dir = _client_install_dir(name)
        network_dir = _client_networksense_dir(name)
        descriptor = AUTONOMOUS_STATE / name / "home" / ".comfy" / "player.json"
        clients.append({
            "client": name,
            "install": _file_info(install_dir),
            "network_sense_dir": _file_info(network_dir),
            "bepinex_log": _file_info(install_dir / "BepInEx" / "LogOutput.log"),
            "player_descriptor": _file_info(descriptor),
            "no_vnc_url": f"http://127.0.0.1:{8080 + index}",
        })
    return {
        "autonomous_state": str(AUTONOMOUS_STATE),
        "clients": clients,
    }


def valheim_tail_swarm_client(client: str = "client01", file_name: str = "telemetry-client.jsonl", lines: int = 20) -> dict:
    """Tail a NetworkSense JSONL file for one autonomous swarm client."""
    root = _client_networksense_dir(client)
    path = _safe_child(root, file_name)
    return {
        "client": _client_name(client),
        "file": str(path),
        "entries": _tail_json(path, lines),
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
        "netcode_probe_local": _file_info(NETWORK_SENSE_DIR / NETCODE_PROBE_FILE),
        "notes_path": str(DEV_NOTES_PATH),
        "ollama_endpoint": ollama_endpoint,
        "am4": {"ssh_host": AM4_SSH_HOST, "container": AM4_CONTAINER, "probe_path": AM4_PROBE_PATH},
        "tools": [
            "valheim_networksense_files",
            "valheim_swarm_clients",
            "valheim_tail_swarm_client",
            "valheim_networksense_report",
            "valheim_session_bundle",
            "valheim_compare_clients",
            "valheim_suggest_next_test",
            "valheim_suggest_config",
            "valheim_tail_netcode_probe",
            "valheim_netcode_probe_summary",
            "valheim_server_log_tail",
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
    "baseline_route": {
        "liveSampleIntervalSeconds": "0.5",
        "serverPulseIntervalSeconds": "2",
        "benchmarkDurationSeconds": "60",
        "writeTelemetryLogs": "true",
    },
    "autonomous_route": {
        "liveSampleIntervalSeconds": "0.5",
        "serverPulseIntervalSeconds": "2",
        "benchmarkDurationSeconds": "60",
        "writeTelemetryLogs": "true",
        "autoRehearsalEnabled": "true",
        "autoRehearsalRouteFile": "teleport-route.tsv",
        "autoRehearsalProfile": "host_full",
        "autoRehearsalDelaySeconds": "20",
        "autoRehearsalRunOncePerSession": "true",
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


def valheim_tail_netcode_probe(source: str = "local", lines: int = 20) -> dict:
    """Tail the I1 netcode-probe.jsonl. source='local' (OMEN client) or 'am4' (server via ssh)."""
    source = str(source or "").strip().lower()
    lines = max(1, min(int(lines), 2000))
    if source == "local":
        path = _safe_child(NETWORK_SENSE_DIR, NETCODE_PROBE_FILE)
        return {
            "source": "local",
            "file": str(path),
            "exists": path.exists(),
            "entries": _tail_json(path, lines),
        }
    if source == "am4":
        try:
            rc, out, err = _run_ssh(f"tail -n {lines} {AM4_PROBE_PATH}")
        except subprocess.TimeoutExpired:
            return {"source": "am4", "ok": False, "error": "ssh timeout",
                    "ssh_host": AM4_SSH_HOST, "remote_path": AM4_PROBE_PATH}
        except FileNotFoundError:
            return {"source": "am4", "ok": False, "error": "ssh client not found on PATH"}
        if rc != 0:
            return {"source": "am4", "ok": False, "error": err.strip() or f"ssh exit {rc}",
                    "ssh_host": AM4_SSH_HOST, "remote_path": AM4_PROBE_PATH}
        return {
            "source": "am4",
            "ok": True,
            "ssh_host": AM4_SSH_HOST,
            "remote_path": AM4_PROBE_PATH,
            "entries": _parse_jsonl_text(out),
        }
    raise ValueError("source must be 'local' or 'am4'")


def _summarize_probe_rows(rows: list[dict]) -> dict:
    """Scope to the latest start->end window and read authoritative counters.

    Counters live ONLY on a lifecycle stop/status row (finite autostop). If none landed in
    the window, the true totals were never emitted: we report per-detail-row FALLBACK counts
    and mark unmeasured fields null — never a fabricated zero the caller could mistake for a
    measurement.
    """
    # jsonl is append-only, so file order is chronological: find the last 'start' by index.
    start_idx = None
    for index, row in enumerate(rows):
        if str(row.get("event")) == "start":
            start_idx = index
    window = rows[start_idx:] if start_idx is not None else rows

    summary_row = None
    for row in window:
        if str(row.get("event")) in ("stop", "status") and any(k in row for k in _PROBE_COUNTER_KEYS):
            summary_row = row  # last one wins

    zdo_rows = [r for r in window if str(r.get("event")) == "zdo"]
    recv_detail = sum(1 for r in zdo_rows if str(r.get("dir")) == "recv")
    send_detail = sum(1 for r in zdo_rows if str(r.get("dir")) == "send")

    if summary_row is not None:
        def _c(key: str) -> int:
            value = summary_row.get(key)
            return int(value) if isinstance(value, (int, float)) else 0
        counters = {key: _c(key) for key in _PROBE_COUNTER_KEYS}
        authoritative = True
        caveat = None
    else:
        # Fallback: only the pre-cap detail rows are trustworthy as a FLOOR. Everything the
        # stop-row would have carried (funnel calls, parse errors, send counters) is unknown.
        counters = {key: None for key in _PROBE_COUNTER_KEYS}
        counters["recv_zdo_rows"] = recv_detail
        counters["send_zdo_rows"] = send_detail
        authoritative = False
        caveat = ("No lifecycle stop/status row in window: counters are a FLOOR from detail "
                  "rows, not measured totals. null fields were never emitted (set a finite "
                  "netcodeProbeAutoStopSeconds to get authoritative counts). Not a PASS.")

    return {
        "has_lifecycle_summary": summary_row is not None,
        "counters_are_authoritative": authoritative,
        "counters": counters,
        "detail_rows": {"recv": recv_detail, "send": send_detail, "window_rows": len(window)},
        "window": {
            "has_start": start_idx is not None,
            "start_row": window[0] if (start_idx is not None and window) else None,
        },
        "caveat": caveat,
    }


def valheim_netcode_probe_summary(source: str = "local") -> dict:
    """Summarize the netcode probe (I1), explicitly labeling fallback-mode counters.

    A summary with counters_are_authoritative=false is NOT a measurement and must never be
    reported as a PASS. Provenance (host + sha256 + size) is recorded so stale/copied data is
    visible. source='local' (OMEN client) or 'am4' (server via ssh).
    """
    source = str(source or "").strip().lower()
    if source == "local":
        path = _safe_child(NETWORK_SENSE_DIR, NETCODE_PROBE_FILE)
        if not path.exists():
            return {"source": "local", "ok": False, "error": "netcode-probe.jsonl not found",
                    "path": str(path)}
        raw = path.read_text(encoding="utf-8", errors="replace")
        rows = _parse_jsonl_text(raw)
        stat = path.stat()
        provenance = {
            "host": "local",
            "path": str(path),
            "sha256": hashlib.sha256(raw.encode("utf-8", "replace")).hexdigest(),
            "size_bytes": stat.st_size,
            "modified_utc": stat.st_mtime,
            "age_seconds": round(time.time() - stat.st_mtime, 1),
        }
        result = {"source": "local", "ok": True, "provenance": provenance}
        result.update(_summarize_probe_rows(rows))
        return result
    if source == "am4":
        # One round-trip: PROV header (sha256 size mtime now) then the file body.
        remote = (
            f"F={AM4_PROBE_PATH}; "
            f"echo PROV $(sha256sum \"$F\" | cut -d' ' -f1) $(stat -c '%s %Y' \"$F\") $(date +%s); "
            f"tail -n 100000 \"$F\""
        )
        try:
            rc, out, err = _run_ssh(remote, timeout_s=max(SSH_TIMEOUT_S, 40))
        except subprocess.TimeoutExpired:
            return {"source": "am4", "ok": False, "error": "ssh timeout", "ssh_host": AM4_SSH_HOST}
        except FileNotFoundError:
            return {"source": "am4", "ok": False, "error": "ssh client not found on PATH"}
        if rc != 0:
            return {"source": "am4", "ok": False, "error": err.strip() or f"ssh exit {rc}",
                    "ssh_host": AM4_SSH_HOST, "remote_path": AM4_PROBE_PATH}
        body_lines = out.splitlines()
        provenance = {"host": AM4_SSH_HOST, "remote_path": AM4_PROBE_PATH}
        if body_lines and body_lines[0].startswith("PROV "):
            parts = body_lines[0].split()
            body_lines = body_lines[1:]
            try:
                sha, size, mtime, now = parts[1], int(parts[2]), int(parts[3]), int(parts[4])
                provenance.update({
                    "sha256": sha,
                    "size_bytes": size,
                    "modified_unix": mtime,
                    "age_seconds": now - mtime,
                })
            except (IndexError, ValueError):
                provenance["prov_parse_error"] = body_lines and parts or None
        rows = _parse_jsonl_text("\n".join(body_lines))
        result = {"source": "am4", "ok": True, "provenance": provenance}
        result.update(_summarize_probe_rows(rows))
        return result
    raise ValueError("source must be 'local' or 'am4'")


def valheim_server_log_tail(lines: int = 80, filter_text: str = "") -> dict:
    """Tail the am4 dedicated-server container logs (join/peer/probe lifecycle lines).

    filter_text overrides the default grep pattern; pass 'ALL' for the unfiltered tail.
    """
    lines = max(1, min(int(lines), 500))
    base = f"docker logs --tail {lines} {AM4_CONTAINER} 2>&1"
    ftext = str(filter_text or "").strip()
    if ftext.upper() == "ALL":
        remote = base
        pattern = None
    else:
        pattern = ftext or _SERVER_LOG_DEFAULT_FILTER
        remote = f"{base} | grep -iE {shlex.quote(pattern)}"
    try:
        rc, out, err = _run_ssh(remote)
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "ssh timeout", "ssh_host": AM4_SSH_HOST}
    except FileNotFoundError:
        return {"ok": False, "error": "ssh client not found on PATH"}
    # grep exits 1 on no-match: that's not an error, just an empty result.
    if rc not in (0, 1):
        return {"ok": False, "error": err.strip() or f"ssh exit {rc}",
                "ssh_host": AM4_SSH_HOST, "container": AM4_CONTAINER}
    return {
        "ok": True,
        "ssh_host": AM4_SSH_HOST,
        "container": AM4_CONTAINER,
        "filter": pattern,
        "lines": [line for line in out.splitlines() if line.strip()],
    }


# --- Save integrity (P3+ HARD gate) ---------------------------------------------------
# Fingerprint the am4 world's STRUCTURAL state so a quit->reload can be verified intact.
# Uses the server load-log's semantic counts (ZDOs / portals / spawners / locations), which
# survive a save-rewrite (a raw .db hash changes on every save) but DROP on corruption/loss,
# plus the world save-file size/mtime as a reference. Server-authoritative state only; the
# tool reads logs + stats files over ssh and never modifies the world.
SAVE_INTEGRITY_BASELINE = Path(os.environ.get(
    "COMFY_SAVE_INTEGRITY_BASELINE",
    str(Path(__file__).resolve().parents[3] / "var" / "valheim-save-integrity-baseline.json"),
))
AM4_WORLD_DB = os.environ.get(
    "COMFY_AM4_WORLD_DB",
    "/home/derek/comfy-valheim-lab/server-state/config/worlds_local/ComfyEra16.db",
)
AM4_WORLD_FWL = os.environ.get(
    "COMFY_AM4_WORLD_FWL",
    "/home/derek/comfy-valheim-lab/server-state/config/worlds_local/ComfyEra16.fwl",
)
# Loaded-world geometry counts that must match EXACTLY across a clean reload; ZDOS is the
# live total and gets a small tolerance.
_SAVE_STRUCTURAL_KEYS = ("portals", "spawned", "targets", "locations")
_SAVE_ZDOS_TOLERANCE = 0.01  # 1%


def _last_int(text: str, pattern: str) -> int | None:
    import re
    found = re.findall(pattern, text)
    return int(found[-1]) if found else None


def _capture_world_integrity() -> dict:
    """Fingerprint the am4 world from its most recent load block + save-file stats."""
    fp: dict = {"captured_utc": time.time(), "source": AM4_SSH_HOST,
                "container": AM4_CONTAINER, "ok": False}
    try:
        rc, out, err = _run_ssh(
            f"docker logs --since 48h {AM4_CONTAINER} 2>&1 | "
            f"grep -E 'ZDOS:|ConnectPortals =>|spawned=|Loaded [0-9]+ locations'",
            timeout_s=max(SSH_TIMEOUT_S, 45),
        )
    except subprocess.TimeoutExpired:
        fp["error"] = "ssh timeout reading container logs"
        return fp
    except FileNotFoundError:
        fp["error"] = "ssh client not found on PATH"
        return fp
    if rc not in (0, 1):
        fp["error"] = err.strip() or f"ssh exit {rc}"
        return fp
    fp["zdos"] = _last_int(out, r"ZDOS:(\d+)")
    fp["portals"] = _last_int(out, r"ConnectPortals => Connected (\d+) portals")
    fp["spawned"] = _last_int(out, r"spawned=(\d+)")
    fp["targets"] = _last_int(out, r"targets=(\d+)")
    fp["locations"] = _last_int(out, r"Loaded (\d+) locations")
    try:
        _, sout, _ = _run_ssh(
            f"stat -c '%n|%s|%Y' {shlex.quote(AM4_WORLD_DB)} {shlex.quote(AM4_WORLD_FWL)} 2>/dev/null"
        )
        files: dict = {}
        for line in sout.splitlines():
            parts = line.strip().split("|")
            if len(parts) == 3:
                files[Path(parts[0]).name] = {"bytes": int(parts[1]), "mtime": int(parts[2])}
        fp["world_files"] = files
    except Exception:
        fp["world_files"] = {}
    # zdos is emitted continuously (heartbeat); the geometry counts are boot-only.
    fp["ok"] = fp["zdos"] is not None
    fp["has_load_block"] = fp["locations"] is not None and fp["portals"] is not None
    return fp


def valheim_save_integrity(action: str = "check", label: str = "") -> dict:
    """Fingerprint / verify the am4 world's structural integrity for the P3+ save-integrity gate.

    action='snapshot' captures the current world fingerprint (ZDO/portal/spawner/location
    counts from the server load log + save-file size/mtime) and stores it as the baseline.
    action='check' (default) re-captures and diffs against the baseline: structural counts
    (portals/spawned/targets/locations) must match EXACTLY and ZDOS within 1% -> status 'pass';
    a drop -> 'fail' (possible corruption/loss on reload). action='show' returns the baseline.
    Read-only: reads am4 logs + stats save files over ssh; nothing is modified.
    """
    action = (action or "check").strip().lower()
    if action == "show":
        if SAVE_INTEGRITY_BASELINE.exists():
            return {"ok": True, "action": "show",
                    "baseline": json.loads(SAVE_INTEGRITY_BASELINE.read_text(encoding="utf-8"))}
        return {"ok": True, "action": "show", "baseline": None, "note": "no baseline stored"}

    current = _capture_world_integrity()
    if not current.get("ok"):
        return {"ok": False, "action": action,
                "error": current.get("error", "capture failed"), "current": current}

    if action == "snapshot":
        current["label"] = label or "clean-world baseline"
        SAVE_INTEGRITY_BASELINE.parent.mkdir(parents=True, exist_ok=True)
        SAVE_INTEGRITY_BASELINE.write_text(json.dumps(current, indent=2), encoding="utf-8")
        return {"ok": True, "action": "snapshot", "stored": str(SAVE_INTEGRITY_BASELINE),
                "fingerprint": current}

    if not SAVE_INTEGRITY_BASELINE.exists():
        return {"ok": True, "action": "check", "status": "no_baseline",
                "note": "no baseline stored; run action='snapshot' on a known-good world first",
                "current": current}

    baseline = json.loads(SAVE_INTEGRITY_BASELINE.read_text(encoding="utf-8"))
    drift: dict = {}
    status = "pass"
    for k in _SAVE_STRUCTURAL_KEYS:
        b, c = baseline.get(k), current.get(k)
        if b is None or c is None:
            drift[k] = {"baseline": b, "current": c, "verdict": "missing"}
            status = "warn" if status == "pass" else status
        elif b != c:
            drift[k] = {"baseline": b, "current": c, "delta": c - b, "verdict": "MISMATCH"}
            status = "fail"
        else:
            drift[k] = {"baseline": b, "current": c, "verdict": "ok"}
    b, c = baseline.get("zdos"), current.get("zdos")
    if b and c:
        rel = abs(c - b) / b
        if c < b * (1 - _SAVE_ZDOS_TOLERANCE):
            zv = "MISMATCH"
            status = "fail"
        elif rel > _SAVE_ZDOS_TOLERANCE:
            zv = "warn"
            status = "warn" if status == "pass" else status
        else:
            zv = "ok"
        drift["zdos"] = {"baseline": b, "current": c, "delta": c - b, "rel": round(rel, 4), "verdict": zv}
    else:
        drift["zdos"] = {"baseline": b, "current": c, "verdict": "missing"}
        status = "warn" if status == "pass" else status

    if not current.get("has_load_block"):
        status = "warn" if status == "pass" else status

    return {
        "ok": True, "action": "check", "status": status,
        "baseline_captured_utc": baseline.get("captured_utc"),
        "baseline_label": baseline.get("label"),
        "current_captured_utc": current.get("captured_utc"),
        "has_recent_load_block": current.get("has_load_block"),
        "drift": drift,
        "world_files": {"baseline": baseline.get("world_files"), "current": current.get("world_files")},
        "note": "structural counts must match exactly; ZDOS within 1%. status=fail => possible "
                "corruption/loss on reload. Snapshot on a known-good world, then check after a reload.",
    }


def get_tools() -> list[Callable]:
    return [
        valheim_mcp_health,
        valheim_networksense_files,
        valheim_swarm_clients,
        valheim_tail_swarm_client,
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
        valheim_tail_netcode_probe,
        valheim_netcode_probe_summary,
        valheim_server_log_tail,
        valheim_save_integrity,
    ]
