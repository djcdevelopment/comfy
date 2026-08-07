"""Build the standalone 'practice to profession' page.

A markdown file is the wrong vehicle for this audience. This emits a single
self-contained HTML file -- no external requests, images inlined as data URIs --
that can be sent, hosted, or opened from disk.

Editorial rule enforced here: the page describes the *documents*, never the
person. There is no second person anywhere in the copy. Recognition is left to
the reader.

Usage:
    python tools/build_practice_page.py --shots <dir> --out practice.html
"""

from __future__ import annotations

import argparse
import base64
import mimetypes
import os

# Anchor images, keyed to the section that uses them.
ANCHORS = {
    "protractor": "p1_02.png",
    "restrictions": "p2_00.png",
    "eulers": "p2_05.jpg",
}


def data_uri(path: str) -> str:
    mime = mimetypes.guess_type(path)[0] or "image/png"
    with open(path, "rb") as fh:
        return f"data:{mime};base64,{base64.b64encode(fh.read()).decode('ascii')}"


# --------------------------------------------------------------------------
# SVG 1 -- the release train. Three eras, identical offsets. The argument.
# --------------------------------------------------------------------------

MILESTONES = [
    (-56, "Announce", "senior staff", True),
    (-49, "Select seed", "senior staff", False),
    (-42, "Prep server online", "staff", False),
    (-35, "Creators notified", "creators", False),
    (-14, "All staff + proposals", "all staff", False),
    (-11, "Players notified, kits open", "players", False),
    (-4, "Kits close, prep server shut", "players / staff", False),
    (0, "Era starts", "everyone", False),
]

ERAS = [
    ("E15", "5 Jul 2025", "#c2703d"),
    ("E16", "15 Nov 2025", "#3d7ec2"),
    ("E17", "14 Mar 2026", "#4f9d69"),
]


def release_train_svg() -> str:
    L, R = 96, 1104
    span = 56.0
    def x(off: int) -> float:
        return L + (off + span) / span * (R - L)

    rows = []
    for i, (label, start, colour) in enumerate(ERAS):
        y = 168 + i * 34
        rows.append(f'<text x="{L-14}" y="{y+4}" class="eralab" fill="{colour}">{label}</text>')
        rows.append(f'<line x1="{x(-56)}" y1="{y}" x2="{x(0)}" y2="{y}" class="erarail"/>')
        for off, _, _, soft in MILESTONES:
            cx = x(off)
            if soft:
                rows.append(f'<circle cx="{cx}" cy="{y}" r="4.5" fill="none" stroke="{colour}" stroke-width="2" stroke-dasharray="2 2"/>')
            else:
                rows.append(f'<circle cx="{cx}" cy="{y}" r="4.5" fill="{colour}"/>')
        rows.append(f'<text x="{R+14}" y="{y+4}" class="erastart">{start}</text>')

    ticks = []
    for off, name, audience, soft in MILESTONES:
        cx = x(off)
        ticks.append(f'<line x1="{cx}" y1="112" x2="{cx}" y2="{168 + 2*34 + 16}" class="guide"/>')
        lbl = "T-56*" if soft else (f"T{off}" if off else "T-0")
        ticks.append(f'<text x="{cx}" y="104" class="tmin">{lbl}</text>')
        ticks.append(
            f'<g transform="translate({cx},290) rotate(-38)">'
            f'<text x="0" y="0" class="msname">{name}</text>'
            f'<text x="0" y="15" class="msaud">{audience}</text></g>'
        )

    return f"""<svg viewBox="0 0 1200 380" role="img" aria-label="Release train: three eras, identical milestone offsets">
  <text x="{L-14}" y="72" class="axtitle">T-minus</text>
  <line x1="{x(-56)}" y1="112" x2="{x(0)}" y2="112" class="axis"/>
  {''.join(ticks)}
  {''.join(rows)}
  <rect x="{x(-42)}" y="140" width="{x(-4)-x(-42)}" height="{34*2+28}" class="window"/>
  <text x="{(x(-42)+x(-4))/2}" y="134" class="wlabel">staging window · 38 days</text>
</svg>"""


