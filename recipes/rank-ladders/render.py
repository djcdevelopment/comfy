"""Render a guild rank-ladder file into the things a guild already uses:
  1. a clean rank page (markdown) that replaces the drifting rank image
  2. the copy-paste submission commands a member/rep pastes

Standard library only. Usage:  python render.py [path-to.json]
Prints to the screen; redirect to a file if you want:  python render.py mine.json > rankpage.md
"""
import json, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "example-output.json")
data = json.load(open(path, encoding="utf-8"))

guild = data["guild"]
era = data.get("era", "?")
ranks = sorted(data["ranks"], key=lambda r: r.get("tier", 0))
tmpl = data.get("bot_command_template", "/{guild} submit rank:{rank}")

out = [f"# {guild} - rank ladder (era {era})"]
if data.get("source"):
    out.append(f"_source: {data['source']}_")
out.append("")

for r in ranks:
    out.append(f"## {r['name']}  -  rank {r.get('tier', '?')}")
    for req in r.get("requirements", []):
        out.append(f"- {req}")
    rew = r.get("reward") or {}
    bits = ([f"rank -> {rew['rank']}"] if rew.get("rank") else []) + \
           ([rew["bonus"]] if rew.get("bonus") else [])
    if bits:
        out.append(f"- _reward: {', '.join(bits)}_")
    out.append("")

out.append("---")
out.append("## copy-paste submission commands")
if data.get("bot_command_is_placeholder"):
    out.append("_(PLACEHOLDER command format - swap in the guild's real one, then re-render)_")
else:
    out.append("_(paste to submit; replace <proof> with your screenshot or link)_")
out.append("")
for r in ranks:
    if r.get("tier", 0) < 1:
        continue
    cmd = (tmpl.replace("{guild}", guild.lower())
               .replace("{rank}", r["name"])
               .replace("{proof}", "<proof>"))
    out.append(f"- **{r['name']}**: `{cmd}`")

print("\n".join(out))
