# Segment 4 — Video → gallery (cut the flythrough into per-build clips + stills)

**Goal:** Given (a) a screen-recording of a camera flying through a series of locations and (b) a
`timeline.json` that says which location was on screen during which seconds, produce a **gallery**: one
short clip and one still image per location, plus a `gallery.json` manifest with captions. This is a
pure media-processing task — **ffmpeg + any scripting language**. No game, no 3D, no context needed.

You need to know ffmpeg and basic scripting. You do **not** need to know what the locations are or how
the video was made.

## Inputs
1. A video file (e.g. `flythrough.mp4`), any common format/resolution.
2. `timeline.json` (contract below), where times are seconds from the moment the camera *started
   moving.*
3. `--offset` (a single number, default `0`): seconds between the start of the **video** and `t = 0`
   in the timeline. If the operator started recording before triggering the flight, this is that gap.
   Video-time for an event = `event_time + offset`. Expose it as a CLI flag so a human can nudge it.

### `timeline.json` contract
```json
{
  "run_id": "string",
  "t0_meaning": "seconds are measured from first camera movement",
  "events": [
    { "rank": 1, "owner": "Anathema", "label": "densest build cluster", "pieceCount": 20965,
      "arrived_s": 3.0, "left_s": 10.0 }
  ]
}
```
- `owner` may be `null`; fall back to `label` (and `rank`) for the caption.

## Steps
1. Parse `timeline.json`, sort `events` by `rank`.
2. For each event, compute video times: `start = arrived_s + offset`, `end = left_s + offset`. Add a
   small pad (e.g. 0.5 s each side), clamped to the video bounds.
3. **Clip:** `ffmpeg -ss <start> -to <end> -i video.mp4 -c copy gallery/NN_rank_owner.mp4`
   (re-encode instead of `-c copy` if you need frame-accurate cuts).
4. **Still:** grab one frame at the midpoint: `ffmpeg -ss <mid> -i video.mp4 -frames:v 1 gallery/NN_rank_owner.jpg`.
5. **Caption (optional, nice):** burn a caption onto the still/clip via ffmpeg `drawtext`
   (e.g. `#1 · Anathema · 20,965 pieces`). Keep it optional behind a flag.
6. Write `gallery/gallery.json`.

## Output contract — `gallery/`
```
gallery/
  gallery.json
  01_anathema.mp4   01_anathema.jpg
  02_rank2.mp4      02_rank2.jpg
  ...
```
```json
{
  "count": 10,
  "items": [
    { "rank": 1, "owner": "Anathema", "label": "densest build cluster", "pieceCount": 20965,
      "clip": "01_anathema.mp4", "still": "01_anathema.jpg", "caption": "#1 · Anathema · 20,965 pieces" }
  ]
}
```

## Definition of done (self-verifiable)
- Given a sample video + a `timeline.json`, running one command yields a `gallery/` folder with the
  right number of clips + stills, each corresponding to the correct time range, and a valid
  `gallery.json`. (You can fabricate a test: record any 60-second video and a `timeline.json` with a
  few events, and confirm the cuts land where the timestamps say.)

## Constraints
- ffmpeg only for media; standard library for the rest. No cloud services, no heavy frameworks.
- Deterministic: same inputs → same outputs. All timing derived from `timeline.json` + `offset`.

## Explicitly NOT your problem
- Producing the video (a human records it) or the `timeline.json` (Segment 3 emits it).
- Choosing which builds matter (that was decided upstream and is baked into the timeline order).
