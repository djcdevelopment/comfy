# ComfyMods inspection assessment

## Summary

Primary sources inspected:

- Thunderstore publisher page: <https://thunderstore.io/c/valheim/p/ComfyMods/>
- GitHub source repo: <https://github.com/redseiko/ComfyMods>
- Local inspection clone: `scratch/ComfyMods` (ignored by this repo)

The control-surface vertical slice should follow the ComfyMods repo's existing BepInEx + Harmony pattern and avoid adding Jotunn unless a later UI pass needs it. The strongest starting pattern is a small standalone mod like `ZoneScouter` or `Pinnacle`: one plugin class, `Config/PluginConfig.cs`, `Patches/`, `Core/`, duplicated local `ComfyLib` helpers as needed, and Thunderstore package files beside the project.

For v1, do not start from a heavy in-game panel. The handoff's hotkey plus console command path matches the repo better: use `KeyboardShortcut` config, `Terminal.ConsoleCommand`, `MessageHud`/`Chat` status, and plain files under `BepInEx/config/comfy-control`.

## Repo And Build System

ComfyMods is a multi-project Visual Studio solution, `ComfyMods.sln`, with one mod per top-level directory. Each mod owns its `.csproj`, `README.md`, `CHANGELOG.md`, `manifest.json`, `icon.png`, plugin entry class, config class, patches, and local helper copies.

Build conventions to reuse:

- Target framework: `net48` / `v4.8`.
- Language version: C# `12`.
- Output type: library.
- Main references: `BepInEx.dll`, `0Harmony.dll`, Valheim publicized assemblies, Unity assemblies.
- Post-build copy target copies the plugin DLL to `$(GamePath)\BepInEx\plugins`.
- Thunderstore package target zips the DLL plus package metadata.
- `Environment.props` exists only as a local override template for Valheim/BepInEx paths.

Most older mods use classic MSBuild `.csproj`; newer mods such as `ZoneScouter` and `BetterZeeLog` use SDK-style `Microsoft.NET.sdk`. For a new vertical slice, prefer the newer SDK-style `net48` shape from `ZoneScouter` unless the implementation is added directly to the upstream ComfyMods solution where consistency with nearby files is more important.

## Dependencies And Mod Frameworks

Observed dependencies:

- BepInEx plugin model through `[BepInPlugin(...)]` and `BaseUnityPlugin`.
- Harmony patching through `Harmony.CreateAndPatchAll(Assembly.GetExecutingAssembly(), harmonyInstanceId: PluginGuid)`.
- BepInEx config through `ConfigFile`, `ConfigEntry<T>`, and Comfy's `BindInOrder` helper.
- Unity UI modules for in-game panels.
- Unity input through BepInEx `KeyboardShortcut` and, in some cases, Valheim `ZInput`.
- Thunderstore dependency in manifests: `denikson-BepInExPack_Valheim-5.4.2202`.

Jotunn is not a primary pattern in the inspected candidates. `SearsCatalog` has compatibility behavior around Jotunn categories, but the repo's first-class pattern is direct Valheim/Harmony/Unity work rather than Jotunn-based mod structure.

## Reference Mods To Reuse

`ZoneScouter`

- Demonstrates: lightweight in-game HUD panel, button, draggable config-persisted position, player position/sector capture, periodic HUD update coroutine, hotkey with `KeyboardShortcut`.
- Exact files/classes: `ZoneScouter/ZoneScouter.cs`, `ZoneScouter/Config/PluginConfig.cs`, `ZoneScouter/Patches/HudPatch.cs`, `ZoneScouter/Core/SectorInfoPanelController.cs`, `ZoneScouter/Core/UI/SectorInfoPanel.cs`, `ZoneScouter/Core/UI/Builder/ButtonCell.cs`.
- Reuse level: adapt for player context capture and optional small status/debug panel. Copy only narrow UI/helper pieces if needed.
- Risks: its panel is a debug overlay, not a submission workflow. Do not let the v1 become a large always-on panel.

`Chatter`

- Demonstrates: chat-style UI, text input behavior, message capture, center message handling, direct terminal command registration.
- Exact files/classes: `Chatter/Chatter.cs`, `Chatter/Core/TerminalCommands.cs`, `Chatter/Patches/TerminalPatch.cs`, `Chatter/Patches/MessageHudPatch.cs`, `Chatter/Core/UI/ChatPanel.cs`, `Chatter/Core/UI/ChatPanel/InputFieldCell.cs`.
- Reuse level: style reference for terminal command registration and possible later notes/input UI. Do not copy the whole chat panel for v1.
- Risks: Chatter is chat-specific and patches core chat behavior heavily.

`Pinnacle`

