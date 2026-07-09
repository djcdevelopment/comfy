# Valheim Netcode Replacement — Feasibility Research

Date: 2026-07-08. Method: 6-angle deep-research fan-out (108 agents, 25 sources,
70 extracted claims, 25 adversarially verified — 21 confirmed, 4 refuted). Each
claim below survived a 3-vote adversarial pass unless marked otherwise. This is a
**grounded feasibility assessment, not a build plan.**

The destination (restated so it does not get lost again): a **100% swap of
Valheim's native network/replication layer for an external authoritative server
(Lumberjacks), with the Valheim client still running and rendering locally.** The
sidecar/projection/priority-manifest work to date was the environment-dialing
warm-up, not the goal.

---

## Verdict up front

Nothing found rules this out. Nothing found proves anyone has done the *full*
swap either. The honest state is: **the individual mechanisms the goal depends on
are each independently demonstrated by shipping mods — but no one has been shown
to compose them into a complete transport/replication replacement.** This is a
"hard, unproven-in-full, no hard blocker discovered yet" verdict, not an
"impossible" one and not a "solved" one.

The single most important architectural finding: **Valheim's netcode is Iron
Gate's own bespoke stack (`ZNet`/`ZDOMan`/`ZNetView`/`ZRoutedRpc`), not built on
Mirror / Netcode for GameObjects / Photon.** So the clean "swap the transport
component" seam those frameworks provide (confirmed to exist for Mirror) **does
not exist in Valheim.** There is no designed-in transport abstraction to
substitute; interception has to be manufactured with Harmony patches against
bespoke internals. That is the crux of the difficulty.

---

## What the evidence confirms

### Runtime & tooling ceiling (Q3) — favorable

- **Valheim runs on Mono, not IL2CPP.** The BepInEx pack ships *unstripped Unity +
  Mono BCL DLLs*. [confirmed 2-1] — this was the specific thing to verify, and it
  verifies. Mono means full reflection + Harmony IL patching against private
  members is on the table; IL2CPP would have made this dramatically harder.
- **BepInEx patches in-game methods, classes, and entire assemblies without
  touching original files.** [confirmed 3-0] The interception mechanism itself is
  not in doubt.
- **Two real Harmony ceilings, both relevant to hot-path netcode:**
  - Harmony **cannot patch inlined methods** — after inlining the method is no
    longer a distinct call site. [confirmed 2-1]
  - Harmony **cannot prefix/postfix native/`extern` methods** — it needs the
    original IL to build the replacement. [confirmed 2-1] This matters at the
    Steam socket boundary, where the actual send/recv bottoms out in native
    Steamworks calls.

  Implication: the reachable surface is the **managed** ZNet/ZDOMan/ZRoutedRpc
  layer, not the native socket primitives beneath it. You intercept *above* the
  Steamworks native calls, not at them.

### Architecture (Q1) — well-mapped enough to plan against

- **`ZDOMan` is the replication/sync manager**; peers are registered with it to
  "keep all world objects in sync." [confirmed 3-0]
- **`ZRoutedRpc` is the central named-method RPC dispatch** —
  `ZRoutedRpc.instance.Register(name, handler)` and `InvokeRoutedRpc(targetID,
  name, pkg)`, supporting both point-to-point *and* broadcast targeting.
  [confirmed 3-0 ×2]
- **The Steam socket is reachable from managed code**: from a `ZNetPeer` you can
  cast `peer.m_socket` to `ZSteamSocket` and read the SteamID — i.e. the transport
  identity is inspectable via reflection/cast from a BepInEx plugin. [confirmed
  2-1]
- **Transport backends**: default = Steam sockets on UDP 2456–2457; crossplay =
  PlayFab **relay** (no port-forward). [confirmed 3-0 ×2] Two distinct backends to
  account for.
- **The core problem is real and confirmed**: ZDO/area ownership is **distributed
  to the first client entering a zone**, so a badly-connected owner degrades
  everyone in that zone; and **even with a dedicated server, clients still host
  their local areas.** [confirmed 3-0 ×2] Centralizing that authority is exactly
  the value proposition — and exactly what the swap has to seize.

### Prior art that de-risks specific mechanisms (Q2)

- **`BetterNetworking` (CW_Jesse)** is the strongest confirmed evidence that
  low-level netcode is reachable and modifiable in production:
  - implements a **ZDO "new connection buffer"** to prevent ZDO data loss on
    connect — i.e. ZDOMan-level interception. [confirmed 2-1]
  - **changes outgoing queue size and send/update rate** — the ZNet send-queue and
    tick mechanics, not gameplay config. [confirmed 3-0]
  - **operates at the Steamworks socket layer**, exposing min/max send rates and a
    **crossplay on/off toggle**. [confirmed 3-0]
- **`valheim-serverside` (ddormer)** targets the same problem — centralizing area
  simulation authority on the server. [confirmed 3-0] **BUT** the specific strong
  claims that it does this *by Harmony-patching ZNet/ZDOMan/ZNetView/ZRoutedRpc
  directly* [**REFUTED 0-3**] and that it is *server-side-only with stock clients*
  [**REFUTED 1-2**] did **not** survive verification. So treat it as evidence that
  *the goal is being pursued*, not as a proven blueprint for the mechanism.

