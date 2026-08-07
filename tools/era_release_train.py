"""Comfy era reset planner -- the release train, as data.

The Comfy reset schedule is not a record of past resets; it is a template. Every
milestone sits at a fixed offset from the era start date, so the entire staff
calendar, the comms cascade, and the staging window are a pure function of one
input: the day the era begins.

This tool encodes that template. Source of truth is the community-maintained
"Comfy Reset Schedule (Template)" covering E15 (5 Jul 2025), E16 (15 Nov 2025),
and E17 (14 Mar 2026). Offsets below were derived from all three and agree
exactly from T-49 onward.

Usage
-----
    python tools/era_release_train.py --era 18 --start 2026-11-14
    python tools/era_release_train.py --suggest
    python tools/era_release_train.py --era 18 --start 2026-11-14 --posts
"""

from __future__ import annotations

import argparse
import datetime as dt
from dataclasses import dataclass, field

# --------------------------------------------------------------------------
# Reference data: observed era starts. Every one falls on a Saturday.
# --------------------------------------------------------------------------

KNOWN_ERA_STARTS: dict[int, dt.date] = {
    15: dt.date(2025, 7, 5),
    16: dt.date(2025, 11, 15),
    17: dt.date(2026, 3, 14),
}

# Observed era lengths: E15->E16 = 133d (19wk), E16->E17 = 119d (17wk).
CADENCE_WEEKS = (17, 19)

# CADENCE IS BROKEN -- DO NOT EXTRAPOLATE.
#
# E17 was NOT followed by E18 at the observed cadence. An unscheduled short
# interstitial era ("The Lost Era") was inserted instead, launching on or about
# Sat 18 Jul 2026 with deliberately reduced ceremony, while E18 prep ran during
# it. E18 appears anchored to the external Valheim 1.0 launch rather than to the
# internal cadence.
#
# SOURCE: private message corpus under comfy-etheiry-analysis/ (gitignored, not
# distributable -- see that directory's README). The finding is recorded here as
# an operational fact only; supporting quotations stay in the private analysis
# and must not be copied into tracked files. Launch date is INFERRED, not
# confirmed -- verify against the reset channels before relying on it.
#
# Two consequences for this tool:
#   1. Cadence-derived candidate dates for E18 are known-wrong. --suggest says so.
#   2. The template models one era type. It does not model a short interstitial
#      era with reduced ceremony, and that gap is already costing coordination
#      inside the community.
CADENCE_BROKEN_AFTER = 17


# --------------------------------------------------------------------------
# The release train. One row per milestone, offset in days before era start.
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class Milestone:
    offset: int  # days before era start (negative)
    name: str
    audience: str  # who this beat is addressed to
    phase: str
    tolerance: int = 0  # +/- days this beat is allowed to drift
    note: str = ""


MILESTONES: tuple[Milestone, ...] = (
    Milestone(
        -56,
        "Announce to Senior Staff",
        "Senior Staff",
        "kickoff",
        tolerance=2,
        note="Only soft beat. Observed T-54 (E15), T-55 (E16), T-56 (E17); no fixed weekday.",
    ),
    Milestone(-49, "Select Seed", "Senior Staff", "kickoff"),
    Milestone(
        -42,
        "Prep Server Online",
        "Staff",
        "staging",
        note="Opens the staging window.",
    ),
    Milestone(-35, "Creators Notified", "Creators", "comms cascade"),
    Milestone(
        -14,
        "All Staff Notified; Brainstorming Proposals Due",
        "All Staff",
        "comms cascade",
        note="Merged into a single date from E16 on; was two beats in E15.",
    ),
    Milestone(
        -11,
        "Players Notified; EoE Kits Start",
        "Players",
        "comms cascade",
        note="First player-facing beat. Opens the End-of-Era kit window.",
    ),
    Milestone(
        -4,
        "EoE & Threat Kits End; Prep Server Closed",
        "Players / Staff",
        "freeze",
        note="Prep Server close moved here from T-11 after E15, lengthening staging by a week.",
    ),
    Milestone(0, "Era Starts", "Everyone", "launch"),
)

# Assets that carry the era number in their name and must be rebuilt per era.
ERA_SCOPED_ASSETS: tuple[str, ...] = (
    "HobbitHome{era}",  # Rewind build file, loaded via /lb --fn=...
)