- Demonstrates: command auto-registration helper, command classes, local export/import files, player-visible status via chat, logging wrapper with timestamps.
- Exact files/classes: `Pinnacle/Pinnacle.cs`, `Pinnacle/ComfyLib/Commands/ComfyCommand.cs`, `Pinnacle/Core/Commands/ExportPinsCommand.cs`, `Pinnacle/Core/PinImportExport.cs`, `Pinnacle/Patches/MinimapPatch.cs`.
- Reuse level: adapt command registration and file-output command structure. Use as the best reference for `comfy_submit` and `comfy_control_status`.
- Risks: `PinImportExport` writes relative paths and uses `FileMode.CreateNew`; the control surface needs explicit config-root paths and atomic `*.tmp` then rename.

`Intermission`

- Demonstrates: locating a config-adjacent plugin directory, creating config subfolders/files, reading local content, loading images, timestamped plugin logging.
- Exact files/classes: `Intermission/Intermission.cs`, `Intermission/Core/CustomAssets.cs`, `Intermission/Config/PluginConfig.cs`, `Intermission/Intermission.csproj`.
- Reuse level: adapt config-root path discovery and local directory creation.
- Risks: it is a content loader, not a structured writer. It also creates `File.Create(path)` without disposing in one path; do not copy that detail.

`ComfyLoadingScreens`

- Demonstrates: content-only Thunderstore package that installs files under `config/Intermission`, and package dependency on another Comfy mod.
- Exact files/classes: `ComfyLoadingScreens/ComfyLoadingScreens.csproj`, `ComfyLoadingScreens/manifest.json`.
- Reuse level: style reference for packaging default `config/comfy-control/actions.json` and fixtures if Comfy wants package-installed starter config.
- Risks: contains many large image assets; do not copy this content packaging scale into the control-surface slice.

`SearsCatalog`

- Demonstrates: config persistence for UI dimensions/position and patching an existing Valheim HUD surface.
- Exact files/classes: `SearsCatalog/SearsCatalog.cs`, `SearsCatalog/Config/PluginConfig.cs`, `SearsCatalog/Core/BuildHudController.cs`, `SearsCatalog/Patches/HudPatch.cs`, `SearsCatalog/ComfyLib/UI/Components/PanelDragger.cs`, `SearsCatalog/ComfyLib/UI/Components/PanelResizer.cs`.
- Reuse level: only as a UI/config style reference. It is too build-HUD-specific for the vertical slice.
- Risks: patches complex build UI paths and includes Jotunn-related compatibility; copying this would add unnecessary blast radius.

`BetterZeeLog`

- Demonstrates: minimal plugin, config-gated Harmony patching, log stack-trace tuning.
- Exact files/classes: `BetterZeeLog/BetterZeeLog.cs`, `BetterZeeLog/Config/PluginConfig.cs`, `BetterZeeLog/Patches/ZLogPatch.cs`.
- Reuse level: style reference for minimal plugin shape and log discipline.
- Risks: its purpose is log suppression/transpiling, not workflow logging. The vertical slice needs richer trace files, not less logging.

## UI Pattern Recommendation

V1 should not build a full panel first. Use:

- Configurable hotkey: `ConfigEntry<KeyboardShortcut>` defaulting to `F7`.
- Console commands: `comfy_submit` and `comfy_control_status`.
- Visible player status: `MessageHud.instance.ShowMessage(MessageHud.MessageType.Center, "...")` if available, with `Chat.m_instance.AddMessage(...)` as a fallback.

If a visible control surface is needed after the file contract works, start from `ZoneScouter/Core/UI/SectorInfoPanel.cs`: small HUD-root panel, clear button, `ContentSizeFitter`, `VerticalLayoutGroup`, `Button.onClick`, and persisted position through a `Vector2` config entry.

Do not start with Chatter's input panel unless v1 requires typed notes.

## Input And Command Pattern Recommendation

Recommended command pattern:

- Use the `Pinnacle/ComfyLib/Commands/ComfyCommand.cs` attribute scanner or a narrow direct `Terminal.ConsoleCommand` registration like `Chatter/Core/TerminalCommands.cs`.
- Register commands on plugin enable and refresh terminal command lists after registration.
- Keep command classes in `Core/Commands/SubmitCommand.cs` and `Core/Commands/StatusCommand.cs`.

Recommended hotkey pattern:

- Bind `ConfigEntry<KeyboardShortcut> SubmitShortcut`.
- Check `SubmitShortcut.Value.IsDown()` from a low-risk update hook such as a `Hud.Update` postfix or a small `MonoBehaviour` attached after `Hud.Awake`.
- Gate hotkey execution on `Player.m_localPlayer`, `Hud.m_instance`, no active text input, and mod enabled.

Avoid the `Shortcuts` mod's deep `ZInput` transpiler approach. It is useful for remapping built-in game actions but excessive for one control-surface shortcut.

## Config/File/Trace Pattern Recommendation

Use Comfy config conventions for simple settings and plain filesystem code for the workbench contract:

