#!/usr/bin/env python3
"""Generate ComfyControlSurface actions from a rank-ladder recipe output.

Usage:
  python generate-actions-from-rank-ladder.py <rank-ladder.json> [actions.json]
"""
import json
import re
import sys
from pathlib import Path


def slug(text):
    value = re.sub(r"[^a-z0-9]+", "_", str(text).lower()).strip("_")
    return value or "unknown"


def guild_slug(guild):
    value = slug(guild)
    if value.endswith("s") and len(value) > 1:
        value = value[:-1]
    return value


def load_json(path):
    with open(path, encoding="utf-8-sig") as f:
        return json.load(f)


def action_from_rank(data, rank):
    guild = data["guild"]
    guild_id = guild_slug(guild)
    rank_name = (rank.get("reward") or {}).get("rank") or rank["name"]
    rank_id = slug(rank_name)

    return {
        "action_id": f"{guild_id}_rank_{rank_id}",
        "label": f"{guild}: {rank_name} Proof",
        "description": f"Create a local proof submission for {guild} rank {rank_name}.",
        "submission_type": f"{guild_id}_rank_proof",
        "workflow": {
            "guild": guild,
            "era": data.get("era"),
            "source": data.get("source"),
            "category": "rank_proof",
            "rank": rank_name,
            "tier": rank.get("tier"),
            "bot_command_template": data["bot_command_template"],
        },
        "requires_screenshot": True,
        "requires_target": False,
        "bridge": {
            "kind": "file",
            "out_dir": "BepInEx/config/comfy-control/outbox",
        },
    }


def generate(data):
    for key in ("guild", "ranks", "bot_command_template"):
        if key not in data:
            raise ValueError(f"missing rank-ladder field: {key}")

    actions = [
        action_from_rank(data, rank)
        for rank in sorted(data["ranks"], key=lambda item: item.get("tier", 0))
        if rank.get("tier", 0) >= 1
    ]

    if not actions:
        raise ValueError("rank ladder did not contain any rank-up tiers")

    return {
        "schema_version": 1,
        "source": {
            "kind": "rank-ladder",
            "guild": data["guild"],
            "era": data.get("era"),
            "source": data.get("source"),
            "bot_command_is_placeholder": data.get("bot_command_is_placeholder", False),
        },
        "actions": actions,
    }


def main(argv):
    if len(argv) not in (1, 2):
        print(__doc__.strip(), file=sys.stderr)
        return 2

    source = Path(argv[0])
    output = Path(argv[1]) if len(argv) == 2 else None
    actions = generate(load_json(source))
    text = json.dumps(actions, indent=2) + "\n"

    if output:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(text, encoding="utf-8", newline="\n")
    else:
        print(text, end="")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
