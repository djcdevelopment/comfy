# Segment 1 — Waypoints from a world save (extraction)

**Goal:** Turn a Valheim world save into `waypoints.json` — a ranked list of the most build-dense
locations, each attributed to a player. This is the input every downstream segment consumes.

**Status: built.** This segment is *composition*, not new construction: it reuses an existing Valheim
`.db` parser + REST dashboard (`ComfyStewardView`) and a ~60-line standalone script. No parser code
was changed. Build/test against [`waypoints.sample.json`](waypoints.sample.json); the current real
output lives at the repo root as `waypoints.json`.

You need to know how to build/run a Java app and run a Python script. You do **not** need to
understand the parser's internals.

## Inputs
- A Valheim world save (`.db` + `.fwl`).
- `ComfyStewardView` — the Java `.db` parser + dashboard (separate repo). Its own `docs/comfy-
  integration/BUILD_GUIDE.md` has the 10-step build; the short version is: install Java 17, run the
  prebuilt fat JAR against the `.db`:
  ```
  java -Xmx6g -jar viewer/target/world-viewer-1.0.0.jar <path>/<World>.db --port 7080 --no-browser
  ```
  (put its `classification.json` next to the `.db` or in the working dir). ~15–30 s to parse a ~1.3 GB save.

## Steps
1. Run the StewardView server on the `.db` (above). Wait for `GET /api/v1/status` → `"done": true`.
2. Run the emitter (standard library only):
   ```
   python segment-1-emit-waypoints.py [base_url] [topN] [out_path]
   # defaults: http://localhost:7080/api/v1  15  ./waypoints.json
   ```

## How it works (so it's maintainable, not magic)
- **Rank** by build density: `GET /api/v1/heatmap?type=BUILDING` gives per-500m-cell building-piece
  counts; sort descending.
- **Attribute** each top cell: query owned points inside the cell's bbox
  (`GET /api/v1/points?cat=PORTAL|CONTAINER|BED&minX=&maxX=&minZ=&maxZ=`), and take the most common
  `owner`. Portals are the cleanest signal (they carry an owner and a name/label).
- **De-dupe** so the gallery stays varied: one waypoint per builder, and skip cells adjacent to an
  already-chosen cell (one big build spilling across cells becomes one waypoint).
- **Aim** the camera at the *centroid* of the owned points in the cell (where the build actually is),
  not the cell corner.
- `owner` is `null` when a dense cell has no nearby personal ownership — that's real signal
  (communal/guild builds); keep them, the flight can caption them "communal build."

## Output
`waypoints.json` per the contract in [`README.md`](README.md). See [`waypoints.sample.json`](waypoints.sample.json)
for a stable fixture.

## Definition of done (self-verifiable)
- `waypoints.json` validates against the contract, has `topN` entries in descending `pieceCount`,
  distinct builders where attributable, and real coordinates. (Sanity check: eyeball that owners look
  like player names and coordinates fall within the world's bounds.)

## Constraints
- Emitter: Python standard library only.
- Don't modify the parser to get attribution — composition of existing endpoints is deliberate and
  sufficient. (If you ever want *exact* per-piece creator attribution instead of "nearest owned
  point," that's a parser change + rebuild — out of scope, and the point-based approach is plenty for
  a gallery.)
