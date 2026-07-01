# Segment 2 — Get into the world (a mod-loadable Valheim, running a given save)

**Goal:** Take a Valheim world save (a `.db` + `.fwl` pair) and produce a **running local Valheim
instance loaded into that world, in god + fly mode, with BepInEx installed** so that a plugin (built
in a separate segment) can control the camera. That's the whole job: make the world *enterable and
controllable.* You are not writing gameplay or analysis code.

You need to know Valheim and basic Windows. You do **not** need to know anything about where the save
came from or what it's for.

## Inputs
- A world save: two files, `<WorldName>.db` and `<WorldName>.fwl`. Treat them as read-only source.
- A Valheim installation (Steam). **Version matters:** the save has an internal "world version"; your
  Valheim client must be recent enough to open it. If Steam's current Valheim opens it, you're fine.
  (A save can be *upgraded* on load — so never point the game at the originals; see step 1.)

## Steps
1. **Work on a copy.** Copy the two save files into Valheim's single-player worlds folder:
   `%USERPROFILE%\AppData\LocalLow\IronGate\Valheim\worlds_local\`
   Keep the originals untouched elsewhere. (Loading may migrate the save format; you want that to
   happen to the copy, not the source.)
2. **Enable the console.** In Steam → Valheim → Properties → Launch Options, add `-console`.
3. **Install BepInEx for Valheim** (the standard modding framework — Thunderstore "BepInExPack
   Valheim"). Launch once so it generates its folders. Confirm `BepInEx/plugins/` exists.
4. **Load the world.** Start Valheim → Start Game → create/pick any character → select the copied
   world → enter it. (A fresh character in god mode is fine; you're a camera, not a player.)
5. **Verify control.** Open console (F5), type `devcommands`, then `god`, then `fly`. Confirm you can
   rise into the air and move freely, clip through terrain, and take no damage.
6. **Verify a plugin can load.** Drop any trivial "hello world" BepInEx plugin into
   `BepInEx/plugins/` and confirm it logs on launch (proves Segment 3's mod will run here).

## Definition of done (self-verifiable)
- You can launch, land in the target world, and fly around it with god mode.
- `BepInEx/plugins/` loads a test plugin (you see its log line at startup).
- Deliverable to the next segment: **written notes** of (a) the exact Valheim + BepInEx versions that
  worked, (b) the world name, (c) confirmation that `Player.m_localPlayer` is non-null once in-world
  (a mod will need it). One short README is enough.

## Constraints / notes
- Don't modify or save over the original `.db`/`.fwl`.
- If the world won't open ("incompatible version"), report the Valheim version and the error; do not
  try to hand-edit the save. That's an upstream issue, not yours to solve.
- No custom code required in this segment beyond the throwaway test plugin.

## Explicitly NOT your problem
- Where the coordinates to fly to come from (that's a JSON file another segment produces).
- Moving the camera automatically (Segment 3).
- Recording or editing video (Segment 4).
