from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from comfy_gateway.kernel.auth import AuthRegistry
from comfy_gateway.kernel.ledger import Ledger, new_event
from comfy_gateway.toolsurface import valheim


class GatewayBasicsTest(unittest.TestCase):
    def test_ledger_append_and_query(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            ledger = Ledger(tmp)
            event_id = ledger.append(new_event(
                {"id": "tester", "runner_class": "human", "node": "omen"},
                "smoke",
                args={"x": 1},
                result={"ok": True},
            ))

            events = ledger.query()
            self.assertEqual(event_id, events[0]["event_id"])
            self.assertEqual("smoke", events[0]["tool"])

    def test_auth_resolves_known_key(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            callers = Path(tmp) / "callers.json"
            callers.write_text(
                json.dumps({"key": {"id": "tester", "runner_class": "human", "node": "omen"}}),
                encoding="utf-8",
            )

            caller = AuthRegistry(callers_path=callers).resolve("key")
            self.assertIsNotNone(caller)
            self.assertEqual("tester", caller.id)

    def test_valheim_report_from_temp_jsonl(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "telemetry-client.jsonl").write_text(
                "\n".join([
                    json.dumps({"session_id": "s1", "fps": 60.0, "frame_time_p95_ms": 16.6, "rtt_ms": 10, "cpu_bound_estimate": 0.1}),
                    json.dumps({"session_id": "s1", "fps": 50.0, "frame_time_p95_ms": 20.0, "rtt_ms": 20, "cpu_bound_estimate": 0.2}),
                ])
                + "\n",
                encoding="utf-8",
            )
            (root / "event-timeline.jsonl").write_text(
                json.dumps({"session_id": "s1", "event_name": "dev_marker"}) + "\n",
                encoding="utf-8",
            )
            old_root = valheim.NETWORK_SENSE_DIR
            try:
                valheim.NETWORK_SENSE_DIR = root
                report = valheim.valheim_networksense_report(sample_count=10)
                sessions = valheim.valheim_list_sessions()
                bundle = valheim.valheim_session_bundle("latest")
                next_test = valheim.valheim_suggest_next_test()
            finally:
                valheim.NETWORK_SENSE_DIR = old_root

            self.assertEqual(2, report["sample_count"])
            self.assertEqual(55.0, report["averages"]["fps"])
            self.assertFalse(report["server_pulse_available"])
            self.assertEqual("s1", sessions["latest_session_id"])
            self.assertEqual("s1", bundle["session_id"])
            self.assertTrue(next_test["suggestions"])

    def test_apply_config_profile_uses_whitelist(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            cfg = Path(tmp) / "djcdevelopment.valheim.comfynetworksense.cfg"
            cfg.write_text(
                "\n".join([
                    "liveSampleIntervalSeconds = 0.5",
                    "serverPulseIntervalSeconds = 3",
                    "writeTelemetryLogs = false",
                ])
                + "\n",
                encoding="utf-8",
            )
            old_cfg = valheim.NETWORK_SENSE_CFG
            try:
                valheim.NETWORK_SENSE_CFG = cfg
                result = valheim.valheim_apply_config_profile("multiplayer_pulse")
            finally:
                valheim.NETWORK_SENSE_CFG = old_cfg

            self.assertTrue(result["ok"])
            text = cfg.read_text(encoding="utf-8")
            self.assertIn("serverPulseIntervalSeconds = 2", text)
            self.assertIn("writeTelemetryLogs = true", text)

    def test_netcode_gate_tools_are_registered(self) -> None:
        names = {tool.__name__ for tool in valheim.get_tools()}
        self.assertTrue({
            "valheim_zdo_redirect_gate",
            "valheim_zdo_injection_status",
            "valheim_lumberjacks_injection",
            "valheim_zdo_injection_gate",
        }.issubset(names))

    def test_injection_summary_requires_terminal_lifecycle(self) -> None:
        running = valheim._summarize_injection_rows([
            {"event": "injection_start", "window_id": "i4-test", "rendered": 0},
            {"event": "injection_rendered", "window_id": "i4-test", "owner": "7"},
        ])
        self.assertFalse(running["counters_are_authoritative"])
        stopped = valheim._summarize_injection_rows([
            {"event": "injection_start", "window_id": "i4-test"},
            {"event": "injection_rendered", "window_id": "i4-test", "owner": "7"},
            {"event": "injection_auto_stop", "window_id": "i4-test", "authority_id": "7",
             "polls": 2, "poll_errors": 0, "received": 1, "applied": 1,
             "rendered": 1, "rejected": 0, "duplicates": 0, "awaiting_render": 0},
        ])
        self.assertTrue(stopped["counters_are_authoritative"])
        self.assertEqual(1, stopped["counters"]["rendered"])


if __name__ == "__main__":
    unittest.main()