@dataclass
class ReleasePlan:
    era: int
    start: dt.date
    rows: list[tuple[Milestone, dt.date]] = field(default_factory=list)

    @property
    def staging_open(self) -> dt.date:
        return self.start + dt.timedelta(days=-42)

    @property
    def staging_close(self) -> dt.date:
        return self.start + dt.timedelta(days=-4)

    @property
    def kit_window(self) -> tuple[dt.date, dt.date]:
        return (
            self.start + dt.timedelta(days=-11),
            self.start + dt.timedelta(days=-4),
        )


def build_plan(era: int, start: dt.date) -> ReleasePlan:
    plan = ReleasePlan(era=era, start=start)
    for m in MILESTONES:
        plan.rows.append((m, start + dt.timedelta(days=m.offset)))
    return plan


# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------


def render_calendar(plan: ReleasePlan) -> str:
    lines: list[str] = []
    lines.append(f"E{plan.era} COMFY VALHEIM RESET -- RELEASE TRAIN")
    lines.append("=" * 62)
    lines.append(f"Era start (T-0):  {plan.start:%a %d %b %Y}")
    lines.append(f"Staging window:   {plan.staging_open:%d %b} -> {plan.staging_close:%d %b} (38 days)")
    kit_open, kit_close = plan.kit_window
    lines.append(f"EoE kit window:   {kit_open:%d %b} -> {kit_close:%d %b} (7 days)")
    lines.append("")
    lines.append(f"{'T-minus':>8}  {'Date':<15}  {'Audience':<16}  Milestone")
    lines.append(f"{'-'*8}  {'-'*15}  {'-'*16}  {'-'*46}")

    for m, when in plan.rows:
        tminus = "T-0" if m.offset == 0 else f"T-{abs(m.offset)}"
        if m.tolerance:
            tminus += f" ~{m.tolerance}"
        lines.append(
            f"{tminus:>8}  {when:%a %d %b %Y}  {m.audience:<16}  {m.name}"
        )

    notes = [(m, w) for m, w in plan.rows if m.note]
    if notes:
        lines.append("")
        lines.append("Notes")
        lines.append("-----")
        for m, _ in notes:
            lines.append(f"  * {m.name}: {m.note}")

    lines.append("")
    lines.append("Era-scoped artifacts to rebuild")
    lines.append("-------------------------------")
    for tmpl in ERA_SCOPED_ASSETS:
        lines.append(f"  * {tmpl.format(era=f'E{plan.era}')}")

    lines.append("")
    lines.append(
        "Exact timestamps belong in the reset-channel posts, not in this calendar."
    )
    return "\n".join(lines)


POST_TEMPLATES: dict[str, str] = {
    "Select Seed": (
        "[E{era} / T-{tminus}] Seed selected for Era {era}.\n"
        "Prep Server comes online {next_date:%A %d %B} for staff build-out."
    ),
    "Prep Server Online": (
        "[E{era} / T-{tminus}] Prep Server is ONLINE.\n"
        "Staging window runs through {staging_close:%A %d %B}. Build, test, and stage "
        "era-scoped assets now -- anything not staged before close ships late."
    ),
    "Creators Notified": (
        "[E{era} / T-{tminus}] Creators: Era {era} planning is open.\n"
        "Prep Server is live. Brainstorming proposals are due {proposals:%A %d %B}."
    ),
    "All Staff Notified; Brainstorming Proposals Due": (
        "[E{era} / T-{tminus}] All staff: Era {era} begins {start:%A %d %B}.\n"
        "Brainstorming proposals are due TODAY. Player announcement goes out "
        "{players:%A %d %B}."
    ),
    "Players Notified; EoE Kits Start": (
        "[E{era} / T-{tminus}] Era {era} begins {start:%A %d %B}.\n"
        "End-of-Era and Threat kits are available starting now and close "
        "{kit_close:%A %d %B}. Get your affairs in order, Vikings."
    ),
    "EoE & Threat Kits End; Prep Server Closed": (
        "[E{era} / T-{tminus}] EoE and Threat kits are CLOSED. Prep Server is closed.\n"
        "Era {era} starts {start:%A %d %B}. Final freeze is in effect."
    ),
    "Era Starts": (
        "[E{era} / T-0] Era {era} is LIVE. Fresh world, fresh seed. Go build something comfy."
    ),
}


