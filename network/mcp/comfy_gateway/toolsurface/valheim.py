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
import urllib.error
import urllib.parse
import urllib.request
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

# --- dedicated server (netcode probe source of record) -------------------------------
# Defaults retain the proven am4 topology. Environment overrides retarget the same
# read-only evidence surface to the GCP P7 VM without placing MCP in gameplay logic.
AM4_SSH_HOST = os.environ.get("COMFY_AM4_SSH", "derek@am4")
AM4_CONTAINER = os.environ.get(
    "COMFY_AM4_CONTAINER", "comfy-valheim-server-am4-valheim-server-1",
)
AM4_PROBE_PATH = os.environ.get(
    "COMFY_AM4_PROBE_PATH",
    "~/comfy-valheim-lab/server-state/config/bepinex/comfy-network-sense/netcode-probe.jsonl",
)
NETCODE_PROBE_FILE = "netcode-probe.jsonl"
OWNERSHIP_CHURN_FILE = "ownership-churn.jsonl"
AM4_OWNERSHIP_PATH = os.environ.get(
    "COMFY_AM4_OWNERSHIP_PATH",
    AM4_PROBE_PATH.rsplit("/", 1)[0] + "/" + OWNERSHIP_CHURN_FILE,
)
OWNERSHIP_PIN_FILE = "ownership-pin.jsonl"
AM4_OWNERSHIP_PIN_PATH = os.environ.get(
    "COMFY_AM4_OWNERSHIP_PIN_PATH",
    AM4_PROBE_PATH.rsplit("/", 1)[0] + "/" + OWNERSHIP_PIN_FILE,
)
REDIRECT_SEND_FILE = "redirect-send.jsonl"
AM4_REDIRECT_PATH = os.environ.get(
    "COMFY_AM4_REDIRECT_PATH",
    AM4_PROBE_PATH.rsplit("/", 1)[0] + "/" + REDIRECT_SEND_FILE,
)
INJECTION_APPLY_FILE = "injection-apply.jsonl"
# Lumberjacks gateway (P4/I3 receipt counter). Runs on OMEN next to this gateway, so
# localhost by default; the mod on am4 reaches the same service via the tailnet IP.
LUMBERJACKS_URL = os.environ.get("COMFY_LUMBERJACKS_URL", "http://127.0.0.1:4000")
SSH_TIMEOUT_S = int(os.environ.get("COMFY_SSH_TIMEOUT_S", "20"))
# am4 mod config (BepInEx writes it beside the comfy-network-sense/ telemetry dir).
AM4_MOD_CFG = os.environ.get(
    "COMFY_AM4_MOD_CFG",
    "~/comfy-valheim-lab/server-state/config/bepinex/djcdevelopment.valheim.comfynetworksense.cfg",
)
# The mod build that first carries the P6/I5 handshake responder surface. am4 must be at or
# above this before the armed handshake window can arm the interceptor.
HANDSHAKE_MIN_MOD_VERSION = os.environ.get("COMFY_HANDSHAKE_MIN_MOD_VERSION", "0.5.16")
# P7/I7 composition: the mod builds that carry each rung's runner. am4 (server) needs
# pin (0.5.10) + redirect (0.5.12) + handshake (0.5.16); OMEN (client) needs the injection
# runner (0.5.15). A 0.5.16+ am4 build has all three server runners AND the full config surface.
COMPOSE_MIN_MOD_VERSION_AM4 = os.environ.get("COMFY_COMPOSE_MIN_MOD_VERSION_AM4", "0.5.16")
COMPOSE_MIN_MOD_VERSION_OMEN = os.environ.get("COMFY_COMPOSE_MIN_MOD_VERSION_OMEN", "0.5.15")
# The am4-side flags the composition arms together (I2 pin + I3 redirect + I5 handshake).
# I4 injection is the OMEN client's flag; I6 Steam-only is server env (CROSSPLAY=false).
_COMPOSE_AM4_ARM_FLAGS = ("ownershipPinEnabled", "zdoRedirectEnabled", "handshakeResponderEnabled")
# Every rung's config key must exist in a build for it to be composition-capable.
_COMPOSE_CFG_SURFACE = ("ownershipPinEnabled", "zdoRedirectEnabled", "zdoInjectionEnabled",
                        "handshakeResponderEnabled")
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
        "ownership_churn_local": _file_info(NETWORK_SENSE_DIR / OWNERSHIP_CHURN_FILE),
        "ownership_pin_local": _file_info(NETWORK_SENSE_DIR / OWNERSHIP_PIN_FILE),
        "redirect_send_local": _file_info(NETWORK_SENSE_DIR / REDIRECT_SEND_FILE),
        "injection_apply_local": _file_info(NETWORK_SENSE_DIR / INJECTION_APPLY_FILE),
        "notes_path": str(DEV_NOTES_PATH),
        "ollama_endpoint": ollama_endpoint,
        "lumberjacks_url": LUMBERJACKS_URL,
        "am4": {"ssh_host": AM4_SSH_HOST, "container": AM4_CONTAINER,
                "probe_path": AM4_PROBE_PATH, "ownership_path": AM4_OWNERSHIP_PATH,
                "ownership_pin_path": AM4_OWNERSHIP_PIN_PATH,
                "redirect_send_path": AM4_REDIRECT_PATH},
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
            "valheim_tail_ownership_churn",
            "valheim_ownership_churn_summary",
            "valheim_tail_ownership_pin",
            "valheim_ownership_pin_status",
            "valheim_tail_zdo_redirect",
            "valheim_zdo_redirect_status",
            "valheim_lumberjacks_receipts",
            "valheim_zdo_redirect_gate",
            "valheim_tail_zdo_injection",
            "valheim_zdo_injection_status",
            "valheim_lumberjacks_injection",
            "valheim_zdo_injection_gate",
            "valheim_handshake_trace",
            "valheim_handshake_gate",
            "valheim_handshake_preflight",
            "valheim_loopback_preflight",
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


_OWNERSHIP_COUNTER_KEYS = (
    "set_owner_rows", "set_owner_internal_rows", "no_op_skipped", "rows_written",
)


def valheim_tail_ownership_churn(source: str = "am4", lines: int = 20) -> dict:
    """Tail the P3/I2 ownership-churn.jsonl. source='am4' (dedicated server, where the pin
    funnel churns) or 'local' (OMEN client)."""
    source = str(source or "").strip().lower()
    lines = max(1, min(int(lines), 2000))
    if source == "local":
        path = _safe_child(NETWORK_SENSE_DIR, OWNERSHIP_CHURN_FILE)
        return {
            "source": "local",
            "file": str(path),
            "exists": path.exists(),
            "entries": _tail_json(path, lines),
        }
    if source == "am4":
        try:
            rc, out, err = _run_ssh(f"tail -n {lines} {AM4_OWNERSHIP_PATH}")
        except subprocess.TimeoutExpired:
            return {"source": "am4", "ok": False, "error": "ssh timeout",
                    "ssh_host": AM4_SSH_HOST, "remote_path": AM4_OWNERSHIP_PATH}
        except FileNotFoundError:
            return {"source": "am4", "ok": False, "error": "ssh client not found on PATH"}
        if rc != 0:
            return {"source": "am4", "ok": False, "error": err.strip() or f"ssh exit {rc}",
                    "ssh_host": AM4_SSH_HOST, "remote_path": AM4_OWNERSHIP_PATH}
        return {
            "source": "am4",
            "ok": True,
            "ssh_host": AM4_SSH_HOST,
            "remote_path": AM4_OWNERSHIP_PATH,
            "entries": _parse_jsonl_text(out),
        }
    raise ValueError("source must be 'local' or 'am4'")


