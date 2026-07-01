# Governance & Policy — a third axis (Creator Events rules)

> Alongside **actors** (personas/org) and **data** (economy, telemetry, ranks), Comfy has a
> **policy** layer. Policy is different in kind: it carries *intent*, it's **versioned** (rules
> evolve), and it's **era-scoped** like everything else. First instance captured here: the
> **Creator Events** rules. (Policy owners on the org chart: **Creator Lead** — "manages Creator
> Event policies and reward guidelines"; **Moderator** — enforcement; **Balance Strategist** — fairness.)

## The Creator Events rules — evolution

- **Old rules** (in effect for years): constructed in response to **people fighting over the
  opportunity to run events** — i.e., contention/scarcity around event-running.
- Then a **slow relaxation** to make Creator Events more **approachable for newbies**.
- **New rules** written with **two objectives**:
  1. **Simplify** the newbie path — "how to run your first Event."
  2. **Discourage farming** / prevent bad actors & competitive farmers from stressing/abusing the system.

## Why this matters to the hub

**The two objectives are in tension.** Simplicity pulls toward fewer/looser rules; anti-abuse pulls
toward more/tighter rules. Prose that tries to do both gets complex — which defeats objective #1.

**Objective #2 is a detection problem, not a rules problem.** "Farming" and "bad actors" are
**patterns in event-run telemetry**: same player + same event repeated, reward accumulation past a
threshold, suspicious timing/frequency. Rules only deter what someone can *see*; today that means a
human noticing. The hub can make abuse **visible** — the same move as the weapon-choices join
(surfacing "over-represented relative to cost").

**The payoff — the hub decouples the two objectives.** Move anti-farming enforcement to **back-end
detection** and the **newbie-facing rulebook can stay simple**, because the tight stuff is watched
in the data rather than spelled out in prose. Accessibility no longer has to be traded against
abuse-resistance.

## Throughline: "fairness under contention"

Recurs across subsystems — regen team keeping resources fair, weapon balance for "round fairness,"
event rules against farming. A candidate unifying purpose for the hub: **make fairness measurable.**

## Status

Both rule sets received and analyzed → **`docs/creator-events-rules-analysis.md`**. Key result:
the new rules already *decoupled the objectives* — newbie "how to play" (New #1–#5) is split from
anti-farming limits (New #7, #9), and the anti-farming limits are written as **hard countable
numbers** (≤2×/week, not-two-resets-in-a-row, solo ≤3×/era, FTT ≥50% new). All of them reduce to
one dependency: a **per-run log**. Recommended first hub feature: a **Creator Event run-log +
anti-farming detector**.

## Open questions

1. ~~See the rules text~~ — done (analyzed).
2. What does **"farming"** concretely trip on — mostly the countable limits above, or also softer
   abuse the rules don't number?
3. **Does a run-log exist today**, and how is a "run" recorded — Creator marks completion, or
   players submit (like turn-ins)? Is **solo** flagged? Is **loot attribution** captured?
4. Does "**run an event**" mean *complete* a Creator Event (my read from the rules), or *host* one?
