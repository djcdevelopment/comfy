# ComfyNetworkSense Live Test Checklist
*Solo Developer — Unity/Valheim BepInEx Plugin*

Condensed operator quick-reference for `NETWORKSENSE-PERF-DEBUG-PLAN.md` Test A / Test B.
Drafted via HEARTH local_generate (qwen3-coder:30b) — 2026-07-08.

---

### **Test A: Load Only**
1. Launch Valheim with ComfyNetworkSense 0.4.3
2. Load Era16
3. Do not run route
4. Stand still for 2 minutes after player spawn
5. Observe hitches before any route command

Expected signal: hitches tied to load/portal/log/sample startup

---

### **Test B: Perf-Only Route**
Config: `writeTelemetryLogs=true`, `liveSampleIntervalSeconds=999`, `serverPulseIntervalSeconds=999`, `perfProbeEnabled=true`

1. Run one-stop route to `open_control`
2. Run one-stop routes to each density coordinate
3. Teleport and wait for quiet
4. Observe hitches after teleport

Expected signal: if 10s hitches remain, base teleport/zone/portal work dominates

---

### **Diagnostic Decision Table**

| Signal Seen | Hypothesis | Action |
|-------------|------------|--------|
| Hitches align with ConnectPortals/Loaded/Unloading assets/teleport boundaries | H1 | Confirm timing; disable telemetry to verify |
| Hitches align with Unity warnings/sec (hundreds) | H2 | Check engine logs; no NetworkSense section accounts for stall |
| Hitches align with ClientTelemetrySampler.Capture/scene scan/ServerPulseBroadcaster.Update | H3 | Toggle scan/pulse/logging; check perf-hitches.jsonl |
| Writer queue depth grows during load; hitches with enqueue/flush/disk I/O | H4 | Observe telemetry stop before shutdown |
| Hitches align with OnApplicationQuit/PrepareSave/ZDOs saved | H5 | Mark as save cost; keep benchmark windows outside it |

---

### **Resolution Rule**
*Use evidence not guesses — if NetworkSense sections explain it, fix that path before rerun; if engine logs explain it, mark as load/portal/save cost and keep benchmark windows outside it; if both contribute, split into phases; exit without OnApplicationQuit => capture crash dumps before touching telemetry logic.*

---

### **Post-Test Analysis**
Run: `.\fieldlab\scripts\analyze-networksense-perf.ps1`
Reads: `perf-hitches.jsonl`, `perf-sections.jsonl`
