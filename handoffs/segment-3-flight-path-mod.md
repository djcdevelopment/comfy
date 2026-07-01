# Segment 3 — Flight-path mod (fly the camera through a list of coordinates)

**Goal:** A **BepInEx plugin for Valheim** that, on a hotkey, reads a list of world coordinates from
`waypoints.json`, flies the player-camera to each one in turn, lingers for a set time, and writes a
`timeline.json` recording *when* it was at each place. A person screen-records the game while this
runs; the `timeline.json` is what lets the recording be cut up later.

You need to know C# and basic Unity/BepInEx Valheim modding. You do **not** need to know where the
coordinates come from or what happens to the video afterward. Build against the fixture
`waypoints.sample.json` (real data, provided).

## Input contract — `waypoints.json`
```json
{
  "world": "string",
  "cellSize": 500,
  "waypoints": [
    { "rank": 1, "x": 3250.0, "z": 2250.0, "y": null,
      "owner": "Anathema", "label": "densest build cluster", "pieceCount": 20965, "dwellSeconds": 7 }
  ]
}
```
- `x`, `z` = Valheim world coordinates (horizontal plane). Always present.
- `y` = height; usually `null` → **you resolve ground height yourself** and place the camera above it.
- `dwellSeconds` = how long to linger before moving on.
- `owner`, `label`, `pieceCount`, `rank` = pass-through metadata; copy them into `timeline.json`.

## Output contract — `timeline.json`
Times are seconds from the moment the camera **first starts moving** (`t = 0`).
```json
{
  "run_id": "string (any unique id, e.g. a timestamp you print at start)",
  "t0_meaning": "seconds are measured from first camera movement",
  "events": [
    { "rank": 1, "owner": "Anathema", "label": "densest build cluster", "pieceCount": 20965,
      "arrived_s": 3.0, "left_s": 10.0 }
  ]
}
```

## Behavior
1. On a configurable hotkey (default e.g. `F8`), load `waypoints.json` from a known path (a BepInEx
   config value; default `BepInEx/config/waypoints.json`).
2. **Countdown for recording sync:** print an on-screen/logged 3-2-1 countdown, THEN begin moving.
   `t = 0` is the first movement. (This gives the human a clean cue to have recording already rolling.)
3. For each waypoint, in order:
   - Resolve ground height at `(x, z)` and set the camera to a good vantage above/beside the build
     (a configurable height + pitch; a downward-ish angle from ~30–60 m up reads well). Ensure the
     area is loaded (force nearby zone generation if needed) before the dwell so the build is rendered.
   - Record `arrived_s`, dwell `dwellSeconds`, record `left_s`, then proceed.
4. On finish, write `timeline.json` next to `waypoints.json`.

**Two acceptable movement modes — ship the simple one first:**
- **Teleport (do this first):** hard-cut between waypoints. Trivial, and perfect for stills.
- **Glide (enhancement):** interpolate the camera position between waypoints over ~2–3 s for a smooth
  cinematic pan. Same interface; just nicer footage.

## API hints (so your AI can implement fast)
- `Player.m_localPlayer` — the local player. Position via its transform / `TeleportTo(pos, rot, distantTeleport:true)`.
- Ground height: `ZoneSystem.instance.GetGroundHeight(new Vector3(x, 0, z), out float h)` (or the
  `GetSolidHeight` variant); world position is `new Vector3(x, h + cameraHeight, z)`.
- Force-load area: nudge `ZNetScene` / wait a frame or two after teleport so pieces render before capture.
- Use a coroutine for the dwell timing; use `Time.time` deltas for the timeline.

## Definition of done (self-verifiable, using the fixture)
- Drop in `waypoints.sample.json`, press the hotkey: the camera visits all 10 coordinates in rank
  order, lingering at each, with the builds rendered (not empty terrain).
- A valid `timeline.json` is written whose `events` match the waypoints and whose `arrived_s`/`left_s`
  increase monotonically.
- Deliverable: the built `.dll` plugin + a one-paragraph README (hotkey, config path, how `t=0` works).

## Constraints
- Single-player / local world only (the segment before you set that up).
- No network calls, no external services. Read one JSON, write one JSON.

## Explicitly NOT your problem
- Producing `waypoints.json` (a separate tool does; you consume it).
- Recording the screen (a human does that with OBS/Discord).
- Cutting the video (Segment 4 consumes your `timeline.json`).
