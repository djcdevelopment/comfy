#!/usr/bin/env python3
"""Assert one correlated real positive path and one network-absent Importance reject."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def load_rows(path: Path, window: str):
    rows = []
    for number, line in enumerate(path.read_text(encoding="utf-8-sig", errors="replace").splitlines(), 1):
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        if row.get("window_id") == window:
            row["_line"] = number
            rows.append(row)
    return rows


def require(condition: bool, message: str):
    if not condition:
        raise AssertionError(message)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server-jsonl", required=True, type=Path)
    parser.add_argument("--server-log", required=True, type=Path)
    parser.add_argument("--client-log", required=True, type=Path)
    parser.add_argument("--gateway-log", required=True, type=Path)
    parser.add_argument("--status", required=True, type=Path)
    parser.add_argument("--consumer", required=True, type=Path)
    parser.add_argument("--window", required=True)
    parser.add_argument("--release", required=True)
    args = parser.parse_args()

    rows = load_rows(args.server_jsonl, args.window)
    server_log = args.server_log.read_text(encoding="utf-8-sig", errors="replace")
    client_log = args.client_log.read_text(encoding="utf-8-sig", errors="replace")
    gateway_log = args.gateway_log.read_text(encoding="utf-8-sig", errors="replace")
    status = load_json(args.status)
    consumer = load_json(args.consumer)

    positive = consumer.get("first_correlation_id") or consumer.get("last_correlation_id")
    result = consumer.get("first_operation_result") or consumer.get("last_operation_result")
    require(positive, "consumer result surface has no correlated result")
    require(result in {"applied", "superseded"}, "consumer result is not applied/superseded")

    positive_rows = [row for row in rows if row.get("correlation_id") == positive]
    events = {row.get("event"): row for row in positive_rows}
    for event in ("importance_candidate", "importance_allowed", "redirect"):
        require(event in events, f"positive correlation lacks server event {event}")
    require(
        events["importance_candidate"]["_line"]
        < events["importance_allowed"]["_line"]
        < events["redirect"]["_line"],
        "positive server events are out of order",
    )
    require(events["importance_allowed"].get("network_eligible") is True,
            "positive Importance decision was not network eligible")
    require(positive in gateway_log, "Gateway accepted log lacks positive correlation")
    require("caller_identity=private-plane" in gateway_log,
            "Gateway did not authenticate producer as private-plane")
    require(f"mod_release={args.release}" in gateway_log,
            "Gateway accepted log lacks admitted release")
    require(positive in client_log, "Comfy consumer log lacks positive correlation")
    require(f"Lumberjacks contract release={args.release}" in server_log,
            "running server log lacks explicit contract release")
    require(f"Lumberjacks contract release={args.release}" in client_log,
            "running client log lacks explicit contract release")
    require(status.get("receipts", 0) > 0, "Gateway recorded no receipts")
    require(status.get("acknowledged", 0) > 0, "Gateway recorded no acknowledgements")
    require(consumer.get("priority_fast_lane_applied", 0) > 0,
            "consumer did not process an Importance-approved fast-lane item")

    rejected_by_id = {}
    for row in rows:
        correlation = row.get("correlation_id")
        if correlation:
            rejected_by_id.setdefault(correlation, []).append(row)
    negative = None
    for correlation, correlated in rejected_by_id.items():
        kinds = {row.get("event") for row in correlated}
        if "importance_candidate" in kinds and "importance_rejected" in kinds:
            negative = correlation
            require("importance_allowed" not in kinds and "redirect" not in kinds,
                    "rejected item entered the Comfy network queue")
            break
    require(negative, "no Importance-rejected real server candidate was observed")
    require(negative not in gateway_log, "Importance-rejected correlation crossed the Gateway boundary")
    require(negative not in client_log, "Importance-rejected correlation reached the consumer")

    evidence = {
        "verdict": "PASS",
        "window_id": args.window,
        "release": args.release,
        "positive": {
            "correlation_id": positive,
            "importance_class": events["importance_allowed"].get("importance_class"),
            "priority_rank": events["importance_allowed"].get("priority_rank"),
            "consumer_result": result,
            "gateway_receipts": status.get("receipts"),
            "gateway_acknowledged": status.get("acknowledged"),
        },
        "negative": {
            "correlation_id": negative,
            "decision": "importance_rejected",
            "gateway_absent": True,
            "consumer_absent": True,
        },
        "sequence": [
            "server_candidate",
            "importance_allowed",
            "comfy_submitted",
            "gateway_authenticated_private_plane",
            "gateway_admitted_release",
            "gateway_routed_legacy",
            "consumer_processed",
            "comfy_observed_result",
        ],
    }
    print(json.dumps(evidence, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