# --------------------------------------------------------------------------
# SVG 2 -- one placement, four records, nothing comparing them.
# --------------------------------------------------------------------------

RECORDS = [
    ("PassWard", "set in world"),
    ("Tracker", "confidential sheet"),
    ("Player DM", "copy-pasta"),
    ("/hobbitrep", "bot ledger"),
]

PROJECTIONS = [
    ("Player DM", "rendered from the row"),
    ("/hobbitrep", "logged against the row"),
    ("PassWard", "spot-checked in world"),
]


def records_svg() -> str:
    """Two panels: the shape today, and the one move that closes it.

    Deliberately not drawn as a defect. The left panel is what four parallel
    writes look like; the right is write-once-project-many, which is the same
    move the rest of this work already makes everywhere else.
    """
    p = []

    # ---- Panel A: four independent writes -------------------------------
    p.append('<text x="34" y="26" class="panel">Today &#8212; four independent writes</text>')
    p.append('<rect x="34" y="128" width="150" height="54" rx="6" class="src"/>')
    p.append('<text x="109" y="150" class="srct">One placement</text>')
    p.append('<text x="109" y="168" class="srcs">7 steps &#183; 6 mods</text>')
    for i, (name, sub) in enumerate(RECORDS):
        y = 54 + i * 52
        p.append(f'<path d="M184 155 C 236 155, 244 {y+18}, 286 {y+18}" class="flow"/>')
        p.append(f'<rect x="286" y="{y}" width="176" height="38" rx="6" class="rec"/>')
        p.append(f'<text x="300" y="{y+17}" class="rect">{name}</text>')
        p.append(f'<text x="300" y="{y+30}" class="recs">{sub}</text>')
    p.append('<text x="286" y="292" class="misss">Each can be missed on its own.</text>')
    p.append('<text x="34" y="292" class="misss">as this guide describes it</text>')

    # ---- divider ---------------------------------------------------------
    p.append('<line x1="520" y1="34" x2="520" y2="296" class="guide"/>')

    # ---- Panel B: one record, three projections --------------------------
    p.append('<text x="562" y="26" class="panel2">One move &#8212; one record, three projections</text>')
    p.append('<rect x="562" y="128" width="132" height="54" rx="6" class="src"/>')
    p.append('<text x="628" y="150" class="srct">One placement</text>')
    p.append('<text x="628" y="168" class="srcs">7 steps &#183; 6 mods</text>')

    p.append('<path d="M694 155 L 744 155" class="flow"/>')
    p.append('<rect x="744" y="122" width="150" height="66" rx="6" class="record"/>')
    p.append('<text x="819" y="146" class="rect" text-anchor="middle">Tracker row</text>')
    p.append('<text x="819" y="163" class="recs" text-anchor="middle">system of record</text>')
    p.append('<text x="819" y="178" class="recs" text-anchor="middle">written once</text>')

    for i, (name, sub) in enumerate(PROJECTIONS):
        y = 66 + i * 62
        p.append(f'<path d="M894 155 C 940 155, 948 {y+18}, 986 {y+18}" class="flow2"/>')
        p.append(f'<rect x="986" y="{y}" width="152" height="38" rx="6" class="rec"/>')
        p.append(f'<text x="1000" y="{y+17}" class="rect">{name}</text>')
        p.append(f'<text x="1000" y="{y+30}" class="recs">{sub}</text>')

    p.append('<rect x="744" y="256" width="394" height="34" rx="6" class="done"/>')
    p.append('<text x="762" y="278" class="donet">Done = the row is complete. One check, not four.</text>')

    return (
        '<svg viewBox="0 0 1170 310" role="img" '
        'aria-label="Four parallel records today, versus one system of record projecting three outputs">'
        f'{"".join(p)}</svg>'
    )


