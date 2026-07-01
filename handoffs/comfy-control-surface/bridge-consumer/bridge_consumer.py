#!/usr/bin/env python3
"""Render ComfyControlSurface outbox payloads into local review markdown.

Usage:
  python bridge_consumer.py <comfy-control-root-or-fixture-dir> [out-dir]

If the input contains an outbox/ directory, payloads are read from outbox/*.json.
Otherwise, *.json files in the input directory are treated as fixture payloads.
"""
import json
import math
import os
import sys
from datetime import datetime, timezone


SLAYER_RANKS = {"Thrall", "Thegn", "Jarl"}


def load_json(path):
    with open(path, encoding="utf-8-sig") as f:
        return json.load(f)


def require_object(value, where):
    if not isinstance(value, dict):
        raise ValueError(f"{where} must be an object")
    return value


def require_string(data, key, where):
    value = data.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{where}.{key} must be a non-empty string")
    return value


def optional_string(data, key, where):
    value = data.get(key)
    if value is None:
        return None
    if not isinstance(value, str):
        raise ValueError(f"{where}.{key} must be a string or null")
    return value


def require_number(data, key, where):
    value = data.get(key)
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ValueError(f"{where}.{key} must be a finite number")
    return float(value)


def validate_payload(data, path):
    require_object(data, "payload")
    if data.get("schema_version") != 1:
        raise ValueError(f"{path}: schema_version must be 1")
    if data.get("status") != "ready_for_review":
        raise ValueError(f"{path}: status must be ready_for_review")

    payload = {
        "submission_id": require_string(data, "submission_id", "payload"),
        "run_id": require_string(data, "run_id", "payload"),
        "action_id": require_string(data, "action_id", "payload"),
        "submission_type": require_string(data, "submission_type", "payload"),
        "created_at_utc": require_string(data, "created_at_utc", "payload"),
    }

    player = require_object(data.get("player"), "payload.player")
    world = require_object(data.get("world"), "payload.world")
    workflow = data.get("workflow") if isinstance(data.get("workflow"), dict) else {}
    position = require_object(data.get("position"), "payload.position")
    evidence = require_object(data.get("evidence"), "payload.evidence")
    trace = require_object(data.get("trace"), "payload.trace")

    payload["player_name"] = require_string(player, "name", "payload.player")
    payload["player_id"] = optional_string(player, "player_id", "payload.player")
    payload["world_name"] = optional_string(world, "name", "payload.world")
    payload["world_seed"] = optional_string(world, "seed", "payload.world")
    payload["workflow_guild"] = optional_string(workflow, "guild", "payload.workflow")
    payload["workflow_era"] = workflow.get("era")
    payload["workflow_source"] = optional_string(workflow, "source", "payload.workflow")
    payload["workflow_category"] = optional_string(workflow, "category", "payload.workflow")
    payload["workflow_rank"] = optional_string(workflow, "rank", "payload.workflow")
    payload["workflow_tier"] = workflow.get("tier")
    payload["workflow_bot_command_template"] = optional_string(
        workflow, "bot_command_template", "payload.workflow"
    )
    payload["x"] = require_number(position, "x", "payload.position")
    payload["y"] = require_number(position, "y", "payload.position")
    payload["z"] = require_number(position, "z", "payload.position")
    payload["biome"] = require_string(position, "biome", "payload.position")
    payload["screenshot"] = require_string(evidence, "screenshot", "payload.evidence")
    payload["trace_id"] = require_string(trace, "trace_id", "payload.trace")
    payload["trace_file"] = require_string(trace, "trace_file", "payload.trace")
    payload["notes"] = data.get("notes") if isinstance(data.get("notes"), str) else ""

    if payload["submission_type"].endswith("_rank_proof"):
        rank = slayer_rank(payload)
        if payload["submission_type"] == "slayer_rank_proof" and rank not in SLAYER_RANKS:
            allowed = ", ".join(sorted(SLAYER_RANKS))
            raise ValueError(f"{path}: Slayer rank must be one of {allowed}")
        if not rank:
            raise ValueError(f"{path}: rank proof payload must include workflow.rank")

    return payload


def discover_payloads(input_dir):
    outbox = os.path.join(input_dir, "outbox")
    payload_dir = outbox if os.path.isdir(outbox) else input_dir
    return sorted(
        os.path.join(payload_dir, name)
        for name in os.listdir(payload_dir)
        if name.lower().endswith(".json")
    )


def render_review(payload, source_path, input_root):
    screenshot_abs = os.path.normpath(os.path.join(input_root, payload["screenshot"]))
    trace_abs = os.path.normpath(os.path.join(input_root, payload["trace_file"]))
    bot_line = render_command(payload)

    return "\n".join([
        f"# Submission {payload['submission_id']}",
        "",
        "## Review",
        "",
        f"- Status: ready for review",
        f"- Type: {payload['submission_type']}",
        f"- Action: {payload['action_id']}",
        f"- Workflow: {workflow_label(payload)}",
        f"- Created: {payload['created_at_utc']}",
        f"- Player: {payload['player_name']}",
        f"- Player ID: {payload['player_id'] or 'unknown'}",
        f"- World: {payload['world_name'] or 'unknown'}",
        f"- Biome: {payload['biome']}",
        f"- Position: x={payload['x']:.3f}, y={payload['y']:.3f}, z={payload['z']:.3f}",
        "",
        "## Evidence",
        "",
        f"- Screenshot: `{payload['screenshot']}`",
        f"- Screenshot absolute path: `{screenshot_abs}`",
        f"- Trace: `{payload['trace_file']}`",
        f"- Trace absolute path: `{trace_abs}`",
        f"- Source payload: `{source_path}`",
        "",
        "## Copy-paste command draft",
        "",
        "```text",
        bot_line,
        "```",
        "",
        "## Notes",
        "",
        payload["notes"] or "_No notes supplied._",
        "",
    ])