def _summarize_ownership_rows(rows: list[dict]) -> dict:
    """Scope to the latest start->stop window and aggregate ownership churn.

    Splits the two funnels by `via`: SetOwner = authoritative, revision-BUMPING path;
    SetOwnerInternal = the revision-SILENT remote-apply path (NETCODE-OWNERSHIP-MAP.md
    caveat #2 -- a SetOwner guard alone would NOT cover it). Lifecycle counters live only on
    a stop/status row; without one the counts are a FLOOR, not authoritative totals.
    """
    start_idx = None
    for index, row in enumerate(rows):
        if str(row.get("event")) == "start":
            start_idx = index
    window = rows[start_idx:] if start_idx is not None else rows

    summary_row = None
    for row in window:
        if str(row.get("event")) in ("stop", "status") and any(k in row for k in _OWNERSHIP_COUNTER_KEYS):
            summary_row = row  # last one wins

    churn = [r for r in window if str(r.get("event")) == "ownership"]
    via_set_owner = sum(1 for r in churn if str(r.get("via")) == "SetOwner")
    via_internal = sum(1 for r in churn if str(r.get("via")) == "SetOwnerInternal")
    distinct_uids = len({str(r.get("uid")) for r in churn})
    distinct_sectors = len({(r.get("sector_x"), r.get("sector_y")) for r in churn})
    server_rows = sum(1 for r in churn if r.get("is_server") is True)
    server_became_owner = sum(1 for r in churn if r.get("is_owner_now") is True)
    released_to_unowned = sum(1 for r in churn if str(r.get("new_owner")) == "0")

    if summary_row is not None:
        def _c(key: str) -> int:
            value = summary_row.get(key)
            return int(value) if isinstance(value, (int, float)) else 0
        counters = {key: _c(key) for key in _OWNERSHIP_COUNTER_KEYS}
        authoritative = True
        caveat = None
    else:
        counters = {key: None for key in _OWNERSHIP_COUNTER_KEYS}
        counters["rows_written"] = len(churn)
        authoritative = False
        caveat = ("No lifecycle stop/status row in window: counts are a FLOOR from detail "
                  "rows, not measured totals (needs ownershipObserveEnabled + a finite "
                  "netcodeProbeAutoStopSeconds). Not a gate PASS.")

    return {
        "has_lifecycle_summary": summary_row is not None,
        "counters_are_authoritative": authoritative,
        "counters": counters,
        "churn": {
            "total_change_rows": len(churn),
            "via_set_owner": via_set_owner,               # authoritative, revision-bumping
            "via_set_owner_internal": via_internal,       # revision-silent remote-apply (caveat #2)
            "distinct_zdos": distinct_uids,
            "distinct_sectors": distinct_sectors,
            "server_side_rows": server_rows,
            "server_became_owner": server_became_owner,   # is_owner_now == true (seize)
            "released_to_unowned": released_to_unowned,    # new_owner == 0 (release)
            "window_rows": len(window),
        },
        "window": {
            "has_start": start_idx is not None,
            "start_row": window[0] if (start_idx is not None and window) else None,
        },
        "caveat": caveat,
    }