### Blockers assessed (Q4) — one soft, one non-blocker, several unknowns

- **Connection handshake is a real gate.** The server validates a connecting peer
  on version, password, ban, whitelist, player count, and duplicate connection.
  [confirmed 2-1] Any external gateway that sits in front of or replaces ZNet's
  connection flow has to satisfy or reproduce these checks. (The *exact method
  sequence* of the handshake was **refuted 1-2** — so the gate exists, but treat
  the precise call chain as not-yet-verified.)
  **UPDATE 2026-07-09 (I0):** the exact sequence is now re-derived from a decompile —
  `ServerHandshake → ClientHandshake → SendPeerInfo → RPC_PeerInfo`, version gate
  `num != 36`, full server-side check order and error codes. See `NETCODE-MAP.md` funnel 5.
  This "refuted" item is resolved.
- **Save format is NOT a blocker.** World state is filesystem-portable: the
  `.fwl`/`.db` pair moves between differently-hosted servers with no machine, Steam
  session, or network-identity binding. [confirmed 2-1] Authority can live
  elsewhere without a save-format problem.
- **We could not confirm any Valve endorsement** of external authoritative
  servers — that claim was **refuted 0-3**. Absence of a found blocker is not a
  green light; EULA/anti-cheat posture for redistributing a modified netcode layer
  remains an **open question the research did not close.**

### Cross-game prior art (Q5) — informative, but the seam is missing here

- **Mirror decouples transport from netcode via a swappable component**, and ships
  many interchangeable transports (KCP/Telepathy/WebSockets/Steam/EOS/relay).
  [confirmed 3-0 ×2] This proves the *pattern* is clean **when the engine was
  designed for it.**
- **No evidence was found that Valheim uses Mirror/Netcode/Photon.** Its stack is
  bespoke. So Mirror is a reference for *what a good transport seam looks like*,
  not a component you can drop in. You would be **manufacturing** the seam Mirror
  gets for free.

---

## Honest map: proven vs. possible vs. unknown

| Sub-capability toward the full swap | Status from evidence |
| --- | --- |
| Mono runtime (reflection/Harmony viable) | **Proven** — unstripped Mono BCL ships |
| Intercept ZDOMan replication behavior | **Proven possible** — BetterNetworking does a ZDO connect-buffer |
| Manipulate ZNet send queue / rate | **Proven possible** — BetterNetworking changes queue size + send rate |
| Reach the Steamworks socket layer from managed code | **Proven possible** — send-rate control + crossplay toggle at that layer |
| Read transport identity (SteamID) from a peer | **Proven possible** — cast `m_socket` to `ZSteamSocket` |
| Centralize ZDO/area ownership on a server | **Being attempted** (valheim-serverside) — mechanism NOT verified |
| Full replacement of transport + replication with an external authority | **No evidence anyone has done it** — theoretically assembled from the above, unproven in composition |
| Satisfy/replace the connection handshake gate | **Theoretically necessary**, exact sequence unverified |
| Save/world format compatibility | **Non-blocker** — filesystem-portable |
| Legal/anti-cheat posture for redistribution | **Unknown** — not closed by this research |

---

## What this research did NOT resolve (next queries, if pursued)

1. **The actual `valheim-serverside` mechanism.** The most on-point prior art, and
   its patching approach is exactly what got refuted for lack of evidence. Reading
   its source directly (not search snippets) is the highest-value next step.
2. **Whether interception must sit above or below `ZRoutedRpc`.** RPC dispatch is
   named-method and reachable; ZDO sync is the harder, higher-frequency path. Which
   layer a full swap should hook is unresolved.
3. **Native-boundary reality.** Harmony can't touch the native Steamworks calls; is
   intercepting the managed `ZSteamSocket` wrapper's send/recv sufficient to
   redirect *all* replication traffic to an external authority, or do paths bypass
   it?
4. **The two-backend problem.** Does a swap have to handle both the Steam-socket
   and PlayFab-relay backends, or can it force one (BetterNetworking's crossplay
   toggle suggests forcing Steam-only is feasible)?
5. **Legal/ToS.** Redistributing a modified netcode layer — unknown and worth a
   dedicated check before any public release.

---

## Bottom line for the project

The earlier "not viable" verdict was wrong to record as a conclusion — it was an
inference from "the private state exists and looks complex," never a tested
finding. This research replaces it with a defensible position: **every primitive
the full swap needs has been demonstrated in isolation by a shipping mod on a
Mono runtime that Harmony can reach; no one has been shown to compose them into a
complete replacement; and the one genuine architectural disadvantage is that
Valheim — unlike Mirror-based games — has no designed-in transport seam, so the
interception layer must be built by hand against bespoke internals.** Hard and
unproven-in-full, but open. The next concrete move is source-level study of
`valheim-serverside` and `BetterNetworking`, not another web pass.
