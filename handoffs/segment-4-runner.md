# Segment 4 runner

`video_to_gallery.py` is the executable version of the Segment 4 handoff. It consumes a recording and
`timeline.json`, then emits `gallery/` with one clip, one still, and a `gallery.json` manifest per
timeline event.

## Dry run

No media tools are needed for this check:

```powershell
python .\handoffs\video_to_gallery.py flythrough.mp4 .\handoffs\timeline.sample.json --dry-run --duration 60
```

## Real run

Install ffmpeg so both `ffmpeg` and `ffprobe` are on `PATH`, then run:

```powershell
python .\handoffs\video_to_gallery.py flythrough.mp4 timeline.json --offset 4.2 --out gallery
```

Use `--offset` when recording started before the Segment 3 countdown finished. Use `--caption` to burn
captions into outputs; that forces video re-encoding. Without captions, clips use `-c copy` for speed.