def valheim_ownership_churn_summary(source: str = "am4") -> dict:
    """Summarize P3/I2 ownership churn, split by funnel (SetOwner vs SetOwnerInternal).

    Answers the observe-first questions before any pin code: does ownership transfer on zone
    entry, via which path, and does the revision race hold. counters_are_authoritative=false
    is NOT a measurement. Provenance (host + sha256 + size + age) exposes stale/copied data.
    source='am4' (dedicated server) or 'local' (OMEN client).
    """
    source = str(source or "").strip().lower()
    if source == "local":
        path = _safe_child(NETWORK_SENSE_DIR, OWNERSHIP_CHURN_FILE)
        if not path.exists():
            return {"source": "local", "ok": False, "error": "ownership-churn.jsonl not found",
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
        result.update(_summarize_ownership_rows(rows))
        return result
    if source == "am4":
        remote = (
            f"F={AM4_OWNERSHIP_PATH}; "
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
                    "ssh_host": AM4_SSH_HOST, "remote_path": AM4_OWNERSHIP_PATH}
        body_lines = out.splitlines()
        provenance = {"host": AM4_SSH_HOST, "remote_path": AM4_OWNERSHIP_PATH}
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
                provenance["prov_parse_error"] = True
        rows = _parse_jsonl_text("\n".join(body_lines))
        result = {"source": "am4", "ok": True, "provenance": provenance}
        result.update(_summarize_ownership_rows(rows))
        return result
    raise ValueError("source must be 'local' or 'am4'")


# Counter fields the pin emits only on an authoritative lifecycle pin_stop/pin_start row.
_OWNERSHIP_PIN_COUNTER_KEYS = (
    "pinned_count", "captured", "holds", "holds_via_set_owner", "holds_via_internal",
    "pass_through", "hold_rows_written",
)


def valheim_tail_ownership_pin(source: str = "am4", lines: int = 20) -> dict:
    """Tail the P3/I2 ownership-pin.jsonl (behaviour-changing pin holds). source='am4' (dedicated
    server, where the pin runs) or 'local' (OMEN client, normally empty — pin is server-side)."""
    source = str(source or "").strip().lower()
    lines = max(1, min(int(lines), 2000))
    if source == "local":
        path = _safe_child(NETWORK_SENSE_DIR, OWNERSHIP_PIN_FILE)
        return {
            "source": "local",
            "file": str(path),
            "exists": path.exists(),
            "entries": _tail_json(path, lines),
        }
    if source == "am4":
        try:
            rc, out, err = _run_ssh(f"tail -n {lines} {AM4_OWNERSHIP_PIN_PATH}")
        except subprocess.TimeoutExpired:
            return {"source": "am4", "ok": False, "error": "ssh timeout",
                    "ssh_host": AM4_SSH_HOST, "remote_path": AM4_OWNERSHIP_PIN_PATH}
        except FileNotFoundError:
            return {"source": "am4", "ok": False, "error": "ssh client not found on PATH"}
        if rc != 0:
            return {"source": "am4", "ok": False, "error": err.strip() or f"ssh exit {rc}",
                    "ssh_host": AM4_SSH_HOST, "remote_path": AM4_OWNERSHIP_PIN_PATH}
        return {
            "source": "am4",
            "ok": True,
            "ssh_host": AM4_SSH_HOST,
            "remote_path": AM4_OWNERSHIP_PIN_PATH,
            "entries": _parse_jsonl_text(out),
        }
    raise ValueError("source must be 'local' or 'am4'")


def _summarize_pin_rows(rows: list[dict]) -> dict:
    """Scope to the latest pin_start->pin_stop window and read the P3 gate signal.

    The gate is a two-sided comparison in ONE window: pinned ZDOs are HELD (owner does not
    transfer) while uncaptured ZDOs pass through normally (the negative control). `holds` split
    by funnel proves both caveat-#2 paths were exercised: via_set_owner = the server churn funnel
    (ReleaseNearbyZDOS), via_internal = the revision-silent RPC_ZDOData remote-apply. Lifecycle
    counters live only on a pin_start/pin_stop row; without one the counts are a FLOOR from detail
    rows, not authoritative totals (not a gate PASS).
    """
    start_idx = None
    for index, row in enumerate(rows):
        if str(row.get("event")) == "pin_start":
            start_idx = index
    window = rows[start_idx:] if start_idx is not None else rows

    summary_row = None
    for row in window:
        if str(row.get("event")) in ("pin_stop", "pin_start") and any(
                k in row for k in _OWNERSHIP_PIN_COUNTER_KEYS):
            summary_row = row  # last one wins (pin_stop supersedes pin_start)

    detail = [r for r in window if str(r.get("event")) in ("pin_capture", "pin_hold")]
    captures = [r for r in detail if str(r.get("event")) == "pin_capture"]
    holds_via_set_owner = sum(1 for r in detail if str(r.get("via")) == "SetOwner")
    holds_via_internal = sum(1 for r in detail if str(r.get("via")) == "SetOwnerInternal")
    distinct_pinned = len({str(r.get("uid")) for r in detail})
    distinct_sectors = len({(r.get("sector_x"), r.get("sector_y")) for r in detail})
    distinct_prefabs = len({r.get("prefab") for r in captures})
    held_owners = sorted({str(r.get("held_owner")) for r in captures})

    stopped = summary_row is not None and str(summary_row.get("event")) == "pin_stop"
    if summary_row is not None:
        def _c(key: str) -> int:
            value = summary_row.get(key)
            return int(value) if isinstance(value, (int, float)) else 0
        counters = {key: _c(key) for key in _OWNERSHIP_PIN_COUNTER_KEYS}
        authoritative = stopped
        caveat = None if stopped else (
            "Only a pin_start row is present (run still armed or crashed before pin_stop): "
            "counters are the arming snapshot, not final totals.")
    else:
        counters = {key: None for key in _OWNERSHIP_PIN_COUNTER_KEYS}
        counters["hold_rows_written"] = len(detail)
        authoritative = False
        caveat = ("No pin lifecycle row in window: counts are a FLOOR from detail rows, not "
                  "measured totals (needs ownershipPinEnabled + a finite netcodeProbeAutoStopSeconds). "
                  "Not a gate PASS.")

    # The gate reads pass when the pin actually held transfers AND some traffic passed through
    # (a live negative control), on an authoritative stop row.
    holds = counters.get("holds") or len(detail)
    passthrough = counters.get("pass_through")
    if authoritative and (counters.get("holds") or 0) > 0 and (passthrough or 0) > 0:
        gate = "held_with_negative_control"
    elif authoritative and (counters.get("holds") or 0) > 0:
        gate = "held_no_passthrough_observed"
    elif not detail and not (counters.get("holds") or 0):
        gate = "no_pin_activity"
    else:
        gate = "inconclusive"

    return {
        "has_lifecycle_summary": summary_row is not None,
        "counters_are_authoritative": authoritative,
        "gate": gate,
        "counters": counters,
        "pin": {
            "captures": len(captures),
            "distinct_pinned_zdos": distinct_pinned,
            "distinct_pinned_sectors": distinct_sectors,
            "distinct_pinned_prefabs": distinct_prefabs,
            "held_owner_ids": held_owners,             # who the pinned ZDOs stayed owned by
            "detail_holds_via_set_owner": holds_via_set_owner,   # server churn funnel
            "detail_holds_via_internal": holds_via_internal,     # RPC_ZDOData remote-apply (caveat #2)
            "detail_rows": len(detail),
            "window_rows": len(window),
        },
        "window": {
            "has_start": start_idx is not None,
            "start_row": window[0] if (start_idx is not None and window) else None,
        },
        "caveat": caveat,
    }


def valheim_ownership_pin_status(source: str = "am4") -> dict:
    """Report the P3/I2 ownership PIN gate: did pinned ZDOs stay pinned while others transferred?

    Reads ownership-pin.jsonl and scopes to the latest pin window. `gate` is the headline:
    'held_with_negative_control' = the pin held real transfers AND uncaptured traffic passed
    through (the P3 step 9 + step 10 comparison in one window); 'no_pin_activity' = armed but
    nothing churned; other values need inspection. `holds` split by funnel confirms BOTH caveat-#2
    paths (SetOwner + SetOwnerInternal) were covered. counters_are_authoritative=false is NOT a
    PASS. Provenance (host + sha256 + size + age) exposes stale/copied data. source='am4' (dedicated
    server, where the pin runs) or 'local'. Pair with valheim_ownership_churn_summary (the observe
    seam logs the uncaptured transfers in detail) and valheim_save_integrity (the hard reload gate).
    """
    source = str(source or "").strip().lower()
    if source == "local":
        path = _safe_child(NETWORK_SENSE_DIR, OWNERSHIP_PIN_FILE)
        if not path.exists():
            return {"source": "local", "ok": False, "error": "ownership-pin.jsonl not found",
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
        result.update(_summarize_pin_rows(rows))
        return result
    if source == "am4":
        remote = (
            f"F={AM4_OWNERSHIP_PIN_PATH}; "
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
                    "ssh_host": AM4_SSH_HOST, "remote_path": AM4_OWNERSHIP_PIN_PATH}
        body_lines = out.splitlines()
        provenance = {"host": AM4_SSH_HOST, "remote_path": AM4_OWNERSHIP_PIN_PATH}
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
                provenance["prov_parse_error"] = True
        rows = _parse_jsonl_text("\n".join(body_lines))
        result = {"source": "am4", "ok": True, "provenance": provenance}
        result.update(_summarize_pin_rows(rows))
        return result
    raise ValueError("source must be 'local' or 'am4'")


# Counter fields the redirect emits only on a lifecycle redirect_start/stop/auto_stop row.
_REDIRECT_COUNTER_KEYS = (
    "seq", "suppressed", "ack_failures", "posted_ok", "post_failed_batches",
    "requeued", "dropped", "queued", "rows_written",
)


def valheim_tail_zdo_redirect(source: str = "am4", lines: int = 20) -> dict:
    """Tail the P4/I3 redirect-send.jsonl (suppressed native sends). source='am4' (dedicated
    server, where the redirect runs) or 'local' (OMEN client, normally empty — server-side)."""
    source = str(source or "").strip().lower()
    lines = max(1, min(int(lines), 2000))
    if source == "local":
        path = _safe_child(NETWORK_SENSE_DIR, REDIRECT_SEND_FILE)
        return {
            "source": "local",
            "file": str(path),
            "exists": path.exists(),
            "entries": _tail_json(path, lines),
        }
    if source == "am4":
        try:
            rc, out, err = _run_ssh(f"tail -n {lines} {AM4_REDIRECT_PATH}")
        except subprocess.TimeoutExpired:
            return {"source": "am4", "ok": False, "error": "ssh timeout",
                    "ssh_host": AM4_SSH_HOST, "remote_path": AM4_REDIRECT_PATH}
        except FileNotFoundError:
            return {"source": "am4", "ok": False, "error": "ssh client not found on PATH"}
        if rc != 0:
            return {"source": "am4", "ok": False, "error": err.strip() or f"ssh exit {rc}",
                    "ssh_host": AM4_SSH_HOST, "remote_path": AM4_REDIRECT_PATH}
        return {
            "source": "am4",
            "ok": True,
            "ssh_host": AM4_SSH_HOST,
            "remote_path": AM4_REDIRECT_PATH,
            "entries": _parse_jsonl_text(out),
        }
    raise ValueError("source must be 'local' or 'am4'")


def _summarize_redirect_rows(rows: list[dict]) -> dict:
    """Scope to the latest redirect_start window and read the mod-side half of the I3 gate.

    The full gate is a THREE-way cross-confirm: these mod-side counts == the Lumberjacks
    gateway's distinct-seq receipts (valheim_lumberjacks_receipts), while the netcode probe
    shows zero native sends of the tagged prefab during the active sub-window. Lifecycle
    counters live only on a redirect_stop/redirect_auto_stop row; without one the counts are
    a FLOOR from detail rows, not authoritative totals (not a gate input).
    """
    start_idx = None
    for index, row in enumerate(rows):
        if str(row.get("event")) == "redirect_start":
            start_idx = index
    window = rows[start_idx:] if start_idx is not None else rows

    summary_row = None
    for row in window:
        if str(row.get("event")) in ("redirect_stop", "redirect_auto_stop", "redirect_start") \
                and any(k in row for k in _REDIRECT_COUNTER_KEYS):
            summary_row = row  # last one wins (a stop row supersedes the arming snapshot)

    detail = [r for r in window if str(r.get("event")) == "redirect"]
    seqs = [int(r.get("seq")) for r in detail if isinstance(r.get("seq"), (int, float))]
    distinct_prefabs = sorted({r.get("prefab") for r in detail})
    unacked = sum(1 for r in detail if r.get("acked") is False)
    window_ids = sorted({str(r.get("window_id")) for r in detail if r.get("window_id")})

    stop_event = str(summary_row.get("event")) if summary_row is not None else None
    stopped = stop_event in ("redirect_stop", "redirect_auto_stop")
    if summary_row is not None:
        def _c(key: str) -> int:
            value = summary_row.get(key)
            return int(value) if isinstance(value, (int, float)) else 0
        counters = {key: _c(key) for key in _REDIRECT_COUNTER_KEYS}
        authoritative = stopped
        caveat = None if stopped else (
            "Only a redirect_start row is present (run still armed or died before stop): "
            "counters are the arming snapshot, not final totals.")
    else:
        counters = {key: None for key in _REDIRECT_COUNTER_KEYS}
        counters["rows_written"] = len(detail)
        authoritative = False
        caveat = ("No redirect lifecycle row in window: counts are a FLOOR from detail rows, "
                  "not measured totals (needs zdoRedirectEnabled + a prefab allowlist + the "
                  "netcode-probe window). Not a gate input.")

    return {
        "has_lifecycle_summary": summary_row is not None,
        "counters_are_authoritative": authoritative,
        "stop_event": stop_event,   # redirect_auto_stop = the in-window rollback rehearsal fired
        "counters": counters,
        "redirect": {
            "detail_rows": len(detail),
            "max_detail_seq": max(seqs) if seqs else 0,
            "distinct_prefabs": distinct_prefabs,
            "unacked_detail_rows": unacked,
            "window_ids": window_ids,
            "window_rows": len(window),
        },
        "window": {
            "has_start": start_idx is not None,
            "start_row": window[0] if (start_idx is not None and window) else None,
        },
        "caveat": caveat,
    }


def valheim_zdo_redirect_status(source: str = "am4") -> dict:
    """Report the mod-side half of the P4/I3 redirect gate from redirect-send.jsonl.

    `counters.seq` (on an authoritative stop row) is the suppressed-send count the Lumberjacks
    gateway's distinct_seq must equal (zero missing_seq) — compare via valheim_zdo_redirect_gate,
    or manually against valheim_lumberjacks_receipts. stop_event='redirect_auto_stop' confirms
    the in-window rollback rehearsal fired. Provenance (host + sha256 + size + age) exposes
    stale/copied data. source='am4' (dedicated server, where the redirect runs) or 'local'.
    """
    source = str(source or "").strip().lower()
    if source == "local":
        path = _safe_child(NETWORK_SENSE_DIR, REDIRECT_SEND_FILE)
        if not path.exists():
            return {"source": "local", "ok": False, "error": "redirect-send.jsonl not found",
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
        result.update(_summarize_redirect_rows(rows))
        return result
    if source == "am4":
        remote = (
            f"F={AM4_REDIRECT_PATH}; "
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
                    "ssh_host": AM4_SSH_HOST, "remote_path": AM4_REDIRECT_PATH}
        body_lines = out.splitlines()
        provenance = {"host": AM4_SSH_HOST, "remote_path": AM4_REDIRECT_PATH}
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
                provenance["prov_parse_error"] = True
        rows = _parse_jsonl_text("\n".join(body_lines))
        result = {"source": "am4", "ok": True, "provenance": provenance}
        result.update(_summarize_redirect_rows(rows))
        return result
    raise ValueError("source must be 'local' or 'am4'")


def valheim_lumberjacks_receipts(window_id: str = "") -> dict:
    """Read the Lumberjacks gateway's ZDO-redirect receipt counters (the gateway half of the
    I3 gate). window_id scopes to one window; blank returns all windows. The gate numbers are
    distinct_seq (must equal the mod's suppressed-send count) and missing_seq (must be 0)."""
    window_id = str(window_id or "").strip()
    url = LUMBERJACKS_URL.rstrip("/") + "/valheim/zdo-redirect/status"
    if window_id:
        url += "/" + urllib.parse.quote(window_id, safe="")
    try:
        with urllib.request.urlopen(url, timeout=10) as response:
            payload = json.loads(response.read().decode("utf-8", "replace"))
    except urllib.error.URLError as error:
        return {"ok": False, "url": url, "error": str(error),
                "hint": "Is the Lumberjacks gateway up? Launch with --urls http://0.0.0.0:4000 "
                        "(fieldlab/scripts/start-lumberjacks-gateway.ps1)."}
    except (json.JSONDecodeError, TimeoutError) as error:
        return {"ok": False, "url": url, "error": str(error)}
    return {"ok": True, "url": url, "status": payload}


def valheim_zdo_redirect_gate(window_id: str = "", source: str = "am4") -> dict:
    """One-call P4/I3 gate read: mod suppressed-send count vs Lumberjacks receipts.

    Compares valheim_zdo_redirect_status(source) against valheim_lumberjacks_receipts for the
    window. verdict='receipts_match_no_loss' requires an authoritative mod stop row, mod seq ==
    gateway distinct_seq, and gateway missing_seq == 0. The probe cross-confirm (zero native
    sends of the tagged prefab during the active sub-window) is step 3 — read it separately via
    valheim_tail_netcode_probe. Not a substitute for the client-stability and save-integrity gates.
    """
    mod = valheim_zdo_redirect_status(source)
    if not mod.get("ok"):
        return {"ok": False, "verdict": "inconclusive", "error": "mod-side read failed", "mod": mod}

    window_ids = mod.get("redirect", {}).get("window_ids") or []
    resolved_window = str(window_id or "").strip() or (window_ids[-1] if window_ids else "")
    gateway = valheim_lumberjacks_receipts(resolved_window)
    if not gateway.get("ok"):
        return {"ok": False, "verdict": "inconclusive", "error": "gateway read failed",
                "window_id": resolved_window, "mod": mod, "gateway": gateway}

    status = gateway.get("status") or {}
    mod_count = (mod.get("counters") or {}).get("seq")
    if mod_count is None:
        mod_count = mod.get("redirect", {}).get("max_detail_seq")
    distinct = status.get("distinct_seq")
    missing = status.get("missing_seq")
    authoritative = bool(mod.get("counters_are_authoritative"))

    if authoritative and mod_count and distinct == mod_count and missing == 0:
        verdict = "receipts_match_no_loss"
    elif not authoritative:
        verdict = "inconclusive_mod_counters_not_authoritative"
    elif not mod_count:
        verdict = "no_redirect_activity"
    else:
        verdict = "mismatch"

    return {
        "ok": True,
        "verdict": verdict,
        "window_id": resolved_window,
        "mod_suppressed": mod_count,
        "gateway_distinct_seq": distinct,
        "gateway_missing_seq": missing,
        "gateway_duplicates": status.get("duplicates"),
        "mod_authoritative": authoritative,
        "mod_stop_event": mod.get("stop_event"),
        "mod_unacked_rows": mod.get("redirect", {}).get("unacked_detail_rows"),
        "caveats": [c for c in [mod.get("caveat")] if c],
    }


_INJECTION_COUNTER_KEYS = (
    "polls", "poll_errors", "received", "applied", "rendered", "rejected",
    "duplicates", "awaiting_render",
)


def valheim_tail_zdo_injection(lines: int = 50) -> dict:
    """Tail the local OMEN client's P5/I4 injection lifecycle and readback rows."""
    lines = max(1, min(int(lines), 2000))
    path = _safe_child(NETWORK_SENSE_DIR, INJECTION_APPLY_FILE)
    return {"source": "local", "file": str(path), "exists": path.exists(),
            "entries": _tail_json(path, lines)}


def _summarize_injection_rows(rows: list[dict]) -> dict:
    start_idx = None
    for index, row in enumerate(rows):
        if str(row.get("event")) == "injection_start":
            start_idx = index
    window = rows[start_idx:] if start_idx is not None else rows
    lifecycle = [r for r in window if str(r.get("event")) in (
        "injection_start", "injection_stop", "injection_auto_stop", "injection_dispose")]
    summary = lifecycle[-1] if lifecycle else None
    applied = [r for r in window if str(r.get("event")) == "injection_applied"]
    rendered = [r for r in window if str(r.get("event")) == "injection_rendered"]
    rejected = [r for r in window if str(r.get("event")) == "injection_rejected"]
    stop_event = str(summary.get("event")) if summary else None
    authoritative = stop_event in ("injection_stop", "injection_auto_stop", "injection_dispose")
    counters = {}
    for key in _INJECTION_COUNTER_KEYS:
        value = summary.get(key) if summary else None
        counters[key] = int(value) if isinstance(value, (int, float)) else None
    return {
        "has_lifecycle_summary": summary is not None,
        "counters_are_authoritative": authoritative,
        "stop_event": stop_event,
        "window_id": str(summary.get("window_id") or "") if summary else "",
        "authority_id": str(summary.get("authority_id") or "") if summary else "",
        "counters": counters,
        "applied_rows": applied,
        "rendered_rows": rendered,
        "rejected_rows": rejected,
        "last_error": str(summary.get("last_error") or "") if summary else "",
        "caveat": None if authoritative else (
            "No terminal injection lifecycle row; detail rows are a floor, not a gate result."),
    }


def valheim_zdo_injection_status() -> dict:
    """Read the OMEN client-side P5/I4 apply/render status with file provenance."""
    path = _safe_child(NETWORK_SENSE_DIR, INJECTION_APPLY_FILE)
    if not path.exists():
        return {"ok": False, "error": "injection-apply.jsonl not found", "path": str(path)}
    raw = path.read_text(encoding="utf-8", errors="replace")
    stat = path.stat()
    result = {
        "ok": True,
        "source": "local",
        "provenance": {"host": "local", "path": str(path),
            "sha256": hashlib.sha256(raw.encode("utf-8", "replace")).hexdigest(),
            "size_bytes": stat.st_size, "modified_unix": stat.st_mtime,
            "age_seconds": round(time.time() - stat.st_mtime, 1)},
    }
    result.update(_summarize_injection_rows(_parse_jsonl_text(raw)))
    return result


def valheim_lumberjacks_injection(window_id: str = "") -> dict:
    """Read Lumberjacks P5 queue, poll, and per-client acknowledgement state."""
    window_id = str(window_id or "").strip()
    url = LUMBERJACKS_URL.rstrip("/") + "/valheim/zdo-injection/status"
    if window_id:
        url += "/" + urllib.parse.quote(window_id, safe="")
    try:
        with urllib.request.urlopen(url, timeout=10) as response:
            payload = json.loads(response.read().decode("utf-8", "replace"))
    except (urllib.error.URLError, json.JSONDecodeError, TimeoutError) as error:
        return {"ok": False, "url": url, "error": str(error)}
    return {"ok": True, "url": url, "status": payload}


def valheim_zdo_injection_gate(window_id: str = "") -> dict:
    """One-call P5 readback gate: local rendered row plus Lumberjacks rendered ack."""
    mod = valheim_zdo_injection_status()
    if not mod.get("ok"):
        return {"ok": False, "verdict": "inconclusive", "mod": mod}
    resolved = str(window_id or "").strip() or str(mod.get("window_id") or "")
    gateway = valheim_lumberjacks_injection(resolved)
    if not gateway.get("ok"):
        return {"ok": False, "verdict": "inconclusive", "window_id": resolved,
                "mod": mod, "gateway": gateway}
    status = gateway.get("status") or {}
    acks = status.get("acks") or status.get("Acks") or {}
    rendered_acks = [a for a in acks.values() if bool(a.get("rendered") or a.get("Rendered"))]
    rendered_rows = mod.get("rendered_rows") or []
    owner_matches = bool(rendered_rows) and all(
        str(row.get("owner") or "") == str(mod.get("authority_id") or "")
        for row in rendered_rows)
    if rendered_rows and rendered_acks and owner_matches:
        verdict = "rendered_with_lumberjacks_owner"
    elif mod.get("rejected_rows"):
        verdict = "rejected"
    else:
        verdict = "pending"
    return {"ok": True, "verdict": verdict, "window_id": resolved,
            "rendered_rows": len(rendered_rows), "rendered_acks": len(rendered_acks),
            "owner_matches": owner_matches,
            "mod_authoritative": bool(mod.get("counters_are_authoritative")),
            "mod": mod, "gateway": gateway}


# --- P6/I5 handshake responder ---------------------------------------------------------
# The Lumberjacks handshake responder replicates Funnel 5's ordered connection gate
# (fieldlab/NETCODE-HANDSHAKE-CONTRACT.md). These tools read its per-window trace and
# compute the one-call gate verdict. The mod (P6 step 5) owns the ZPackage bytes; the
# responder answers the two logical decisions (ClientHandshake args; accept-or-reject).

# The failure-battery CHECKS a satisfied handshake window must have exercised, by their
# distinct gate label - this is stricter than counting error codes because blacklist and
# bad-steam-ticket share code 8 (ErrorBanned) and would otherwise be indistinguishable.
_HANDSHAKE_BATTERY_CHECKS = {"version", "blacklist", "ticket", "full", "password", "duplicate"}


def valheim_handshake_trace(window_id: str = "") -> dict:
    """Read the Lumberjacks P6/I5 handshake exchange trace + gate counters for a window.

    Omit window_id to list every window; pass one to read that window's record.
    """
    window_id = str(window_id or "").strip()
    url = LUMBERJACKS_URL.rstrip("/") + "/valheim/handshake/status"
    if window_id:
        url += "/" + urllib.parse.quote(window_id, safe="")
    try:
        with urllib.request.urlopen(url, timeout=10) as response:
            payload = json.loads(response.read().decode("utf-8", "replace"))
    except (urllib.error.URLError, json.JSONDecodeError, TimeoutError) as error:
        return {"ok": False, "url": url, "error": str(error),
                "hint": "Is the Lumberjacks gateway up with the handshake endpoints? "
                        "Rebuild + relaunch src/Game.Gateway (--urls http://0.0.0.0:4000)."}
    return {"ok": True, "url": url, "window_id": window_id, "status": payload}


def valheim_handshake_gate(window_id: str = "") -> dict:
    """One-call P6/I5 gate: a window is handshake_satisfied when the happy path reached the
    steady-state transition AND the full ordered failure battery surfaced the exact codes."""
    trace = valheim_handshake_trace(window_id)
    if not trace.get("ok"):
        return {"ok": False, "verdict": "inconclusive", "trace": trace}

    payload = trace.get("status") or {}
    # Resolve to a single window record: /status/{id} returns one; /status returns {windows:[...]}.
    # The gateway serializes snake_case.
    if "windows" in payload:
        windows = payload.get("windows") or []
        if len(windows) != 1:
            return {"ok": False, "verdict": "inconclusive",
                    "error": f"expected exactly one window, found {len(windows)}; pass window_id",
                    "windows": [w.get("window_id", "") for w in windows]}
        status = windows[0]
    else:
        status = payload

    resolved = str(status.get("window_id") or window_id)
    accepted = int(status.get("accepted", 0))
    steady = int(status.get("steady_state_reached", 0))
    rejected = int(status.get("rejected", 0))
    by_code = status.get("by_code", {}) or {}
    exchanges = status.get("exchanges", []) or []

    # Coverage is verified by DISTINCT gate-check label (from the exchange trace), which
    # distinguishes the two code-8 cases (blacklist vs ticket) that a codes-only check merges.
    failed_checks = {str(e.get("failed_check")) for e in exchanges
                     if not e.get("accept") and e.get("failed_check")}
    missing_checks = sorted(_HANDSHAKE_BATTERY_CHECKS - failed_checks)

    accept_ok = steady >= 1
    battery_ok = _HANDSHAKE_BATTERY_CHECKS.issubset(failed_checks)
    if accept_ok and battery_ok:
        verdict = "handshake_satisfied"
    elif accept_ok:
        verdict = "accept_only"
    elif rejected:
        verdict = "reject_only"
    else:
        verdict = "pending"

    return {"ok": True, "verdict": verdict, "window_id": resolved,
            "accepted": accepted, "logical_steady_state_reached": steady, "rejected": rejected,
            "battery_checks_present": sorted(failed_checks),
            "battery_checks_missing": missing_checks,
            "by_code": {str(k): v for k, v in by_code.items()},
            # HONESTY: this is a LOGICAL/headless decision proof only. steady-state here means
            # the responder's gate accepted and would drive AddPeer - it is NOT an observation of
            # a real Valheim ZDOMan.AddPeer / in-world peer. The live gate is P6 step 6-7 (Derek
            # connects in-game; >=30s in-world). See fieldlab/NETCODE-HANDSHAKE-CONTRACT.md.
            "scope": "logical_headless_no_live_addpeer",
            "status": status}


def _parse_cfg_flags(text: str) -> dict:
    """Parse a BepInEx `key = value` cfg body into a flat dict (last write wins, comments skipped)."""
    flags: dict = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or line.startswith("[") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        flags[k.strip()] = v.strip()
    return flags


def _cfg_bool(flags: dict, key: str) -> bool | None:
    v = flags.get(key)
    if v is None:
        return None
    return v.strip().lower() == "true"


def _version_tuple(v: str) -> tuple:
    try:
        return tuple(int(p) for p in str(v).strip().split("."))
    except ValueError:
        return ()


def _grep_mod_version_am4() -> str | None:
    """Last 'Loading [ComfyNetworkSense X.Y.Z]' the am4 container logged this boot."""
    code, out, _ = _run_ssh(
        f"docker logs {shlex.quote(AM4_CONTAINER)} 2>&1 | grep -oE "
        r"'ComfyNetworkSense [0-9]+\.[0-9]+\.[0-9]+' | tail -1"
    )
    if code == 0 and out.strip():
        return out.strip().split()[-1]
    return None


def valheim_handshake_preflight(window_id: str = "") -> dict:
    """One-call P6/I5 armed-window pre-flight (READ-ONLY): verify every precondition for
    Derek's single live handshake window.

    Distinct from valheim_handshake_gate (which proves the LOGICAL responder headlessly),
    this checks the physical rig is ready to BEGIN the armed window:
      - door:            this gateway serves the handshake tools;
      - lumberjacks:     /valheim/handshake reachable AND a 'fronted' window is configured
                         (a discriminating gate vanilla am4 lacks: needs_password / a ban /
                         a permit-list) so the client's admission is provably Lumberjacks-decided;
      - am4_reachable:   ssh to the dedicated server answers;
      - am4_baseline:    observe-only/disarmed (ownershipPin + zdoRedirect + zdoInjection all false);
      - am4_mod_version: at/above the handshake build (HANDSHAKE_MIN_MOD_VERSION);
      - omen_client:     local mod build present.

    The RPC interceptor is deliberately NOT a precondition: per the banked step-5 decision it
    is built + wire-validated in-game at the armed window, not headlessly. Its deploy shows up
    under window_steps_remaining, not as a pre-flight blocker. Verdict: preconditions_ready |
    not_ready. Nothing is mutated; no server restart.
    """
    checks: dict = {}

    # 1. door — the running gateway exposes both handshake tools (this call proves the door is up)
    tool_names = {t.__name__ for t in get_tools()}
    door_ok = {"valheim_handshake_trace", "valheim_handshake_gate"}.issubset(tool_names)
    checks["door"] = {"ok": door_ok, "handshake_tools_registered": door_ok}

    # 2. lumberjacks — handshake endpoint up + a fronted (discriminating) window present
    trace = valheim_handshake_trace(window_id)
    lj_ok = bool(trace.get("ok"))
    windows = []
    if lj_ok:
        payload = trace.get("status") or {}
        windows = payload.get("windows") or ([payload] if payload.get("window_id") else [])
    fronted = []
    for w in windows:
        discriminators = []
        if w.get("need_password"):
            discriminators.append("needs_password")
        if int(w.get("banned_hosts", 0) or 0) > 0:
            discriminators.append("blacklist")
        if int(w.get("permitted_hosts", 0) or 0) > 0:
            discriminators.append("permit_list")
        if discriminators:
            fronted.append({"window_id": w.get("window_id"), "discriminators": discriminators})
    checks["lumberjacks"] = {
        "ok": lj_ok,
        "windows": [w.get("window_id") for w in windows],
        "fronted_windows": fronted,
        "fronted_configured": bool(fronted),
        "url": trace.get("url"),
        "error": trace.get("error"),
    }

    # 3-5. am4 — reachable, disarmed baseline, mod version (single ssh cfg read + a version grep)
    code, cfg_text, cfg_err = _run_ssh(f"cat {AM4_MOD_CFG}")
    am4_reachable = code == 0 and bool(cfg_text.strip())
    checks["am4_reachable"] = {"ok": am4_reachable, "cfg_path": AM4_MOD_CFG,
                               "error": None if am4_reachable else (cfg_err.strip() or "unreadable cfg")}
    baseline_ok = None
    arm_flags = {}
    if am4_reachable:
        flags = _parse_cfg_flags(cfg_text)
        for key in ("ownershipPinEnabled", "zdoRedirectEnabled", "zdoInjectionEnabled",
                    "handshakeResponderEnabled"):
            arm_flags[key] = _cfg_bool(flags, key)
        armed = [k for k in ("ownershipPinEnabled", "zdoRedirectEnabled", "zdoInjectionEnabled")
                 if arm_flags.get(k) is True]
        baseline_ok = not armed
        checks["am4_baseline"] = {"ok": baseline_ok, "flags": arm_flags,
                                  "armed_unexpectedly": armed,
                                  "handshake_surface_present": "handshakeResponderEnabled" in flags}
    else:
        checks["am4_baseline"] = {"ok": None, "note": "am4 unreachable"}

    am4_version = _grep_mod_version_am4() if am4_reachable else None
    version_ok = bool(am4_version) and _version_tuple(am4_version) >= _version_tuple(HANDSHAKE_MIN_MOD_VERSION)
    checks["am4_mod_version"] = {"ok": version_ok, "am4": am4_version,
                                 "required_min": HANDSHAKE_MIN_MOD_VERSION}

    # 6. omen client — local mod build present (boot log carries the version line)
    omen_version = None
    if BEPINEX_LOG.exists():
        for ln in reversed(_tail_lines(BEPINEX_LOG, MAX_TAIL_LINES)):
            if "ComfyNetworkSense" in ln:
                parts = [p for p in ln.replace("[", " ").replace("]", " ").split()
                         if p and p[0].isdigit() and "." in p]
                if parts:
                    omen_version = parts[-1]
                    break
    checks["omen_client"] = {"ok": bool(omen_version), "version": omen_version,
                             "cfg_present": NETWORK_SENSE_CFG.exists()}

    # Hard preconditions to BEGIN the armed window (infra up + disarmed baseline).
    hard_ok = bool(door_ok and lj_ok and am4_reachable and baseline_ok)
    verdict = "preconditions_ready" if hard_ok else "not_ready"

    # Things the armed window itself must still do (NOT pre-flight blockers).
    window_steps_remaining = []
    if not checks["lumberjacks"]["fronted_configured"]:
        window_steps_remaining.append(
            "configure a fronted Lumberjacks handshake window (a gate vanilla am4 lacks: "
            "needs_password / ban / permit-list) so admission is provably Lumberjacks-decided")
    if not version_ok:
        window_steps_remaining.append(
            f"deploy the handshake mod build (>= {HANDSHAKE_MIN_MOD_VERSION} + the RPC interceptor) "
            f"to am4 (currently {am4_version or 'unknown'})")
    window_steps_remaining.append(
        "arm + wire-validate the RPC_ServerHandshake/RPC_PeerInfo interceptor in-game "
        "(first real-client bytes; banked step-5 decision)")

    return {
        "ok": True,
        "verdict": verdict,
        "ready_to_begin_armed_window": hard_ok,
        "checks": checks,
        "window_steps_remaining": window_steps_remaining,
        "scope": "physical_rig_preconditions_only_interceptor_validated_in_game",
        "note": "preconditions_ready means the rig can BEGIN the armed window; it does NOT mean "
                "the live handshake passed. The live gate is P6 step 6-7 (Derek in-world >=30s).",
    }


def valheim_loopback_preflight(window_id: str = "") -> dict:
    """One-call P7/I7 composition pre-flight (READ-ONLY): verify the full stack is ready to arm
    I2 pin + I3 redirect + I4 injection + I5 handshake together for a single in-world
    'one client fully on Lumberjacks' window.

    A superset of valheim_handshake_preflight: it also checks the redirect + injection
    subsystems and that BOTH deployed builds carry every runner (am4 has pin/redirect/handshake;
    OMEN has injection). Same philosophy: 'preconditions_ready' means the rig can BEGIN the armed
    window (infra up + disarmed baseline + runners present). The per-subsystem Lumberjacks windows
    are staged just-in-time at the armed session, so they surface under window_steps_remaining, not
    as blockers. Nothing is mutated; no server restart.
    """
    checks: dict = {}

    # 1. door — the gateway exposes all four subsystem gates (this call proves the door is up)
    tool_names = {t.__name__ for t in get_tools()}
    compose_tools = {"valheim_ownership_pin_status", "valheim_zdo_redirect_gate",
                     "valheim_zdo_injection_gate", "valheim_handshake_gate"}
    door_ok = compose_tools.issubset(tool_names)
    checks["door"] = {"ok": door_ok, "compose_gates_registered": sorted(compose_tools & tool_names)}

    # 2. lumberjacks — endpoint reachable (hard) + which of the three windows are already staged
    #    (soft; staging is a just-in-time armed-window step).
    trace = valheim_handshake_trace(window_id)
    lj_ok = bool(trace.get("ok"))
    hs_windows = []
    if lj_ok:
        payload = trace.get("status") or {}
        hs_windows = payload.get("windows") or ([payload] if payload.get("window_id") else [])
    fronted = []
    for w in hs_windows:
        discriminators = []
        if w.get("need_password"):
            discriminators.append("needs_password")
        if int(w.get("banned_hosts", 0) or 0) > 0:
            discriminators.append("blacklist")
        if int(w.get("permitted_hosts", 0) or 0) > 0:
            discriminators.append("permit_list")
        if discriminators:
            fronted.append({"window_id": w.get("window_id"), "discriminators": discriminators})
    # Precise per-subsystem signals: the status endpoints return a DEFAULT window object with the
    # window_id populated even for a window that was never created, so a generic "has a window_id"
    # check false-positives (verified live). Injection is staged only when a fixture command exists
    # (commands>0); the redirect window is create-on-first-write, so it is reported informationally
    # (receipts) and never gates a staging step.
    inj = valheim_lumberjacks_injection(window_id)
    injection_commands = int((inj.get("status") or {}).get("commands") or 0) if inj.get("ok") else 0
    injection_staged = injection_commands > 0
    red = valheim_lumberjacks_receipts(window_id)
    redirect_receipts = int((red.get("status") or {}).get("receipts") or 0) if red.get("ok") else 0
    checks["lumberjacks"] = {
        "ok": lj_ok,
        "handshake_fronted": bool(fronted),
        "fronted_windows": fronted,
        "injection_fixture_staged": injection_staged,
        "injection_commands": injection_commands,
        "redirect_receipts": redirect_receipts,
        "redirect_note": "created on first receipt POST (no pre-staging needed)",
        "url": trace.get("url"),
        "error": trace.get("error"),
    }

    # 3-5. am4 — reachable, disarmed baseline, all four runner config keys present, mod version
    code, cfg_text, cfg_err = _run_ssh(f"cat {AM4_MOD_CFG}")
    am4_reachable = code == 0 and bool(cfg_text.strip())
    checks["am4_reachable"] = {"ok": am4_reachable, "cfg_path": AM4_MOD_CFG,
                               "error": None if am4_reachable else (cfg_err.strip() or "unreadable cfg")}
    am4_baseline_ok = None
    am4_surface_ok = None
    arm_flags = {}
    if am4_reachable:
        flags = _parse_cfg_flags(cfg_text)
        for key in _COMPOSE_CFG_SURFACE:
            arm_flags[key] = _cfg_bool(flags, key)
        armed = [k for k in _COMPOSE_CFG_SURFACE if arm_flags.get(k) is True]
        am4_baseline_ok = not armed
        missing_keys = [k for k in _COMPOSE_CFG_SURFACE if k not in flags]
        am4_surface_ok = not missing_keys
        checks["am4_baseline"] = {"ok": am4_baseline_ok, "flags": arm_flags,
                                  "armed_unexpectedly": armed,
                                  "compose_surface_present": am4_surface_ok,
                                  "missing_keys": missing_keys}
    else:
        checks["am4_baseline"] = {"ok": None, "note": "am4 unreachable"}

    am4_version = _grep_mod_version_am4() if am4_reachable else None
    am4_version_ok = (bool(am4_version)
                      and _version_tuple(am4_version) >= _version_tuple(COMPOSE_MIN_MOD_VERSION_AM4))
    checks["am4_mod_version"] = {"ok": am4_version_ok, "am4": am4_version,
                                 "required_min": COMPOSE_MIN_MOD_VERSION_AM4}

    # 6. omen client — cfg present + injection runner surface (hard, readable at rest) +
    #    build version from the boot log (soft; null when the client is not launched this session).
    omen_cfg_present = NETWORK_SENSE_CFG.exists()
    omen_surface_ok = None
    omen_injection_at_rest = None
    if omen_cfg_present:
        try:
            omen_flags = _parse_cfg_flags(
                NETWORK_SENSE_CFG.read_text(encoding="utf-8", errors="replace"))
        except OSError:
            omen_flags = {}
        omen_surface_ok = "zdoInjectionEnabled" in omen_flags
        omen_injection_at_rest = _cfg_bool(omen_flags, "zdoInjectionEnabled")
    omen_version = None
    if BEPINEX_LOG.exists():
        for ln in reversed(_tail_lines(BEPINEX_LOG, MAX_TAIL_LINES)):
            if "ComfyNetworkSense" in ln:
                parts = [p for p in ln.replace("[", " ").replace("]", " ").split()
                         if p and p[0].isdigit() and "." in p]
                if parts:
                    omen_version = parts[-1]
                    break
    omen_version_ok = (bool(omen_version)
                       and _version_tuple(omen_version) >= _version_tuple(COMPOSE_MIN_MOD_VERSION_OMEN))
    checks["omen_client"] = {
        "ok": bool(omen_cfg_present and omen_surface_ok),
        "cfg_present": omen_cfg_present,
        "injection_surface_present": omen_surface_ok,
        "injection_armed_at_rest": omen_injection_at_rest,
        "version": omen_version,
        "version_ok_soft": omen_version_ok,
        "required_min": COMPOSE_MIN_MOD_VERSION_OMEN,
        "note": None if omen_version
                else "client not launched this session; version unread (soft, non-blocking)",
    }

    # Hard preconditions to BEGIN the armed window: infra up + disarmed baseline + both builds
    # carry every runner. Lumberjacks window staging + OMEN boot-version are NOT blockers.
    hard_ok = bool(door_ok and lj_ok and am4_reachable and am4_baseline_ok
                   and am4_surface_ok and am4_version_ok
                   and omen_cfg_present and omen_surface_ok)
    verdict = "preconditions_ready" if hard_ok else "not_ready"

    steps = []
    if not fronted:
        steps.append("stage a FRONTED Lumberjacks handshake window (needs_password / ban / "
                     "permit-list) so admission is provably Lumberjacks-decided (I5)")
    if not injection_staged:
        steps.append("stage the Lumberjacks synthetic-fixture (e.g. Wood) injection window (I4)")
    steps.append("arm am4: ownershipPinEnabled + zdoRedirectEnabled + handshakeResponderEnabled = "
                 "true (tailnet endpoints http://100.124.12.37:4000 + matching window ids); restart am4")
    steps.append("arm OMEN: zdoInjectionEnabled = true (endpoint http://127.0.0.1:4000 + window id)")
    steps.append("take the pre-window save-integrity snapshot on a fresh idle-restart clock")
    steps.append("DEREK: launch + join; the composed auto-route walks all four mechanisms in one window")
    steps.append("wire-validate the composition holds (no desync/crash) + run each subsystem gate")

    return {
        "ok": True,
        "verdict": verdict,
        "ready_to_begin_armed_window": hard_ok,
        "checks": checks,
        "compose_target": {
            "am4_arm": list(_COMPOSE_AM4_ARM_FLAGS),
            "omen_arm": ["zdoInjectionEnabled"],
            "env_invariant": "I6 Steam-only (CROSSPLAY=false, already set on am4)",
        },
        "window_steps_remaining": steps,
        "scope": "physical_rig_preconditions_only_composition_validated_in_game",
        "note": "preconditions_ready means the rig can BEGIN the P7/I7 armed window; it does NOT "
                "mean the composition passed. The live gate is P7 steps 5-6 (one client in-world, "
                "no desync/crash, world intact on reload).",
    }


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
        valheim_tail_ownership_churn,
        valheim_ownership_churn_summary,
        valheim_tail_ownership_pin,
        valheim_ownership_pin_status,
        valheim_tail_zdo_redirect,
        valheim_zdo_redirect_status,
        valheim_lumberjacks_receipts,
        valheim_zdo_redirect_gate,
        valheim_tail_zdo_injection,
        valheim_zdo_injection_status,
        valheim_lumberjacks_injection,
        valheim_zdo_injection_gate,
        valheim_handshake_trace,
        valheim_handshake_gate,
        valheim_handshake_preflight,
        valheim_loopback_preflight,
        valheim_server_log_tail,
        valheim_save_integrity,
    ]