- BepInEx config entries: enabled flag, hotkey, optional debug flag, optional output root override.
- Action definitions: JSON file at `BepInEx/config/comfy-control/actions.json`, not BepInEx `.cfg`, because it is workflow data rather than plugin settings.
- Workbench root: derive from `Path.GetDirectoryName(Config.ConfigFilePath)` as `Intermission` does, then append `comfy-control`.
- Directories: create `outbox`, `evidence`, `traces`, and `status` before writing.
- Atomic payload write: write `<submission_id>.json.tmp`, flush/close, then `File.Move(tmp, final)`.
- Trace write: append JSONL events as each step completes or fails.
- Screenshot: no strong ComfyMods screenshot-capture reference was found. Use Unity's `ScreenCapture.CaptureScreenshot(path)` or a coroutine/readback path if the capture needs completion proof before payload validation. Add `UnityEngine.ImageConversionModule` only if doing manual texture PNG encoding.

Use `Pinnacle/Core/PinImportExport.cs` as the local export reference, but tighten path handling, status/error output, and atomic writes for the control-surface contract.

## Packaging Recommendation

Package like existing ComfyMods:

- `manifest.json`, `README.md`, `CHANGELOG.md`, `icon.png`, and plugin DLL in the Thunderstore zip.
- Manifest author: `ComfyMods`.
- Dependency: `denikson-BepInExPack_Valheim-5.4.2202`.
- `website_url`: GitHub source path once the mod exists.
- Package target should include starter non-binary files only if desired: `config/comfy-control/actions.json` and `fixtures/*.json`/`*.jsonl`.

If starter config is packaged, follow `ComfyLoadingScreens`' package structure idea, but keep assets small and text-only. Do not package generated evidence, traces, status files, or outbox files.

## Risks And Open Questions

- GPL-3.0: the source repo is GPL-3.0. Copying ComfyLib/helpers or code into a new mod likely brings GPL obligations. If licensing matters for this repo, prefer reimplementation of small patterns or make the new mod GPL-compatible.
- Screenshot completion: `ScreenCapture.CaptureScreenshot` may be asynchronous depending on Unity path. The implementation must verify the evidence file exists before writing `ready_for_review`.
- Player identity: ComfyMods references platform/publicized assemblies, but the handoff should define acceptable fallback values when platform ID is unavailable.
- World name/seed: the handoff should define exact Valheim APIs or fallback behavior to avoid guessing.
- Target capture: no inspected candidate directly implements looked-at-object proof capture. That should be deferred unless `requires_target` is true.
- Path roots: some ComfyMods write relative files. The control-surface slice should avoid relative working-directory ambiguity and always anchor to BepInEx config.
- UI conflict risk: HUD and chat patches are common mod conflict points. V1 should minimize patches and avoid replacing existing UI.

## Recommended Changes To in-game-control-surface.md

- State that v1 should use the ComfyMods BepInEx/Harmony pattern and should not introduce Jotunn unless a later implementation explicitly needs it.
- Add a build baseline: `net48`, C# 12, BepInExPack Valheim `5.4.2202`, Harmony from BepInEx core, Unity/Valheim references from the local Valheim install.
- Add a source-pattern note: start from `ZoneScouter`/`Pinnacle` patterns, not generic Valheim mod templates.
- Clarify screenshot implementation: allow `ScreenCapture.CaptureScreenshot` but require waiting/verification before payload status becomes `ready_for_review`.
- Clarify status messaging fallback order: `MessageHud` center message, then `Chat.m_instance.AddMessage`, then plugin logger.
- Clarify JSON serializer choice. ComfyMods does not standardize JSON payload writing; recommend `Newtonsoft.Json` only if already available in the runtime, otherwise a small explicit serializer strategy should be chosen before implementation.
- Clarify file root: all control files must be anchored under `Path.GetDirectoryName(Config.ConfigFilePath)/comfy-control`.
- Add a license note if code is copied from ComfyMods.

## Implementation Starting Point

Create a new standalone mod project modeled after `ZoneScouter` plus `Pinnacle`:

- `ComfyControlSurface/ComfyControlSurface.cs`: plugin constants, logger, `BindConfig`, command registration, Harmony patching.
- `ComfyControlSurface/Config/PluginConfig.cs`: enabled flag, `KeyboardShortcut SubmitShortcut = F7`, debug/status options.
- `ComfyControlSurface/Core/Commands/SubmitCommand.cs`: registers `comfy_submit`.
- `ComfyControlSurface/Core/Commands/StatusCommand.cs`: registers `comfy_control_status`.
- `ComfyControlSurface/Core/ActionDefinitionLoader.cs`: reads and validates `actions.json`.
- `ComfyControlSurface/Core/SubmissionService.cs`: captures player/world/position context, drives screenshot capture, validates payload, writes trace/status/outbox files.
- `ComfyControlSurface/Core/TraceWriter.cs`: append-only JSONL trace writer with failure-safe events.
- `ComfyControlSurface/Patches/HudPatch.cs`: hotkey detection and optional HUD-ready initialization.

Recommended first behavior: exactly one configured action, `F7` and `comfy_submit` both call the same `SubmissionService.Submit("submit_proof")`, write local trace/status/outbox files, and show a short player-visible message. Add an optional `ZoneScouter`-style panel only after that path is reliable.
