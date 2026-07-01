# Handoff kit — the in-game "gallery" camera pipeline

This folder decomposes one end-to-end capability — *turn a saved Valheim world into a flythrough
video of its most impressive builds* — into **independent segments**, each written to be handed to a
**different builder, on a different machine, using a different AI model, with none of the surrounding
context.**

The rule that makes that possible: **the interfaces below are the only shared context.** A segment
brief tells its builder exactly what file comes in and what file goes out. Nobody needs to know about
"Comfy," this project, or each other. Build to the contract; the pieces snap together.

## The pipeline (data flows left to right)

```
 world .db  ──[Segment 1: extraction, ALREADY BUILT]──▶  waypoints.json
                                                              │
 waypoints.json + a running modded Valheim ──[Segment 2/3: fly it]──▶  timeline.json  (+ live capture)
                                                              │
 recorded video + timeline.json ──[Segment 4: cut it]──▶  gallery/  (clips + stills + gallery.json)
```

- **Recording is a solved problem and is NOT a segment.** Any screen recorder (OBS, Discord "Go
  Live", ShadowPlay) captures the flythrough. The pipeline only needs the resulting video file and
  the `timeline.json` that says *which build is on screen at which second.*

## The contracts (the only shared knowledge)

### `waypoints.json` — produced by Segment 1, consumed by Segment 3
A ranked list of world locations to visit. `x`/`z` are Valheim world coordinates (horizontal); `y`
(height) is optional — the flight code resolves ground height itself. See `waypoints.sample.json` in
this folder for a **real fixture** you can build and test against with zero other context.
```json
{
  "world": "string (label only)",
  "cellSize": 500,
  "waypoints": [
    {
      "rank": 1,
      "x": 3250.0,
      "z": 2250.0,
      "y": null,
      "owner": "Anathema",          // may be null; display label only
      "label": "densest build cluster",
      "pieceCount": 20965,          // for the caption; ignore if you don't need it
      "dwellSeconds": 6             // how long the camera lingers here
    }
  ]
}
```

### `timeline.json` — produced by Segment 3, consumed by Segment 4
For each waypoint the flight visited, the seconds (relative to the moment the flight started moving,
`t = 0`) when the camera arrived and left. This is what lets the video be cut without anyone eyeballing it.
```json
{
  "run_id": "string",
  "t0_meaning": "seconds are measured from first camera movement",
  "events": [
    { "rank": 1, "owner": "Anathema", "label": "densest build cluster",
      "pieceCount": 20965, "arrived_s": 3.0, "left_s": 9.0 }
  ]
}
```

### `gallery/` — produced by Segment 4 (the final artifact)
A folder of per-build clips + stills and a `gallery.json` manifest tying each to its rank/owner/caption.

## The segments

| # | Brief | Hand to someone who knows… | In → Out |
|---|---|---|---|
| 1 | [`segment-1-waypoints-from-world.md`](segment-1-waypoints-from-world.md) **(built)** | Java + Python | world `.db` → `waypoints.json` |
| 2 | [`segment-2-get-into-the-world.md`](segment-2-get-into-the-world.md) | Valheim + BepInEx basics | a world save → a running, mod-loadable Valheim in that world |
| 3 | [`segment-3-flight-path-mod.md`](segment-3-flight-path-mod.md) | C# / Unity / BepInEx modding | `waypoints.json` → a live flythrough + `timeline.json` |
| 4 | [`segment-4-video-to-gallery.md`](segment-4-video-to-gallery.md) + [`segment-4-runner.md`](segment-4-runner.md) | ffmpeg + any scripting | video + `timeline.json` → `gallery/` |

Before building Segment 3, run the proof kit in
[`valheim-camera-proof/`](valheim-camera-proof/README.md). It verifies the actual obstacle: this
machine can load the save, load BepInEx, see `Player.m_localPlayer`, teleport to a waypoint, and write
proof files.

**Segment 1 (extraction) is built** — see its brief, the emitter `segment-1-emit-waypoints.py`, and
the real output `waypoints.json` (Era 16's top 15 clusters, attributed to their builders). It's pure
composition of two existing endpoints — no parser change. Downstream segments can develop against
either the real `waypoints.json` or the `waypoints.sample.json` fixture; both share the contract shape.

## Two other slices (separate handoffs, same template — not in this pipeline)
- **A Discord bot** (the community-facing "control surface"): its own brief, out of scope here.
- **A general Valheim mod** (the toolchain that Segment 3 is a specific instance of): Segment 2 + 3
  together already establish it; a standalone "how to build any Valheim mod" brief can be extracted
  from Segment 3 later.

## For the coordinator (you)
Hand each builder **only their brief + the contract files they touch** (the two JSON schemas above and
`waypoints.sample.json`). Do not hand them this project's history. If a builder needs to know anything
that isn't in their brief or a contract, that's a bug in the decomposition — fix the brief, not the
builder.
