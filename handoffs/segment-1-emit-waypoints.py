#!/usr/bin/env python3
"""Segment 1 — emit waypoints.json from a running ComfyStewardView server.

Composes two existing endpoints (no code change to the parser):
  /api/v1/heatmap?type=BUILDING   -> rank locations by building-piece density
  /api/v1/points?cat=...&bbox     -> attribute each location to a player via nearby owned points

Usage:  python segment-1-emit-waypoints.py [base_url] [topN] [out_path]
Defaults: http://localhost:7080/api/v1  15  ./waypoints.json
Requires only the Python standard library.
"""
import urllib.request, json, sys
from collections import Counter
sys.stdout.reconfigure(encoding="utf-8", errors="replace")

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:7080/api/v1"
N    = int(sys.argv[2]) if len(sys.argv) > 2 else 15
OUT  = sys.argv[3] if len(sys.argv) > 3 else "waypoints.json"

def get(path):
    with urllib.request.urlopen(BASE + path, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))

def points(cat, x0, x1, z0, z1):
    d = get(f"/points?cat={cat}&minX={x0}&maxX={x1}&minZ={z0}&maxZ={z1}")
    return d if isinstance(d, list) else (d.get("points") or d.get("data") or d.get("items") or [])

h = get("/heatmap?type=BUILDING")
cs = h["cellSize"]
cells = sorted(h["cells"], key=lambda c: -c[2])   # (cx, cz, count) desc

accepted_cells, out = [], []
for cx, cz, cnt in cells:
    if len(out) >= N:
        break
    if any(abs(cx-ax) <= 1 and abs(cz-az) <= 1 for ax, az in accepted_cells):
        continue  # adjacent to an accepted cell = same build spilling over
    x0, x1, z0, z1 = cx*cs, (cx+1)*cs, cz*cs, (cz+1)*cs
    pts = []
    for cat in ("PORTAL", "CONTAINER", "BED"):
        try:
            pts += [(p.get("owner"), p.get("x"), p.get("z"), p.get("label"))
                    for p in points(cat, x0, x1, z0, z1) if isinstance(p, dict)]
        except Exception:
            pass
    owner_counts = Counter(o for (o, _, _, _) in pts if o)
    owner = owner_counts.most_common(1)[0][0] if owner_counts else None
    if owner and any(w["owner"] == owner for w in out):
        continue  # one waypoint per builder — keep the gallery varied
    coords = [(x, z) for (_, x, z, _) in pts if isinstance(x, (int, float)) and isinstance(z, (int, float))]
    if coords:
        gx = sum(x for x, _ in coords)/len(coords); gz = sum(z for _, z in coords)/len(coords)
    else:
        gx = cx*cs + cs/2; gz = cz*cs + cs/2
    label = next((l for (o, _, _, l) in pts if o == owner and l), None) or "build cluster"
    accepted_cells.append((cx, cz))
    rank = len(out) + 1
    out.append({"rank": rank, "x": round(gx, 1), "z": round(gz, 1), "y": None,
                "owner": owner, "label": label, "pieceCount": cnt,
                "dwellSeconds": 7 if rank == 1 else (6 if rank <= 4 else 5)})

doc = {"world": "ComfyEra16", "cellSize": cs,
       "generated_from": "StewardView /heatmap?type=BUILDING (ranking) + /points (attribution) — composition, no parser change",
       "waypoints": out}
with open(OUT, "w", encoding="utf-8") as f:
    json.dump(doc, f, indent=2, ensure_ascii=False)
print(f"wrote {len(out)} waypoints -> {OUT}\n")
for w in out:
    print(f"  #{w['rank']:2}  {str(w['owner']):<18} {w['pieceCount']:>6} pc   @({w['x']:>8},{w['z']:>8})   '{w['label']}'")
