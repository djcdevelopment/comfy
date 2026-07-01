# Prompt: ComfyMods inspection assessment

```text
You are working in C:\work\comfy.

Goal:
Assess the existing ComfyMods Valheim mod ecosystem to determine the best implementation pattern for
the planned in-game control surface vertical slice.

Context:
The repo contains a handoff brief at:

  handoffs/in-game-control-surface.md

Read that file first. The vertical slice is not merely "a mod with a button." It is a Comfy-approved
in-game integration workbench:

  in-game player intent
  -> native control surface action
  -> captured local context
  -> structured submission payload
  -> local trace/proof artifact
  -> bridge/export file
  -> visible status back to the player

The user believes ComfyMods are likely approved/supported because they are published here:

  https://thunderstore.io/c/valheim/p/ComfyMods/

The apparent source repo is:

  https://github.com/redseiko/ComfyMods

Task:
Download or inspect the ComfyMods source and produce an assessment of which existing mod patterns
should be reused for the in-game control surface.

Do not implement the new mod yet.

Specific steps:
1. Read handoffs/in-game-control-surface.md.
2. Inspect the ComfyMods Thunderstore publisher page and/or clone/read
   https://github.com/redseiko/ComfyMods.
3. Identify repo structure, build system, target framework, package conventions, dependencies, and
   BepInEx/Harmony/Jotunn usage.
4. Find the best reference mods for:
   - in-game UI panels/buttons
   - keyboard shortcuts/input bindings
   - console commands
   - screenshot capture or local file output
   - config persistence
   - logging/debug/status output
   - Thunderstore packaging
5. Prefer these likely candidates if they exist:
   - Chatter
   - AlaCarte
   - SearsCatalog
   - ZoneScouter
   - BetterZeeLog
   - Intermission
   - ComfyLoadingScreens
6. For each useful reference mod, summarize:
   - what behavior/pattern it demonstrates
   - exact files/classes to read
   - whether it should be copied, adapted, or only used as a style reference
   - any risks or incompatibilities
7. Compare ComfyMods patterns against the current handoff brief. Note any changes the brief should
   make before implementation.
8. Produce a concise build recommendation for the control-surface vertical slice.

Deliverable:
Create a markdown assessment file at:

  handoffs/comfymods-inspection.md

Required sections:
- Summary
- Repo And Build System
- Dependencies And Mod Frameworks
- Reference Mods To Reuse
- UI Pattern Recommendation
- Input And Command Pattern Recommendation
- Config/File/Trace Pattern Recommendation
- Packaging Recommendation
- Risks And Open Questions
- Recommended Changes To in-game-control-surface.md
- Implementation Starting Point

Important constraints:
- Do not overwrite unrelated files.
- Do not implement the new vertical slice.
- Do not add large binaries or downloaded package artifacts to the repo.
- If you clone the ComfyMods repo, put it somewhere temporary or clearly ignored, such as
  scratch/ComfyMods.
- Treat the current worktree as user-owned; do not revert anything.
- Prefer primary sources: Thunderstore package pages and the GitHub source repo.
```

