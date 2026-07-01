"""Cut a Valheim flythrough recording into a gallery.

Standard library only; media work is delegated to ffmpeg/ffprobe.

Dry run:
  python handoffs/video_to_gallery.py flythrough.mp4 handoffs/timeline.sample.json --dry-run --duration 60

Real run:
  python handoffs/video_to_gallery.py flythrough.mp4 timeline.json --offset 4.2 --out gallery
"""
import argparse
import json
import math
import os
import re
import shutil
import subprocess
import sys


def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def require_number(value, where):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ValueError(f"{where} must be a finite number")
    return float(value)


def validate_timeline(data):
    if not isinstance(data, dict):
        raise ValueError("timeline must be a JSON object")
    events = data.get("events")
    if not isinstance(events, list) or not events:
        raise ValueError("timeline.events must be a non-empty array")

    validated = []
    for i, event in enumerate(events):
        if not isinstance(event, dict):
            raise ValueError(f"events[{i}] must be an object")
        rank = event.get("rank")
        if isinstance(rank, bool) or not isinstance(rank, int) or rank < 1:
            raise ValueError(f"events[{i}].rank must be a positive integer")
        arrived = require_number(event.get("arrived_s"), f"events[{i}].arrived_s")
        left = require_number(event.get("left_s"), f"events[{i}].left_s")
        if arrived < 0:
            raise ValueError(f"events[{i}].arrived_s must be >= 0")
        if left <= arrived:
            raise ValueError(f"events[{i}].left_s must be greater than arrived_s")
        validated.append(event)

    ranks = [e["rank"] for e in validated]
    if len(ranks) != len(set(ranks)):
        raise ValueError("timeline.events contains duplicate ranks")
    return sorted(validated, key=lambda e: e["rank"])


def slugify(value, fallback):
    text = str(value or "").strip().lower()
    text = re.sub(r"[^a-z0-9]+", "_", text).strip("_")
    return text or fallback


def caption_for(event):
    bits = [f"#{event['rank']}"]
    owner = event.get("owner")
    label = event.get("label")
    if owner:
        bits.append(str(owner))
    elif label:
        bits.append(str(label))
    pieces = event.get("pieceCount")
    if isinstance(pieces, int):
        bits.append(f"{pieces:,} pieces")
    return " - ".join(bits)


def drawtext_escape(text):
    # ffmpeg drawtext treats these characters as syntax unless escaped.
    return str(text).replace("\\", "\\\\").replace(":", "\\:").replace("'", "\\'").replace(",", "\\,")


def ffprobe_duration(video_path):
    if not shutil.which("ffprobe"):
        raise RuntimeError("ffprobe was not found on PATH; install ffmpeg or pass --duration with --dry-run")
    cmd = [
        "ffprobe",
        "-v",
        "error",
        "-show_entries",
        "format=duration",
        "-of",
        "default=noprint_wrappers=1:nokey=1",
        video_path,
    ]
    result = subprocess.run(cmd, check=True, capture_output=True, text=True)
    return require_number(result.stdout.strip(), "video duration")


def clamp_interval(arrived, left, offset, pad, duration):
    start = max(0.0, arrived + offset - pad)
    end = left + offset + pad
    if duration is not None:
        end = min(duration, end)
    if end <= start:
        raise ValueError(f"computed empty clip interval: start={start:.3f}, end={end:.3f}")
    return start, end, start + ((end - start) / 2.0)


def format_seconds(value):
    return f"{value:.3f}"