def quote_token(value):
    text = str(value)
    if not text or any(ch.isspace() for ch in text):
        return '"' + text.replace('"', '\\"') + '"'
    return text


def render_command(payload):
    template = payload.get("workflow_bot_command_template")
    rank = payload.get("workflow_rank") or slayer_rank(payload)
    if template and rank:
        return render_template_command(template, payload, rank)

    if payload["submission_type"] == "slayer_rank_proof":
        rank = slayer_rank(payload)
        return f"/slayer submit rank:{quote_token(rank)} proof:{quote_token(payload['screenshot'])}"

    return (
        f"/comfy submit type:{payload['submission_type']} "
        f"player:{quote_token(payload['player_name'])} "
        f"world:{quote_token(payload['world_name'] or 'unknown')} "
        f"x:{payload['x']:.1f} y:{payload['y']:.1f} z:{payload['z']:.1f} "
        f"proof:{quote_token(payload['screenshot'])}"
    )


def render_template_command(template, payload, rank):
    return (
        template.replace("{guild}", str(payload.get("workflow_guild") or "").lower())
        .replace("{rank}", str(rank))
        .replace("{proof}", payload["screenshot"])
    )


def slayer_rank(payload):
    rank = payload.get("workflow_rank")
    if rank:
        return str(rank).strip().title()

    action_id = payload.get("action_id", "")
    if action_id.startswith("slayer_rank_"):
        return action_id.removeprefix("slayer_rank_").replace("_", " ").title()

    return ""


def workflow_label(payload):
    parts = [
        payload.get("workflow_guild"),
        payload.get("workflow_category"),
        payload.get("workflow_rank"),
    ]
    text = " / ".join(str(part) for part in parts if part)
    return text or "none"


def write_review(out_dir, submission_id, text):
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, f"{submission_id}.md")
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    os.replace(tmp, path)
    return path


def utc_now():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def atomic_write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)


def ensure_review_state(out_dir, payload, source_path, review_path):
    state_dir = os.path.join(out_dir, "state")
    state_path = os.path.join(state_dir, f"{payload['submission_id']}.json")
    if os.path.exists(state_path):
        state = load_json(state_path)
        state.update(state_metadata(payload, source_path, review_path, out_dir))
        atomic_write_json(state_path, state)
        return state

    state = {
        "submission_id": payload["submission_id"],
        "status": "pending",
        "reason": "",
        "created_at_utc": utc_now(),
        "updated_at_utc": utc_now()
    }
    state.update(state_metadata(payload, source_path, review_path, out_dir))
    atomic_write_json(state_path, state)
    return state


def state_metadata(payload, source_path, review_path, out_dir):
    return {
        "action_id": payload["action_id"],
        "submission_type": payload["submission_type"],
        "player": payload["player_name"],
        "world": payload["world_name"],
        "workflow_guild": payload["workflow_guild"],
        "workflow_era": payload["workflow_era"],
        "workflow_source": payload["workflow_source"],
        "workflow_category": payload["workflow_category"],
        "workflow_rank": payload["workflow_rank"],
        "workflow_tier": payload["workflow_tier"],
        "workflow_bot_command_template": payload["workflow_bot_command_template"],
        "evidence_screenshot": payload["screenshot"],
        "trace_file": payload["trace_file"],
        "source_payload": os.path.abspath(source_path),
        "review_file": os.path.relpath(review_path, out_dir).replace("\\", "/"),
        "payload_created_at_utc": payload["created_at_utc"]
    }


def write_index(out_dir, items):
    index = {
        "schema_version": 1,
        "generated_at_utc": utc_now(),
        "count": len(items),
        "items": items
    }
    atomic_write_json(os.path.join(out_dir, "index.json"), index)


def main(argv):
    if len(argv) not in (1, 2):
        print(__doc__.strip(), file=sys.stderr)
        return 2

    input_dir = os.path.abspath(argv[0])
    if not os.path.isdir(input_dir):
        print(f"error: input directory not found: {input_dir}", file=sys.stderr)
        return 1

    out_dir = os.path.abspath(argv[1]) if len(argv) == 2 else os.path.join(input_dir, "bridge-review")
    payload_paths = discover_payloads(input_dir)
    if not payload_paths:
        print(f"error: no payload json files found in {input_dir}", file=sys.stderr)
        return 1

    count = 0
    index_items = []
    for path in payload_paths:
        data = load_json(path)
        payload = validate_payload(data, path)
        review = render_review(payload, path, input_dir)
        review_path = write_review(out_dir, payload["submission_id"], review)
        state = ensure_review_state(out_dir, payload, path, review_path)
        index_items.append({
            "submission_id": payload["submission_id"],
            "status": state["status"],
            "submission_type": payload["submission_type"],
            "action_id": payload["action_id"],
            "player": payload["player_name"],
            "world": payload["world_name"],
            "created_at_utc": payload["created_at_utc"],
            "review_file": os.path.relpath(review_path, out_dir).replace("\\", "/")
        })
        print(f"wrote {review_path}")
        count += 1

    write_index(out_dir, index_items)
    print(f"processed {count} payload(s)")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