def render_posts(plan: ReleasePlan) -> str:
    by_name = {m.name: (m, w) for m, w in plan.rows}
    kit_open, kit_close = plan.kit_window
    lines: list[str] = [f"DRAFT RESET-CHANNEL POSTS -- E{plan.era}", "=" * 62]

    for m, when in plan.rows:
        tmpl = POST_TEMPLATES.get(m.name)
        if not tmpl:
            continue
        body = tmpl.format(
            era=plan.era,
            tminus=abs(m.offset),
            start=plan.start,
            staging_close=plan.staging_close,
            kit_close=kit_close,
            proposals=by_name["All Staff Notified; Brainstorming Proposals Due"][1],
            players=by_name["Players Notified; EoE Kits Start"][1],
            next_date=by_name["Prep Server Online"][1],
        )
        lines.append("")
        lines.append(f"--- post on {when:%a %d %b %Y} ({m.audience}) ---")
        lines.append(body)

    lines.append("")
    lines.append("(Drafts. Add exact timestamps before posting.)")
    return "\n".join(lines)


def suggest_next() -> str:
    last_era = max(KNOWN_ERA_STARTS)
    last_start = KNOWN_ERA_STARTS[last_era]
    lines = [
        "OBSERVED CADENCE",
        "=" * 62,
    ]
    eras = sorted(KNOWN_ERA_STARTS)
    for a, b in zip(eras, eras[1:]):
        delta = (KNOWN_ERA_STARTS[b] - KNOWN_ERA_STARTS[a]).days
        lines.append(
            f"  E{a} -> E{b}: {delta} days ({delta // 7} weeks)  "
            f"[{KNOWN_ERA_STARTS[a]:%d %b %Y} -> {KNOWN_ERA_STARTS[b]:%d %b %Y}]"
        )
    lines.append("")
    lines.append("*** CADENCE BROKEN AFTER E17 -- DO NOT EXTRAPOLATE ***")
    lines.append("")
    lines.append(
        "E17 was not followed by E18 on cadence. An unscheduled short interstitial"
    )
    lines.append(
        "era, 'The Lost Era', launched ~Sat 18 Jul 2026 with deliberately reduced"
    )
    lines.append(
        "ceremony, and E18 prep is running during it. E18 looks anchored to the"
    )
    lines.append("external Valheim 1.0 launch, not to the internal cadence.")
    lines.append("")
    lines.append("For reference only, the cadence-derived dates that did NOT happen:")
    for weeks in CADENCE_WEEKS:
        cand = last_start + dt.timedelta(weeks=weeks)
        lines.append(f"  {weeks} weeks: {cand:%a %d %b %Y}  (did not occur)")
    lines.append("")
    lines.append(
        f"Get the real E{last_era + 1} start from the reset channels, then pass it "
        "to --start."
    )
    return "\n".join(lines)


# --------------------------------------------------------------------------


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Generate a Comfy era reset release train from the era start date."
    )
    ap.add_argument("--era", type=int, help="Era number, e.g. 18")
    ap.add_argument("--start", help="Era start date, YYYY-MM-DD (should be a Saturday)")
    ap.add_argument("--posts", action="store_true", help="Also emit draft channel posts")
    ap.add_argument("--suggest", action="store_true", help="Show observed cadence and candidate next starts")
    ap.add_argument("--out", help="Write output to a file instead of stdout")
    args = ap.parse_args()

    if args.suggest:
        output = suggest_next()
    else:
        if args.era is None or args.start is None:
            ap.error("--era and --start are required (or use --suggest)")
        start = dt.date.fromisoformat(args.start)
        plan = build_plan(args.era, start)
        chunks = [render_calendar(plan)]
        if args.posts:
            chunks.append("")
            chunks.append(render_posts(plan))
        output = "\n".join(chunks)
        if start.weekday() != 5:  # Saturday
            output = (
                f"WARNING: {start:%d %b %Y} is a {start:%A}. Every observed era "
                "start (E15-E17) is a Saturday, and the T-11/T-4 beats assume it.\n\n"
            ) + output

    if args.out:
        with open(args.out, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(output + "\n")
        print(f"wrote {args.out}")
    else:
        print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
