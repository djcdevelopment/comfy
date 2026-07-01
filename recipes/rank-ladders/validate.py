"""Validate a guild rank-ladder file. Standard library only — no installs.

Usage:  python validate.py [path-to.json]     (defaults to example-output.json)

It prints problems you must fix (X) and advice (!). Exit code 1 if anything is broken.
This is your guardrail: if it says PASS, the file is safe to render.
"""
import json, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "example-output.json")

data = json.load(open(path, encoding="utf-8"))
errors, warnings = [], []

for key in ("guild", "era", "ranks", "bot_command_template"):
    if key not in data:
        errors.append(f"missing top-level field: {key}")

ranks = data.get("ranks", [])
if not ranks:
    errors.append("no ranks defined")

seen = set()
for i, r in enumerate(ranks):
    where = f"rank[{i}] ({r.get('name', '?')})"
    for key in ("tier", "name", "requirements"):
        if key not in r:
            errors.append(f"{where}: missing '{key}'")
    t = r.get("tier")
    if t in seen:
        errors.append(f"{where}: duplicate tier {t}")
    seen.add(t)
    if not r.get("requirements"):
        errors.append(f"{where}: empty requirements")
    for j, req in enumerate(r.get("requirements", [])):
        if not str(req).strip():
            errors.append(f"{where}: blank requirement at position {j}")

if seen:
    lo, hi = min(seen), max(seen)
    missing = [t for t in range(lo, hi + 1) if t not in seen]
    if missing:
        warnings.append(f"non-sequential tiers; missing: {missing}")

if data.get("bot_command_is_placeholder"):
    warnings.append("bot_command_template is a PLACEHOLDER — replace it with the guild's real "
                    "command format, then set bot_command_is_placeholder to false")
elif "{rank}" not in data.get("bot_command_template", ""):
    warnings.append("bot_command_template has no {rank} — the rendered commands won't vary by rank")

print(f"checking {os.path.basename(path)}: {data.get('guild', '?')} guild, {len(ranks)} ranks")
for w in warnings:
    print(f"  ! {w}")
for e in errors:
    print(f"  X {e}")
if errors:
    print(f"FAIL - {len(errors)} problem(s) to fix")
    sys.exit(1)
print("PASS - structure is consistent" + (f" ({len(warnings)} warning(s))" if warnings else ""))