# --------------------------------------------------------------------------

PAGE = """<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Two documents, and what they are called</title>
<style>
  :root {{
    --bg:#fbfaf8; --fg:#1a1a18; --muted:#6b6862; --rule:#e2ded6;
    --card:#ffffff; --accent:#8a5a2b; --accent2:#2f6f4f; --shadow:0 1px 2px rgba(0,0,0,.05),0 8px 24px rgba(0,0,0,.04);
  }}
  @media (prefers-color-scheme: dark) {{
    :root {{ --bg:#131311; --fg:#ece9e3; --muted:#9d9891; --rule:#2c2a26;
             --card:#1b1a17; --accent:#d09a5f; --accent2:#7fc39a; --shadow:none; }}
  }}
  :root[data-theme="dark"] {{ --bg:#131311; --fg:#ece9e3; --muted:#9d9891; --rule:#2c2a26;
             --card:#1b1a17; --accent:#d09a5f; --accent2:#7fc39a; --shadow:none; }}
  :root[data-theme="light"] {{ --bg:#fbfaf8; --fg:#1a1a18; --muted:#6b6862; --rule:#e2ded6;
             --card:#ffffff; --accent:#8a5a2b; --accent2:#2f6f4f;
             --shadow:0 1px 2px rgba(0,0,0,.05),0 8px 24px rgba(0,0,0,.04); }}

  body {{ margin:0; background:var(--bg); color:var(--fg);
    font:400 17px/1.62 ui-sans-serif,-apple-system,"Segoe UI",Inter,Helvetica,Arial,sans-serif;
    -webkit-font-smoothing:antialiased; }}
  .wrap {{ max-width:1180px; margin:0 auto; padding:0 28px 120px; }}
  .narrow {{ max-width:660px; }}
  h1,h2,h3 {{ font-family:ui-serif,Georgia,"Iowan Old Style","Times New Roman",serif; font-weight:600;
    letter-spacing:-.015em; line-height:1.18; }}
  h1 {{ font-size:clamp(34px,5.2vw,58px); margin:0 0 18px; }}
  h2 {{ font-size:clamp(25px,3vw,34px); margin:0 0 14px; }}
  h3 {{ font-size:20px; margin:0 0 8px; }}
  p {{ margin:0 0 18px; }}
  .lede {{ font-size:clamp(19px,2.1vw,23px); line-height:1.5; color:var(--muted); }}
  .eyebrow {{ font:600 12px/1 ui-sans-serif,system-ui; letter-spacing:.15em; text-transform:uppercase;
    color:var(--accent); margin:0 0 20px; }}
  header {{ padding:104px 0 68px; }}
  section {{ padding:64px 0; border-top:1px solid var(--rule); }}
  .fig {{ margin:34px 0; background:var(--card); border:1px solid var(--rule); border-radius:12px;
    padding:26px 20px 16px; box-shadow:var(--shadow); overflow-x:auto; }}
  .fig svg {{ display:block; width:100%; min-width:720px; height:auto; }}
  .cap {{ font-size:14px; color:var(--muted); margin:12px 4px 0; }}

  .axis,.erarail {{ stroke:var(--rule); stroke-width:1.5; }}
  .erarail {{ stroke-dasharray:1 5; stroke-linecap:round; }}
  .guide {{ stroke:var(--rule); stroke-width:1; }}
  .window {{ fill:var(--accent); opacity:.07; }}
  text {{ fill:var(--fg); font-family:ui-sans-serif,system-ui,sans-serif; }}
  .tmin {{ font-size:12px; font-weight:600; fill:var(--muted); text-anchor:middle; }}
  .msname {{ font-size:13px; text-anchor:end; }}
  .msaud {{ font-size:11px; fill:var(--muted); text-anchor:end; }}
  .eralab {{ font-size:14px; font-weight:700; text-anchor:end; }}
  .erastart {{ font-size:12px; fill:var(--muted); }}
  .axtitle,.wlabel {{ font-size:12px; fill:var(--muted); }}
  .axtitle {{ text-anchor:end; font-weight:600; }}
  .wlabel {{ text-anchor:middle; }}
  .src {{ fill:var(--card); stroke:var(--accent); stroke-width:1.5; }}
  .srct {{ font-size:15px; font-weight:600; text-anchor:middle; }}
  .srcs {{ font-size:12px; fill:var(--muted); text-anchor:middle; }}
  .flow {{ fill:none; stroke:var(--rule); stroke-width:1.5; }}
  .rec {{ fill:var(--card); stroke:var(--rule); stroke-width:1.5; }}
  .rect {{ font-size:14px; font-weight:600; }}
  .recs {{ font-size:11px; fill:var(--muted); }}
  .missing {{ stroke:var(--accent); stroke-width:1.5; stroke-dasharray:4 5; opacity:.7; }}
  .miss {{ font-size:13px; font-weight:600; fill:var(--accent); }}
  .misss {{ font-size:11px; fill:var(--muted); }}
  .panel {{ font-size:12px; font-weight:600; letter-spacing:.09em; text-transform:uppercase; fill:var(--muted); }}
  .panel2 {{ font-size:12px; font-weight:600; letter-spacing:.09em; text-transform:uppercase; fill:var(--accent2); }}
  .record {{ fill:var(--card); stroke:var(--accent2); stroke-width:2; }}
  .flow2 {{ fill:none; stroke:var(--accent2); stroke-width:1.5; opacity:.55; }}
  .done {{ fill:var(--accent2); opacity:.09; }}
  .donet {{ font-size:13px; font-weight:600; fill:var(--accent2); }}

  .pair {{ display:grid; grid-template-columns:1fr 1fr; gap:34px; align-items:center; margin:34px 0; }}
  .pair img {{ width:100%; max-width:100%; border-radius:10px; border:1px solid var(--rule); display:block; }}
  .term {{ font:600 13px/1 ui-sans-serif; letter-spacing:.11em; text-transform:uppercase; color:var(--accent2);
    margin:0 0 10px; }}
  @media (max-width:760px) {{ .pair {{ grid-template-columns:1fr; }} }}

  table {{ width:100%; border-collapse:collapse; margin:26px 0; font-size:15px; }}
  th,td {{ text-align:left; padding:11px 12px; border-bottom:1px solid var(--rule); vertical-align:top; }}
  th {{ font:600 12px/1.3 ui-sans-serif; letter-spacing:.09em; text-transform:uppercase; color:var(--muted); }}
  td code {{ font-size:13.5px; background:var(--card); border:1px solid var(--rule);
    border-radius:4px; padding:1px 5px; }}
  .q {{ background:var(--card); border:1px solid var(--rule); border-left:3px solid var(--accent);
    border-radius:0 10px 10px 0; padding:22px 24px; margin:20px 0; box-shadow:var(--shadow); }}
  .q h3 {{ font-family:ui-serif,Georgia,serif; font-style:italic; }}
  .q .ai {{ font-size:15px; color:var(--muted); margin:0; }}
  .q .ai b {{ color:var(--fg); font-weight:600; }}
  footer {{ padding:56px 0 0; border-top:1px solid var(--rule); color:var(--muted); font-size:14px; }}
</style>

<div class="wrap">

<header class="narrow">
  <p class="eyebrow">Two community documents, read closely</p>
  <h1>Two documents, and what they are called</h1>
  <p class="lede">A reset schedule and a placement guide, written for a modded Valheim
  community. Read as engineering artifacts, they are doing work that has established
  names, established tooling, and a job market.</p>
</header>

<section>
  <div class="narrow">
    <h2>Three calendars, one schedule</h2>
    <p>The reset schedule covers three eras. Converting each date to an offset from the
    day its era begins produces the same eight milestones at the same distances, every
    time. From T&#8209;49 onward the offsets are identical &mdash; not similar, identical.</p>
  </div>
  <div class="fig">{train}
    <p class="cap">Every era begins on a Saturday. Only the first beat drifts (T&#8209;54/55/56,
    marked&nbsp;*) &mdash; the one milestone not pinned to a weekday.</p>
  </div>
  <div class="narrow">
    <p><span class="term">Release train</span>
    Milestones fixed at offsets from a launch date is called a release train, and the
    T&#8209;minus notation is the term of art in release engineering. The staged run from
    senior staff to creators to all staff to players is a <b>comms cascade</b>. The prep
    server opening at T&#8209;42 and closing at T&#8209;4 is a <b>staging window</b>. The
    kit period that ends before launch is a <b>change freeze</b>.</p>
    <p>Publishing it as a <b>template</b> rather than a log is the part most organisations
    never reach. Because the offsets hold, the entire calendar is a function of one input:
    a script rebuilds all eight E17 dates from the era start alone.</p>
  </div>
</section>

<section>
  <div class="narrow">
    <h2>A procedure that expects to fail</h2>
    <p>The placement guide is not documentation. It is a <b>runbook</b> &mdash; an executable
    procedure with commands in execution order, a declared toolchain, and remedies attached
    to named failure modes.</p>
  </div>

  <div class="pair">
    <img src="{protractor}" alt="A 360-degree protractor included in the procedure">
    <div>
      <p class="term">Paved road &middot; design tokens</p>
      <p>All thirty&#8209;two valid rotations are printed out, and a protractor is supplied.
      Multiples of 11.25&deg; are 360/32 &mdash; the game's snap grid, documented as an
      approved set.</p>
      <p>Constraining a continuous space to a discrete approved list is what design systems
      call <b>tokens</b> and what platform engineering calls a <b>paved road</b>: make the
      correct option the low&#8209;effort one, and remove arithmetic from the live moment.</p>
    </div>
  </div>

  <div class="pair">
    <div>
      <p class="term">Acceptance criteria &middot; preconditions</p>
      <p>Placement restrictions, numbered, bounded, and checked before work begins. In
      engineering these are <b>preconditions</b> and <b>acceptance criteria</b>; they are
      normally a bulleted list nobody reads.</p>
      <p>Here they are typeset. That is not decoration &mdash; a spec that gets looked at
      is a spec that gets followed.</p>
    </div>
    <img src="{restrictions}" alt="Typeset placement restrictions card">
  </div>

  <table>
    <tr><th>In the guide</th><th>Called</th></tr>
    <tr><td>Private world &rarr; screenshots &rarr; GM review &rarr; live</td>
        <td><b>Pre&#8209;production validation</b> with a change&#8209;approval gate</td></tr>
    <tr><td><code>/undolb</code> &rarr; relog &rarr; <code>/del</code> &rarr; Ward Train</td>
        <td><b>Triage ladder</b> / fallback strategy</td></tr>
    <tr><td>&ldquo;NEVER use increments larger than 5&rdquo;</td>
        <td><b>Blast radius limit</b></td></tr>
    <tr><td><code>--ig=LocationProxy</code> on space islands</td>
        <td><b>Exclusion filter</b> against collateral damage</td></tr>
    <tr><td><code>HobbitHomeE16</code></td>
        <td><b>Versioned artifact</b></td></tr>
    <tr><td>&ldquo;Never used Rewind before?&hellip; Can't find the folder?&hellip;&rdquo;</td>
        <td><b>Zero&#8209;context authoring</b></td></tr>
  </table>
</section>

<section>
  <div class="narrow">
    <h2>These instincts did not come from software</h2>
    <p>They came from a discipline that met the same problem earlier, for the same reason:
    production steps that are expensive and irreversible. A print run punishes vagueness
    exactly the way a live server does.</p>
  </div>
  <table>
    <tr><th>Design practice</th><th>The same thing, in software</th></tr>
    <tr><td><b>Master page</b> &mdash; build the master, instance it per issue</td>
        <td>Process parameterisation; config&#8209;as&#8209;data</td></tr>
    <tr><td><b>Swatch palette / modular scale</b></td>
        <td>Enumerated valid values; making illegal states unrepresentable</td></tr>
    <tr><td><b>Pre&#8209;flight / press proof</b></td>
        <td>Staging plus a change&#8209;approval gate</td></tr>
    <tr><td><b>Asset naming conventions</b></td>
        <td>Artifact versioning</td></tr>
    <tr><td><b>Design &rarr; dev handoff, redlines</b></td>
        <td>Specification authoring</td></tr>
  </table>
  <div class="narrow">
    <p>That last row is the one worth sitting with. A designer's core professional interface
    is handing a specification to an executor that implements it literally, without judgement,
    and gets it wrong precisely where the spec was vague. That executor used to be a press
    operator, then a front&#8209;end developer. The job of writing for it has not changed.
    Only the executor has.</p>
  </div>
</section>

<section>
  <div class="narrow">
    <h2>Where this goes</h2>
  </div>
  <table>
    <tr><th>Role</th><th>What already transfers</th></tr>
    <tr><td><b>Technical Program Manager</b></td><td>Release trains, comms cascades, milestone tracking, retro&#8209;driven process revision</td></tr>
    <tr><td><b>Release / Launch Manager</b></td><td>The reset schedule <i>is</i> this job</td></tr>
    <tr><td><b>Design Ops</b></td><td>Design discipline plus process authoring &mdash; the exact intersection</td></tr>
    <tr><td><b>Business / Process Analyst</b></td><td>Eliciting and documenting workflows</td></tr>
    <tr><td><b>Platform / Developer Experience</b></td><td>Paved roads, onboarding paths, toolchain curation</td></tr>
  </table>
  <div class="narrow">
    <p>An industry spent thirty years building expensive machinery &mdash; BPMN, workflow
    engines, RPA, process mining &mdash; to extract process knowledge from people who could
    not articulate it. Process mining exists because asking did not work. RPA exists because
    writing the spec was too hard, so vendors recorded clicks instead.</p>
    <p>AI did not create the value of being able to state a process precisely. It collapsed
    the cost of acting on one. The scarce input is unchanged.</p>
    <p><b>Honest caveat.</b> Hiring for these roles is credential&#8209;heavy and filters on
    prior industry experience, so none of this is a short move. The gap is vocabulary and
    portfolio framing &mdash; mechanical work &mdash; not capability. In small&#8209;team and
    AI&#8209;native work that gate mostly is not there.</p>
  </div>
</section>

<section>
  <div class="narrow">
    <h2>The questions this opens</h2>
    <p>Documents this good stop generating corrections and start generating questions &mdash;
    the ones asked once the basics are long settled. Each is also a good task to hand an AI:
    a mechanical, exhaustive sweep, where the judgement about what to do with the answer
    stays human.</p>
  </div>

  <div class="narrow">
    <div class="q"><h3>&ldquo;For every step here, what is the reversal, and what does it cost?&rdquo;</h3>
      <p>The load path carries a full escalation ladder &mdash; four ordered remedies, each for a
      named failure. <i>Within this document</i>, the later steps (terrain, ward, sign,
      mark&#8209;off) do not yet carry the same thing. Whether it lives in one of the sibling
      guides is a question rather than an assumption.</p>
      <p class="ai"><b>Where AI helps:</b> walk every step and name the undo for each. Exhaustive,
      and it does not lose interest by step six.</p></div>

    <div class="q"><h3>&ldquo;If these four records disagree, what tells me?&rdquo;</h3>
      <p>One placement writes to four places, and each can be missed on its own. <i>This
      document</i> does not describe a step that compares them &mdash; the tracker and the bot
      guide are separate documents and may already carry part of it. The resolution, wherever it
      lands, is not a fifth system: it is picking <b>one</b> of the four to be authoritative and
      letting the rest fall out of it.</p>
      <p>The tracker row is the natural candidate: it already exists, it already holds the
      PassWard detail, and it is the only one that can carry a column per outcome. Once it is the
      record, the DM is <i>rendered</i> from the row rather than typed beside it,
      <code>/hobbitrep</code> is logged <i>against</i> the row, and the ward is a spot check
      rather than a fourth ledger. Definition of done collapses from four independent writes to
      one question: <b>is the row complete?</b></p>
      <p class="ai"><b>Where AI helps:</b> draft the row schema and the copy&#8209;pasta template
      that renders from it, then write the check that flags rows missing an outcome. Which field
      is authoritative stays the human call.</p></div>
  </div>

  <div class="fig">{records}
    <p class="cap">Write once, project many. The same move the reset schedule already makes &mdash;
    one date in, eight milestones out.</p>
  </div>

  <div class="narrow">
    <div class="q"><h3>&ldquo;Where am I still asking for a judgement call I could pre&#8209;resolve?&rdquo;</h3>
      <p>The thirty&#8209;two&#8209;row rotation table is already the answer to this question, applied
      to rotations. &ldquo;Adjust the era&nbsp;# accordingly&rdquo; is the same class of thing,
      unresolved.</p>
      <p class="ai"><b>Where AI helps:</b> list every point where the reader must compute, look up,
      or decide. Which are worth pre&#8209;resolving stays the human call.</p></div>

    <div class="q"><h3>&ldquo;What does this depend on that someone else controls?&rdquo;</h3>
      <p>A font behind a link. Mod versions. A folder path that &ldquo;may vary from computer to
      computer.&rdquo;</p>
      <p class="ai"><b>Where AI helps:</b> enumerate every external dependency and rank by what
      happens when one disappears.</p></div>

    <div class="q"><h3>&ldquo;Which of these are invariants, and which are just habits?&rdquo;</h3>
      <p>Three eras of data are already in hand. Everything from T&#8209;49 down holds exactly;
      the announce beat drifts. Knowing which is which is the difference between a template and
      a routine.</p>
      <p class="ai"><b>Where AI helps:</b> arithmetic over data that already exists, which it will
      not get wrong.</p></div>
  </div>
</section>

<footer class="narrow">
  <p>Every term used here is externally verifiable &mdash; release train, blast radius, paved
  road, runbook, comms cascade. None of it requires taking anyone's word.</p>
  <p>Sources: <i>Comfy Reset Schedule (Template)</i>, 3 pages, calendars for E15&ndash;E17;
  <i>Hobbit Home Placement Guide</i>, 2 pages, 13 screenshots. Milestone offsets derived from
  all three calendars and verified by regenerating every E17 date from the era start alone.</p>
  <p><b>Scope, stated honestly.</b> These two documents are entries in a staff library that has
  been maintained since 2022 &mdash; trackers, a bot guide, initiation, event guides, rank&#8209;up
  procedure, a rep training checklist, and a standing <i>Areas of Improvement</i> document. Only
  the two above were read. Every observation here is therefore about <i>these documents</i>, and
  any question that sounds like a gap may already be answered in one of the others.</p>
</footer>

</div>
"""


def main() -> int:
    ap = argparse.ArgumentParser(description="Build the standalone practice-to-profession page.")
    ap.add_argument("--shots", required=True, help="Directory holding the extracted anchor images")
    ap.add_argument("--out", required=True, help="Output HTML path")
    args = ap.parse_args()

    uris = {}
    for key, fname in ANCHORS.items():
        p = os.path.join(args.shots, fname)
        if not os.path.exists(p):
            raise SystemExit(f"missing anchor image: {p}")
        uris[key] = data_uri(p)

    html = PAGE.format(
        train=release_train_svg(),
        records=records_svg(),
        protractor=uris["protractor"],
        restrictions=uris["restrictions"],
    )
    with open(args.out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(html)
    print(f"wrote {args.out}  ({os.path.getsize(args.out)/1024:.0f} KB, self-contained)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