def build_commands(video, clip_path, still_path, start, end, mid, caption=None, reencode=False):
    clip_cmd = ["ffmpeg", "-y", "-ss", format_seconds(start), "-to", format_seconds(end), "-i", video]
    still_cmd = ["ffmpeg", "-y", "-ss", format_seconds(mid), "-i", video, "-frames:v", "1"]

    if caption:
        filter_arg = (
            "drawtext=text='"
            + drawtext_escape(caption)
            + "':x=24:y=h-th-24:fontsize=34:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=12"
        )
        clip_cmd += ["-vf", filter_arg, "-c:v", "libx264", "-preset", "veryfast", "-crf", "18", "-c:a", "copy"]
        still_cmd += ["-vf", filter_arg]
    elif reencode:
        clip_cmd += ["-c:v", "libx264", "-preset", "veryfast", "-crf", "18", "-c:a", "copy"]
    else:
        clip_cmd += ["-c", "copy"]

    clip_cmd.append(clip_path)
    still_cmd.append(still_path)
    return clip_cmd, still_cmd


def run_or_print(cmd, dry_run):
    print(" ".join(quote_arg(part) for part in cmd))
    if not dry_run:
        subprocess.run(cmd, check=True)


def quote_arg(value):
    text = str(value)
    if not text or re.search(r"\s", text):
        return '"' + text.replace('"', '\\"') + '"'
    return text


def write_manifest(out_dir, items, dry_run):
    manifest_path = os.path.join(out_dir, "gallery.json")
    data = {"count": len(items), "items": items}
    print(f"write {manifest_path}")
    if not dry_run:
        with open(manifest_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
            f.write("\n")


def main(argv):
    parser = argparse.ArgumentParser(description="Cut a flythrough video into per-build clips and stills.")
    parser.add_argument("video", help="input video file, for example flythrough.mp4")
    parser.add_argument("timeline", help="timeline.json from the flight-path mod")
    parser.add_argument("--out", default="gallery", help="output directory (default: gallery)")
    parser.add_argument("--offset", type=float, default=0.0, help="seconds from video start to timeline t=0")
    parser.add_argument("--pad", type=float, default=0.5, help="seconds to add before/after each event")
    parser.add_argument("--duration", type=float, help="video duration in seconds; normally detected with ffprobe")
    parser.add_argument("--caption", action="store_true", help="burn captions into clips and stills")
    parser.add_argument("--reencode", action="store_true", help="re-encode clips instead of stream-copying")
    parser.add_argument("--dry-run", action="store_true", help="print ffmpeg commands and manifest path only")
    args = parser.parse_args(argv)

    if args.pad < 0:
        raise ValueError("--pad must be >= 0")
    if args.duration is not None and args.duration <= 0:
        raise ValueError("--duration must be > 0")
    if args.caption:
        args.reencode = True

    timeline = load_json(args.timeline)
    events = validate_timeline(timeline)

    duration = args.duration
    if duration is None and not args.dry_run:
        duration = ffprobe_duration(args.video)

    if not args.dry_run:
        if not shutil.which("ffmpeg"):
            raise RuntimeError("ffmpeg was not found on PATH")
        os.makedirs(args.out, exist_ok=True)

    items = []
    for event in events:
        rank = event["rank"]
        name = slugify(event.get("owner") or event.get("label"), f"rank{rank}")
        stem = f"{rank:02d}_{name}"
        clip = f"{stem}.mp4"
        still = f"{stem}.jpg"
        start, end, mid = clamp_interval(
            require_number(event["arrived_s"], f"rank {rank} arrived_s"),
            require_number(event["left_s"], f"rank {rank} left_s"),
            args.offset,
            args.pad,
            duration,
        )
        caption = caption_for(event)
        clip_cmd, still_cmd = build_commands(
            args.video,
            os.path.join(args.out, clip),
            os.path.join(args.out, still),
            start,
            end,
            mid,
            caption if args.caption else None,
            args.reencode,
        )
        run_or_print(clip_cmd, args.dry_run)
        run_or_print(still_cmd, args.dry_run)
        items.append(
            {
                "rank": rank,
                "owner": event.get("owner"),
                "label": event.get("label"),
                "pieceCount": event.get("pieceCount"),
                "clip": clip,
                "still": still,
                "caption": caption,
            }
        )

    write_manifest(args.out, items, args.dry_run)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except (OSError, RuntimeError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
