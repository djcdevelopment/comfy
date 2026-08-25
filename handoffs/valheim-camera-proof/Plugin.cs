using BepInEx;
using BepInEx.Configuration;
using UnityEngine;
using System;
using System.Collections;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;

namespace Comfy.CameraProof
{
    [BepInPlugin("com.comfy.camera-proof", "Comfy Camera Proof", "0.2.0")]
    public sealed class Plugin : BaseUnityPlugin
    {
        private string ConfigDir => Paths.ConfigPath;
        private string WaypointsPath => Path.Combine(ConfigDir, "waypoints.json");
        private bool _stillJobRunning;
        private bool _hidePlayerForScreenshots = true;
        private int _waypointIndex = -1;
        private Vector3? _holdAt;      // pinned camera position while a shot is composed

        // Centred on the aim point, not the lens: an orbit stands off up to 120 m and
        // the fires worth lighting are the subject's, not the ones behind the camera.
        private const float FireSweepRadius = 80f;

        // Long enough that a 4K shutter lands inside it with room either side, short
        // enough to still read as one strike rather than a lit sky.
        private const float FlashHoldSeconds = 1.2f;

        // Hotkeys are configurable because this install shares a keyboard with other
        // Comfy plugins. F7 is deliberately avoided: ComfyControlSurface binds it for
        // quest submit.
        private ConfigEntry<KeyboardShortcut> _keyNext;
        private ConfigEntry<KeyboardShortcut> _keyPrev;
        private ConfigEntry<KeyboardShortcut> _keyCapture;
        private ConfigEntry<KeyboardShortcut> _keyStatus;
        private ConfigEntry<float> _settleSeconds;
        private ConfigEntry<string> _defaultVariantSet;

        private string ProgressPath => Path.Combine(ConfigDir, "comfy-camera-proof-progress.json");

        private void Awake()
        {
            _keyNext = Config.Bind("Hotkeys", "next", new KeyboardShortcut(KeyCode.RightArrow),
                "Teleport to the next waypoint in waypoints.json.");
            _keyPrev = Config.Bind("Hotkeys", "previous", new KeyboardShortcut(KeyCode.LeftArrow),
                "Teleport to the previous waypoint.");
            _keyCapture = Config.Bind("Hotkeys", "capture", new KeyboardShortcut(KeyCode.UpArrow),
                "Capture the current framing in four moods. Avoid F7 — ComfyControlSurface uses it.");
            _keyStatus = Config.Bind("Hotkeys", "status", new KeyboardShortcut(KeyCode.DownArrow),
                "Write the status proof file.");

            _settleSeconds = Config.Bind("Capture", "settleSeconds", 6f,
                "Seconds to let the sky and fog finish crossfading before each shot. "
                + "Atmospherics lerp in, so too short gives a frame mid-transition.");
            _defaultVariantSet = Config.Bind("Capture", "defaultVariantSet", "basic",
                "Which set the capture hotkey shoots: basic (24 frames, all weather), "
                + "weather (12), or quick (4).");

            LoadProgress();
            RegisterConsoleCommands();

            // Armed by a file, not a keystroke: this is what makes an unattended run
            // possible at all, since nothing here can type into the game's console.
            if (TryReadOrbitRequest(out var world, out var character, out var quitWhenDone))
            {
                StartCoroutine(AutoBoot(world, character, quitWhenDone));
            }
            Logger.LogInfo($"Comfy Camera Proof loaded. {_keyNext.Value} next, {_keyPrev.Value} previous, "
                           + $"{_keyCapture.Value} capture, {_keyStatus.Value} status. "
                           + $"Resuming at waypoint {_waypointIndex + 1}.");
        }

        /// <summary>Remember the rotation across restarts so a session picks up where it stopped.</summary>
        private void LoadProgress()
        {
            try
            {
                if (!File.Exists(ProgressPath)) return;
                var match = Regex.Match(File.ReadAllText(ProgressPath), "\"index\"\\s*:\\s*(-?\\d+)");
                if (match.Success)
                {
                    _waypointIndex = int.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture);
                }
            }
            catch (Exception ex)
            {
                Logger.LogWarning($"Could not read waypoint progress: {ex.Message}");
            }
        }

        private void SaveProgress()
        {
            try
            {
                WriteJson("comfy-camera-proof-progress.json",
                    "{\n  \"index\": " + _waypointIndex + ",\n  \"shown\": " + (_waypointIndex + 1) + "\n}\n");
            }
            catch (Exception ex)
            {
                Logger.LogWarning($"Could not save waypoint progress: {ex.Message}");
            }
        }

        /// <summary>
        /// True while the player is typing. The arrow keys double as console history
        /// and chat editing, so raw hotkeys must stand down whenever a text field owns
        /// the keyboard.
        /// </summary>
        private static bool TypingSomewhere()
        {
            try
            {
                if (global::Console.IsVisible()) return true;
                if (TextInput.IsVisible()) return true;
                if (Chat.instance != null && Chat.instance.HasFocus()) return true;
            }
            catch (Exception)
            {
                // A missing type on some game build should not wedge the hotkeys.
            }
            return false;
        }

        private void Update()
        {
            // Orbit shots sit hundreds of metres up. Gravity would drag the camera down
            // through every settle wait, so while a shot is being composed the position
            // is re-asserted each frame. This makes the runner work whether or not fly
            // mode happens to be on — one less thing for the operator to remember.
            if (_holdAt.HasValue)
            {
                var held = GetLocalPlayer();
                if (held != null)
                {
                    PlacePlayer(held, _holdAt.Value);
                }
            }

            if (TypingSomewhere())
            {
                return;
            }

            if (_keyStatus.Value.IsDown())
            {
                WriteStatusProof("hotkey-status");
            }

            if (_keyNext.Value.IsDown())
            {
                StepWaypoint(1);
            }

            if (_keyPrev.Value.IsDown())
            {
                StepWaypoint(-1);
            }

            if (_keyCapture.Value.IsDown() && !_stillJobRunning)
            {
                StartCoroutine(CaptureHere(_defaultVariantSet.Value));
            }
        }

        /// <summary>Walk the waypoint list without typing: F9 forward, F10 back.</summary>
        private void StepWaypoint(int delta)
        {
            var waypoints = LoadWaypoints();
            if (waypoints.Count == 0)
            {
                Announce("No waypoints in BepInEx/config/waypoints.json");
                return;
            }

            _waypointIndex += delta;
            if (_waypointIndex >= waypoints.Count) _waypointIndex = 0;
            if (_waypointIndex < 0) _waypointIndex = waypoints.Count - 1;

            var waypoint = waypoints[_waypointIndex];
            var detail = waypoint.Pieces > 0
                ? $"{waypoint.Pieces:n0} pieces, {waypoint.HeightM:0}m tall"
                : "no detail";
            Announce($"[{_waypointIndex + 1}/{waypoints.Count}] {detail}");
            SaveProgress();
            StartCoroutine(TeleportProof(waypoint));
        }

        private void Announce(string message)
        {
            Logger.LogInfo(message);
            try
            {
                // Only visible with the F5 console open, so it stays out of screenshots.
                global::Console.instance?.Print(message);
            }
            catch (Exception)
            {
                // console not up yet — the log line is enough
            }
        }

        private IEnumerator TeleportProof(Waypoint explicitWaypoint)
        {
            var waypoint = explicitWaypoint ?? LoadFirstWaypoint();
            if (waypoint == null)
            {
                WriteJson("comfy-camera-proof-move.json", "{\n  \"ok\": false,\n  \"error\": \"No waypoint found in BepInEx/config/waypoints.json\"\n}\n");
                yield break;
            }

            var player = GetLocalPlayer();
            if (player == null)
            {
                WriteJson("comfy-camera-proof-move.json", "{\n  \"ok\": false,\n  \"error\": \"Player.m_localPlayer not present\"\n}\n");
                yield break;
            }

            var target = new Vector3(waypoint.X, waypoint.Y ?? 80f, waypoint.Z);
            TryResolveGroundHeight(waypoint.X, waypoint.Z, out var ground);
            if (!waypoint.Y.HasValue && ground.HasValue)
            {
                target.y = ground.Value + 55f;
            }

            var before = ((Component)player).transform.position;
            var moved = TryTeleport(player, target);
            yield return new WaitForSeconds(4f);
            var after = ((Component)player).transform.position;
            if (Vector3.Distance(after, target) > 10f)
            {
                ((Component)player).transform.position = target;
                var body = ((Component)player).GetComponent<Rigidbody>();
                if (body != null)
                {
                    body.position = target;
                    body.velocity = Vector3.zero;
                }
                yield return new WaitForSeconds(1f);
                after = ((Component)player).transform.position;
                moved = Vector3.Distance(after, target) <= 10f;
            }

            var json = new StringBuilder();
            json.AppendLine("{");
            json.AppendLine($"  \"ok\": {JsonBool(moved)},");
            json.AppendLine($"  \"rank\": {waypoint.Rank},");
            json.AppendLine($"  \"player_present\": true,");
            json.AppendLine($"  \"ground_height\": {JsonNumberOrNull(ground)},");
            json.AppendLine($"  \"target\": {JsonVector(target)},");
            json.AppendLine($"  \"before\": {JsonVector(before)},");
            json.AppendLine($"  \"after\": {JsonVector(after)}");
            json.AppendLine("}");
            WriteJson("comfy-camera-proof-move.json", json.ToString());
            Logger.LogInfo("Comfy Camera Proof movement file written.");
        }

        private void RegisterConsoleCommands()
        {
            try
            {
                new Terminal.ConsoleCommand("comfyproof_status", "write Comfy camera status proof", ConsoleStatus);
                new Terminal.ConsoleCommand("comfyproof_move", "teleport to first Comfy waypoint, or to x y z when provided", ConsoleMove);
                new Terminal.ConsoleCommand("comfyproof_tp", "teleport to x y z and write movement proof", ConsoleTeleport);
                new Terminal.ConsoleCommand("comfyproof_stills", "capture stills for waypoints: comfyproof_stills [limit] [settleSeconds]", ConsoleStills);
                new Terminal.ConsoleCommand("comfyproof_env", "force environment: comfyproof_env Clear|Misty|Rain|ThunderStorm|noforce", ConsoleEnv);
                new Terminal.ConsoleCommand("comfyproof_time", "force time of day 0..1, or off: comfyproof_time 0.5", ConsoleTime);
                new Terminal.ConsoleCommand("comfyproof_envs", "write available environment names to comfy-camera-proof-envs.json", ConsoleEnvList);
                new Terminal.ConsoleCommand("comfyproof_sky", "dump sun/moon direction per time of day: comfyproof_sky [0.8,0.9,...]", ConsoleSky);
                new Terminal.ConsoleCommand("comfyproof_hideplayer", "hide/show local player: comfyproof_hideplayer on|off", ConsoleHidePlayer);
                new Terminal.ConsoleCommand("comfyproof_variantstills", "capture env/time variants: comfyproof_variantstills [limit] [settle] [variantSet]", ConsoleVariantStills);
                new Terminal.ConsoleCommand("comfyproof_capture", "capture variants at current position: comfyproof_capture [variantSet]", ConsoleCaptureHere);
                new Terminal.ConsoleCommand("capture", "capture variants at current position: capture [variantSet]", ConsoleCaptureHere);
                new Terminal.ConsoleCommand("next", "teleport to the next waypoint in the shot list", (args) => StepWaypoint(1));
                new Terminal.ConsoleCommand("prev", "teleport to the previous waypoint in the shot list", (args) => StepWaypoint(-1));
                new Terminal.ConsoleCommand("shot", "jump to shot list entry N: shot 12", ConsoleShot);
                new Terminal.ConsoleCommand("aim", "point the camera: aim <yaw> <pitch>  (pitch + = down)", ConsoleAim);
                new Terminal.ConsoleCommand("aimtest", "prove aiming works and holds: aimtest", ConsoleAimTest);
                new Terminal.ConsoleCommand("runplan", "shoot every line of shotplan.tsv: runplan [startIndex]", ConsoleRunPlan);
            }
            catch (Exception ex)
            {
                Logger.LogWarning($"Could not register console commands: {ex.Message}");
            }
        }

        private void ConsoleStatus(Terminal.ConsoleEventArgs args)
        {
            WriteStatusProof("console-command");
        }

        private void ConsoleMove(Terminal.ConsoleEventArgs args)
        {
            if (TryWaypointFromArgs(args, out var waypoint))
            {
                StartCoroutine(TeleportProof(waypoint));
                return;
            }
            StartCoroutine(TeleportProof(null));
        }

        private void ConsoleTeleport(Terminal.ConsoleEventArgs args)
        {
            if (!TryWaypointFromArgs(args, out var waypoint))
            {
                WriteJson("comfy-camera-proof-move.json", "{\n  \"ok\": false,\n  \"error\": \"Usage: comfyproof_tp x y z\"\n}\n");
                return;
            }
            StartCoroutine(TeleportProof(waypoint));
        }

        private void ConsoleStills(Terminal.ConsoleEventArgs args)
        {
            if (_stillJobRunning)
            {
                Logger.LogWarning("Still capture job is already running.");
                return;
            }

            var limit = args.TryParameterInt(1, 0);
            var settleSeconds = args.TryParameterFloat(2, 8f);
            if (settleSeconds < 1f)
            {
                settleSeconds = 1f;
            }
            StartCoroutine(CaptureStills(limit, settleSeconds));
        }

        private void ConsoleVariantStills(Terminal.ConsoleEventArgs args)
        {
            if (_stillJobRunning)
            {
                Logger.LogWarning("Still capture job is already running.");
                return;
            }

            var limit = args.TryParameterInt(1, 0);
            var settleSeconds = args.TryParameterFloat(2, 18f);
            var variantSet = args.Length >= 4 ? args[3] : "basic";
            if (settleSeconds < 1f)
            {
                settleSeconds = 1f;
            }
            StartCoroutine(CaptureVariantStills(limit, settleSeconds, variantSet));
        }

        private void ConsoleShot(Terminal.ConsoleEventArgs args)
        {
            if (!args.TryParameterInt(1, out var n))
            {
                Announce("Usage: shot <number from the shot list>");
                return;
            }
            // Land on n-1 so the shared step logic re-reads and clamps the list.
            _waypointIndex = n - 2;
            StepWaypoint(1);
        }

        // ---------------- unattended boot -------------------------------------------
        // Nothing in this repo can type into Valheim's console, so an unattended run
        // cannot be driven by console commands. Instead the mod arms itself from a file:
        // if orbit-request.json exists at startup it picks the character, opens the named
        // LOCAL world, waits for the player to exist, shoots the plan and quits.
        //
        // Local rather than a dedicated server because no server binary is installed here,
        // and single-player streams ZDOs straight off disk with no network in the way.
        // The character-selection sequence is the one proven by ComfyNetworkSense's
        // LabAutoJoinPatches; only the world half is new.
        private string OrbitRequestPath => Path.Combine(ConfigDir, "orbit-request.json");

        private bool TryReadOrbitRequest(out string world, out string character, out bool quitWhenDone)
        {
            world = null; character = null; quitWhenDone = true;
            try
            {
                if (!File.Exists(OrbitRequestPath)) return false;
                var text = File.ReadAllText(OrbitRequestPath);
                world = Match(text, "world");
                character = Match(text, "character");
                var q = Regex.Match(text, "\"quit_when_done\"\\s*:\\s*(true|false)");
                if (q.Success) quitWhenDone = q.Groups[1].Value == "true";
                return !string.IsNullOrEmpty(world);
            }
            catch (Exception ex)
            {
                Logger.LogError($"Could not read orbit request: {ex}");
                return false;
            }
        }

        /// <summary>Times a sky dump was asked for, from the same request file.</summary>
        private System.Collections.Generic.List<float> ReadSkyTimes()
        {
            var times = new System.Collections.Generic.List<float>();
            try
            {
                if (!File.Exists(OrbitRequestPath)) return times;
                var m = Regex.Match(File.ReadAllText(OrbitRequestPath),
                                    "\"sky_times\"\\s*:\\s*\\[([^\\]]*)\\]");
                if (!m.Success) return times;
                foreach (var part in m.Groups[1].Value.Split(','))
                {
                    if (float.TryParse(part.Trim(), NumberStyles.Float,
                                       CultureInfo.InvariantCulture, out var t))
                    {
                        times.Add(Mathf.Clamp01(t));
                    }
                }
            }
            catch (Exception ex)
            {
                Logger.LogError($"Could not read sky_times: {ex.Message}");
            }
            return times;
        }

        private static string Match(string text, string key)
        {
            var m = Regex.Match(text, "\"" + key + "\"\\s*:\\s*\"([^\"]*)\"");
            return m.Success ? m.Groups[1].Value : null;
        }

        private IEnumerator AutoBoot(string worldName, string characterName, bool quitWhenDone)
        {
            Logger.LogInfo($"Orbit auto-boot: world='{worldName}' character='{characterName ?? "(first)"}'");
            var flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance;
            var deadline = Time.realtimeSinceStartup + 180f;

            while (FejdStartup.instance == null && Time.realtimeSinceStartup < deadline)
                yield return new WaitForSeconds(0.5f);
            var fejd = FejdStartup.instance;
            if (fejd == null) { Logger.LogError("Orbit auto-boot: no FejdStartup."); yield break; }

            // Valheim logs into PlayFab before the character list is populated.
            while (!PlayFabManager.IsLoggedIn && Time.realtimeSinceStartup < deadline)
                yield return new WaitForSeconds(0.5f);

            var t = typeof(FejdStartup);
            var showSelection = t.GetMethod("ShowCharacterSelection", flags);
            var updateList = t.GetMethod("UpdateCharacterList", flags);
            var setSelected = t.GetMethod("SetSelectedProfile", flags);
            var onStart = t.GetMethod("OnCharacterStart", flags);
            var loadScene = t.GetMethod("LoadMainScene", flags);
            var profilesField = t.GetField("m_profiles", flags);
            var profileIndex = t.GetField("m_profileIndex", flags);

            showSelection?.Invoke(fejd, null);
            yield return new WaitForSeconds(1f);

            System.Collections.IList profiles = null;
            while (Time.realtimeSinceStartup < deadline)
            {
                updateList?.Invoke(fejd, null);
                yield return new WaitForSeconds(0.5f);
                profiles = profilesField?.GetValue(fejd) as System.Collections.IList;
                if (profiles != null && profiles.Count > 0) break;
            }
            if (profiles == null || profiles.Count == 0)
            {
                Logger.LogError("Orbit auto-boot: no character profiles available.");
                yield break;
            }

            var index = 0;
            if (!string.IsNullOrEmpty(characterName))
            {
                for (var i = 0; i < profiles.Count; i++)
                {
                    var nm = (profiles[i] as PlayerProfile)?.GetName();
                    if (!string.IsNullOrEmpty(nm) &&
                        nm.Equals(characterName, StringComparison.OrdinalIgnoreCase))
                    {
                        index = i;
                        break;
                    }
                }
            }
            var chosen = profiles[index] as PlayerProfile;
            Logger.LogInfo($"Orbit auto-boot: character '{chosen?.GetName()}' (index {index}).");

            profileIndex?.SetValue(fejd, index);
            if (chosen != null) setSelected?.Invoke(fejd, new object[] { chosen.GetFilename() });
            updateList?.Invoke(fejd, null);
            yield return new WaitForSeconds(0.5f);
            onStart?.Invoke(fejd, null);
            yield return new WaitForSeconds(0.5f);

            // Never GetCreateWorld blindly — a typo would silently generate a brand new
            // empty world and shoot six photographs of nothing.
            World target = null;
            SaveSystem.ForceRefreshCache();
            foreach (var w in SaveSystem.GetWorldList())
            {
                if (w != null && string.Equals(w.m_name, worldName, StringComparison.OrdinalIgnoreCase))
                {
                    target = w;
                    break;
                }
            }
            if (target == null)
            {
                Logger.LogError($"Orbit auto-boot: world '{worldName}' not found; refusing to create one.");
                yield break;
            }

            ZNet.SetServer(server: true, openServer: false, publicServer: false,
                           serverName: string.Empty, password: string.Empty, world: target);
            loadScene?.Invoke(fejd, null);
            Logger.LogInfo($"Orbit auto-boot: loading '{target.m_name}' single-player.");

            var worldDeadline = Time.realtimeSinceStartup + 600f;
            while (GetLocalPlayer() == null && Time.realtimeSinceStartup < worldDeadline)
                yield return new WaitForSeconds(1f);
            if (GetLocalPlayer() == null)
            {
                Logger.LogError("Orbit auto-boot: player never spawned.");
                yield break;
            }

            Logger.LogInfo("Orbit auto-boot: player is in-world; settling before capture.");
            yield return new WaitForSeconds(12f);

            // A sky dump is a measurement rather than a capture, but it still needs
            // a loaded world -- EnvMan only exists inside a scene. Same file, same
            // unattended path, because nothing here can type into the console.
            var skyTimes = ReadSkyTimes();
            if (skyTimes.Count > 0)
            {
                yield return SkyDumpRoutine(skyTimes);
            }
            else
            {
                yield return RunShotPlan(0);
            }

            if (quitWhenDone)
            {
                Logger.LogInfo("Orbit auto-boot: plan complete, quitting.");
                yield return new WaitForSeconds(2f);
                Application.Quit();
            }
        }

        // ---------------- automated orbit capture ----------------------------------
        // Reads shotplan.tsv (written by tools/selfie-stick/plan_shots.py) and shoots
        // every line: place, clamp, aim, set the light, wait for the world to actually
        // arrive, capture. Flat TSV rather than the sibling JSON because this file has
        // no JSON parser, and one line per shot cannot be misparsed the way nested
        // objects can.
        private string ShotPlanPath => Path.Combine(ConfigDir, "shotplan.tsv");
        private string ShotReceiptsPath => Path.Combine(ConfigDir, "shotplan-receipts.jsonl");

        private sealed class Shot
        {
            public int ClusterId;
            public string Name;
            public Vector3 Camera;
            public float Yaw;
            public float Pitch;
            public string Environment;
            public float TimeOfDay;
            public Vector3 Aim;
            public string Label;
            public string Mode;
            public bool Fires;
            public float? Flash;
        }

        /// <summary>Optional trailing TSV columns are how every plan already on disk
        /// stays readable: absent means "as before", never "off by accident".</summary>
        private static bool TsvFlag(string value)
        {
            if (string.IsNullOrEmpty(value)) return false;
            var v = value.Trim();
            return v == "1" || v.Equals("true", StringComparison.OrdinalIgnoreCase)
                            || v.Equals("yes", StringComparison.OrdinalIgnoreCase);
        }

        private static float? TsvFloat(string value)
        {
            if (string.IsNullOrEmpty(value)) return null;
            var v = value.Trim();
            if (v.Length == 0 || v == "-" || v.Equals("off", StringComparison.OrdinalIgnoreCase)) return null;
            return float.TryParse(v, NumberStyles.Float, CultureInfo.InvariantCulture, out var f)
                ? (float?)f : null;
        }

        /// <summary>
        /// Interior rows (14th TSV column, written by plan_interiors.py) keep their
        /// composed position: the ground clamp relaxes to eye-height margins and
        /// occlusion recovery -- which exists to escape foliage -- stays off, because
        /// indoors every "rescue" is a teleport through the roof.
        /// </summary>
        private static bool IsInterior(Shot s)
            => string.Equals(s.Mode, "interior", StringComparison.OrdinalIgnoreCase);

        private static FieldInfo FindField(Type type, string name)
        {
            for (var cur = type; cur != null; cur = cur.BaseType)
            {
                var f = cur.GetField(name,
                    BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                if (f != null) return f;
            }
            return null;
        }

        /// <summary>
        /// The camera rig is not a combatant. Shots teleport the player into
        /// courtyards and halls where wolves, raids and fall damage are real; a
        /// death mid-plan costs a respawn wait and puts a freshly *visible*
        /// corpse-run character in frame (the hide toggle binds to the instance
        /// that died). God and ghost mode via reflection, because nothing here
        /// can type 'devcommands' into the console.
        /// </summary>
        private void SetInvulnerable(object player, bool on)
        {
            if (player == null) return;
            try
            {
                var type = player.GetType();
                var god = type.GetMethod("SetGodMode",
                    BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                if (god != null)
                {
                    god.Invoke(player, new object[] { on });
                }
                else
                {
                    var f = FindField(type, "m_godMode");
                    if (f != null) f.SetValue(player, on);
                }
                var ghost = FindField(type, "m_ghostMode");
                if (ghost != null) ghost.SetValue(player, on);
            }
            catch (Exception ex)
            {
                Logger.LogWarning($"Could not set god/ghost mode: {ex.Message}");
            }
        }

        private System.Collections.Generic.List<Shot> LoadShotPlan()
        {
            var plan = new System.Collections.Generic.List<Shot>();
            if (!File.Exists(ShotPlanPath))
            {
                return plan;
            }

            foreach (var raw in File.ReadAllLines(ShotPlanPath))
            {
                var line = raw.Trim();
                if (line.Length == 0 || line.StartsWith("#")) continue;
                var f = line.Split('\t');
                if (f.Length < 12) continue;
                try
                {
                    plan.Add(new Shot
                    {
                        ClusterId = int.Parse(f[0], CultureInfo.InvariantCulture),
                        Name = f[1],
                        Camera = new Vector3(P(f[2]), P(f[3]), P(f[4])),
                        Yaw = P(f[5]),
                        Pitch = P(f[6]),
                        Environment = f[7],
                        TimeOfDay = P(f[8]),
                        Aim = new Vector3(P(f[9]), P(f[10]), P(f[11])),
                        Label = f.Length > 12 ? f[12] : "",
                        Mode = f.Length > 13 ? f[13].Trim() : "",
                        Fires = f.Length > 14 && TsvFlag(f[14]),
                        Flash = f.Length > 15 ? TsvFloat(f[15]) : null
                    });
                }
                catch (Exception ex)
                {
                    Logger.LogWarning($"shotplan line skipped: {ex.Message}");
                }
            }
            return plan;
        }

        private static float P(string s) => float.Parse(s, CultureInfo.InvariantCulture);

        /// <summary>
        /// Put the lens where the plan says. Valheim's third-person camera rides a boom
        /// behind the player, so without collapsing it the planned position is the
        /// character's feet and every frame is composed several metres off.
        /// </summary>
        private float SetCameraBoom(float distance)
        {
            try
            {
                var cam = GameCamera.instance;
                if (cam == null) return -1f;
                var flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance;
                var f = typeof(GameCamera).GetField("m_distance", flags);
                if (f == null) return -1f;
                var was = (float)f.GetValue(cam);
                f.SetValue(cam, distance);
                var min = typeof(GameCamera).GetField("m_minDistance", flags);
                if (min != null && distance <= 0f) min.SetValue(cam, 0f);
                return was;
            }
            catch (Exception ex)
            {
                Logger.LogWarning($"Could not set camera boom: {ex.Message}");
                return -1f;
            }
        }

        private static float CameraFov()
        {
            var cam = Camera.main;
            return cam == null ? -1f : cam.fieldOfView;
        }

        /// <summary>
        /// Is anything solid between the lens and the subject? A shot straight into a
        /// hillside looks exactly like a successful capture unless you check.
        /// </summary>
        private static bool IsOccluded(Vector3 from, Vector3 to)
        {
            try
            {
                var dir = to - from;
                var dist = dir.magnitude;
                if (dist < 1f) return false;
                // Stop a little short: the subject itself is solid and would always hit.
                return Physics.Raycast(from, dir.normalized, out _, dist * 0.85f,
                                       LayerMask.GetMask("terrain", "static_solid", "Default"));
            }
            catch (Exception)
            {
                return false;
            }
        }

        /// <summary>How much of the build has actually streamed in near the aim point.</summary>
        private static int PiecesNear(Vector3 point, float radius)
        {
            try
            {
                var hits = Physics.OverlapSphere(point, radius,
                                                 LayerMask.GetMask("piece", "static_solid"));
                return hits == null ? 0 : hits.Length;
            }
            catch (Exception)
            {
                return -1;
            }
        }

        /// <summary>
        /// Wait for the world to arrive. A 20,000-piece build streams in over seconds;
        /// shooting on arrival gets an empty hillside, and that failure is invisible in
        /// the resulting image. Gate on the piece count going quiet, not on a timer.
        /// </summary>
        private bool _lastWorldSettled;

        private IEnumerator WaitForWorld(Vector3 aim, float maxSeconds)
        {
            _lastWorldSettled = true;
            var start = Time.time;
            var last = -1;
            var stableFor = 0f;
            while (Time.time - start < maxSeconds)
            {
                var n = PiecesNear(aim, 60f);
                // A count of zero is perfectly stable, and completely wrong. During a
                // loading screen -- which Valheim drops into on some long teleports --
                // nothing is loaded, the count sits at 0, and "the world has stopped
                // changing" is technically true of an empty world. Six frames in one run
                // were captures of the loading screen itself, and they passed this gate
                // in 1.5 seconds. Stability only counts once something is actually there.
                if (n > 0 && n == last)
                {
                    stableFor += 0.5f;
                    if (stableFor >= 1.5f) { _lastWorldSettled = true; yield break; }
                }
                else
                {
                    stableFor = 0f;
                }
                last = n;
                yield return new WaitForSeconds(0.5f);
            }
            Logger.LogWarning($"World did not settle within {maxSeconds:0}s near {JsonVector(aim)}");
            _lastWorldSettled = PiecesNear(aim, 60f) > 0;
        }

        /// <summary>
        /// Yaw/pitch that looks from <paramref name="from"/> at <paramref name="at"/>,
        /// in the same convention plan_shots.py emits: yaw clockwise from +Z, pitch
        /// positive looking down.
        /// </summary>
        private static void LookAngles(Vector3 from, Vector3 at, out float yaw, out float pitch)
        {
            var d = at - from;
            var n = d.magnitude;
            if (n < 0.001f) { yaw = 0f; pitch = 0f; return; }
            yaw = Mathf.Repeat(Mathf.Atan2(d.x, d.z) * Mathf.Rad2Deg, 360f);
            pitch = -Mathf.Asin(Mathf.Clamp(d.y / n, -1f, 1f)) * Mathf.Rad2Deg;
        }

        /// <summary>
        /// Find somewhere the subject is actually visible from.
        ///
        /// The planner has no terrain and no vegetation, so a mathematically perfect
        /// orbit point lands inside a tree often enough to matter — one in eighteen on
        /// the first run, and that frame was pure canopy. Detecting it is only half the
        /// job: a flagged frame is still a wasted frame.
        ///
        /// Lift before rotating. The obstruction is usually foliage at the camera rather
        /// than a hill in the middle distance, so gaining height clears it while keeping
        /// the composition the planner chose.
        /// </summary>
        private Vector3 FindClearView(Vector3 desired, Vector3 aim, out string how)
        {
            how = "planned";
            if (!IsOccluded(desired, aim)) return desired;

            // Measured over 202 automated shots: 4% of frames needed recovery, and six
            // of the eight successful lifts landed on +40 m -- the top of the old ladder.
            // A ladder that clears by its last rung is one bad tree away from failing, so
            // it now reaches 60.
            foreach (var lift in new[] { 8f, 16f, 26f, 40f, 60f })
            {
                var c = new Vector3(desired.x, desired.y + lift, desired.z);
                if (!IsOccluded(c, aim)) { how = $"lifted+{lift:0}m"; return c; }
            }

            // Swinging is the fallback for a build the lift ladder could not clear, so
            // it must not re-test heights the ladder already rejected. The first version
            // swung at +8 m on a structure that had needed +40 m one azimuth earlier,
            // which is to say it searched a plane already known to be solid forest.
            // Sweep bearings at each height, tallest first.
            var offset = desired - aim;
            var radius = new Vector2(offset.x, offset.z).magnitude;
            var baseAngle = Mathf.Atan2(offset.x, offset.z);
            foreach (var lift in new[] { 60f, 40f, 26f, 16f })
            {
                for (var deg = 15f; deg <= 90f; deg += 15f)
                {
                    foreach (var sign in new[] { 1f, -1f })
                    {
                        var a = baseAngle + Mathf.Deg2Rad * deg * sign;
                        var c = new Vector3(aim.x + Mathf.Sin(a) * radius,
                                            desired.y + lift,
                                            aim.z + Mathf.Cos(a) * radius);
                        if (!IsOccluded(c, aim))
                        {
                            how = $"swung{(sign > 0 ? "+" : "-")}{deg:0}deg+{lift:0}m";
                            return c;
                        }
                    }
                }
            }

            how = "still_blocked";   // shoot anyway; the receipt says why it is bad
            return desired;
        }

        private void ConsoleRunPlan(Terminal.ConsoleEventArgs args)
        {
            if (_stillJobRunning)
            {
                Announce("a capture job is already running");
                return;
            }
            var from = args.TryParameterInt(1, 0);
            StartCoroutine(RunShotPlan(from));
        }

        private IEnumerator RunShotPlan(int startIndex)
        {
            var plan = LoadShotPlan();
            if (plan.Count == 0)
            {
                Announce($"no shots in {ShotPlanPath}");
                yield break;
            }

            _stillJobRunning = true;
            var outRoot = Path.Combine(ConfigDir, "comfy-orbit-captures");
            var runId = DateTime.Now.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture);
            var outDir = Path.Combine(outRoot, runId);
            Directory.CreateDirectory(outDir);
            Announce($"orbit capture: {plan.Count - startIndex} shot(s) -> {runId}");

            // One reflection walk per run, so the environment list stops being a thing
            // nobody has ever looked at.
            WriteEnvironmentNames();

            var settle = Mathf.Max(1f, _settleSeconds.Value);
            var priorBoom = SetCameraBoom(0f);      // first person: lens at the planned point
            SetCaptureChromeHidden(true);
            if (_hidePlayerForScreenshots) SetLocalPlayerVisible(false);

            var shotIndex = 0;
            for (var i = startIndex; i < plan.Count; i++)
            {
                var s = plan[i];
                // Player.m_localPlayer goes transiently null -- death and respawn, a zone
                // transition, a moment of loading. Treating that as fatal cost 51 shots
                // and 8 structures at index 429 of 480, three hours into a run, because
                // one frame happened to catch the gap. Wait for it to come back.
                var player = GetLocalPlayer();
                if (player == null)
                {
                    Logger.LogWarning($"[{i + 1}/{plan.Count}] no local player; waiting for respawn");
                    var waited = 0f;
                    while (player == null && waited < 90f)
                    {
                        yield return new WaitForSeconds(2f);
                        waited += 2f;
                        player = GetLocalPlayer();
                    }
                    if (player == null)
                    {
                        Logger.LogError($"Orbit capture stopped at {i + 1}/{plan.Count}: "
                                        + "player did not return within 90s.");
                        break;
                    }
                    Logger.LogInfo($"  player back after {waited:0}s; continuing");
                    // A respawned player is a new instance: the hide toggle from the
                    // session setup no longer applies to it.
                    if (_hidePlayerForScreenshots) SetLocalPlayerVisible(false);
                }
                SetInvulnerable(player, true);

                // Never end up inside the hill. The planner has no terrain data at all,
                // so this is the first moment anything knows the real ground height.
                // Interior cameras sit at eye height by design -- the 2 m margin that
                // keeps an orbit out of a hillside would shove them to the ceiling, so
                // they keep just enough to stay out of the dirt.
                var target = s.Camera;
                var minAbove = IsInterior(s) ? 0.2f : 2f;
                if (TryResolveGroundHeight(target.x, target.z, out var ground) && ground.HasValue
                    && target.y < ground.Value + minAbove)
                {
                    target.y = ground.Value + minAbove;
                }

                var yaw = s.Yaw;
                var pitch = s.Pitch;
                PlacePlayer(player, target);
                _holdAt = target;                    // pin against gravity for the whole shot
                TryAim(yaw, pitch);
                SetForcedEnvironment(s.Environment);
                SetDebugTime(s.TimeOfDay);

                yield return WaitForStablePlayer(target, 15f);
                yield return WaitForWorld(s.Aim, 25f);

                // Only now is it worth asking whether the view is blocked. A raycast can
                // only hit colliders that exist, and at placement time the trees have not
                // streamed in yet -- checking then reports "clear" for a camera that is
                // about to be buried in a canopy. Run 4 proved it: one frame came back
                // occluded=true with clearance=planned, the two checks disagreeing purely
                // because they ran either side of the world loading.
                var clearance = "planned";
                var moved = target;
                if (!IsInterior(s))
                {
                    moved = FindClearView(target, s.Aim, out clearance);
                }
                if (clearance != "planned")
                {
                    Logger.LogInfo($"  view was blocked; {clearance}");
                    target = moved;
                    LookAngles(target, s.Aim, out yaw, out pitch);
                    PlacePlayer(player, target);
                    _holdAt = target;
                    yield return WaitForStablePlayer(target, 10f);
                }

                TryAim(yaw, pitch);                  // re-assert after the world loaded

                // Held after the world has streamed in and after any occlusion move, so
                // the sweep is centred on the subject this frame will actually contain.
                // LightLod re-reads its distances once a second and UpdateFireplace ticks
                // every two, and settle is six at its shortest, so both land before the
                // shutter. Reach is measured from where the lens ended up rather than
                // where the plan wanted it.
                if (s.Fires)
                {
                    HoldFiresLit(s.Aim, FireSweepRadius, Vector3.Distance(target, s.Aim) + 40f);
                }
                else
                {
                    // Never let a held shot's counts ride along into an unheld receipt.
                    _firesFound = _firesWereBurning = _firesWereWet = _firesLit = 0;
                    _firesUnowned = _lodsWidened = 0;
                }
                yield return new WaitForSeconds(settle);

                var pieces = PiecesNear(s.Aim, 60f);
                if (pieces <= 0)
                {
                    // Do not photograph a loading screen. Better a gap in the plan that
                    // says why than a file that looks like a capture and is not one.
                    Logger.LogWarning($"[{i + 1}/{plan.Count}] {s.Label} {s.Name}: world never "
                                      + "arrived (0 pieces) -- shot skipped");
                    AppendReceipt("{\"run\":" + JsonString(runId) + ",\"index\":" + i
                                  + ",\"cluster_id\":" + s.ClusterId + ",\"shot\":" + JsonString(s.Name)
                                  + ",\"mode\":" + JsonString(s.Mode)
                                  + ",\"skipped\":\"world_never_loaded\"}");
                    continue;
                }
                var occluded = IsOccluded(target, s.Aim);
                var fileName = $"{s.ClusterId:0000}_{s.Name}.png";
                var path = Path.Combine(outDir, fileName);

                var flash = "off";
                if (s.Flash.HasValue)
                {
                    flash = DriveFlash(s.Aim, target, s.Flash.Value, FlashHoldSeconds);
                    // Inside the hold, past the frame the lights need to be applied on.
                    yield return new WaitForSeconds(0.2f);
                }

                ScreenCapture.CaptureScreenshot(path);
                yield return new WaitForSeconds(1f);
                if (s.Fires) ReleaseHeldLight();

                var cam = Camera.main;
                var lens = cam == null ? target : cam.transform.position;
                AppendReceipt(new StringBuilder()
                    .Append("{")
                    .Append($"\"run\":{JsonString(runId)},")
                    .Append($"\"index\":{i},")
                    .Append($"\"cluster_id\":{s.ClusterId},")
                    .Append($"\"shot\":{JsonString(s.Name)},")
                    .Append($"\"mode\":{JsonString(s.Mode)},")
                    .Append($"\"label\":{JsonString(s.Label)},")
                    .Append($"\"file\":{JsonString(fileName)},")
                    .Append($"\"planned\":{JsonVector(s.Camera)},")
                    .Append($"\"placed\":{JsonVector(target)},")
                    .Append($"\"lens\":{JsonVector(lens)},")
                    .Append($"\"lens_offset_m\":{JsonNumber(Vector3.Distance(lens, target))},")
                    .Append($"\"aim\":{JsonVector(s.Aim)},")
                    .Append($"\"yaw\":{JsonNumber(yaw)},\"pitch\":{JsonNumber(pitch)},")
                    .Append($"\"clearance\":{JsonString(clearance)},")
                    .Append($"\"fov\":{JsonNumber(CameraFov())},")
                    .Append($"\"environment\":{JsonString(s.Environment)},")
                    .Append($"\"time_of_day\":{JsonNumber(s.TimeOfDay)},")
                    .Append($"\"fires\":{JsonBool(s.Fires)},")
                    .Append($"\"fires_found\":{_firesFound},")
                    .Append($"\"fires_burning\":{_firesWereBurning},")
                    .Append($"\"fires_wet\":{_firesWereWet},")
                    .Append($"\"fires_lit\":{_firesLit},")
                    .Append($"\"fires_unowned\":{_firesUnowned},")
                    .Append($"\"light_lods\":{_lodsWidened},")
                    .Append($"\"flash\":{JsonString(flash)},")
                    .Append($"\"flash_bearing_deg\":{JsonNumberOrNull(s.Flash)},")
                    .Append($"\"flash_hold_s\":{(s.Flash.HasValue ? JsonNumber(FlashHoldSeconds) : "null")},")
                    .Append($"\"pieces_near_aim\":{pieces},")
                    .Append($"\"occluded\":{JsonBool(occluded)},")
                    .Append($"\"at\":{JsonString(DateTime.Now.ToString("o", CultureInfo.InvariantCulture))}")
                    .Append("}")
                    .ToString());

                shotIndex++;
                Logger.LogInfo($"[{i + 1}/{plan.Count}] {s.Label} {s.Name} "
                               + $"pieces={pieces} occluded={occluded}");
            }

            _holdAt = null;
            ReleaseHeldLight();
            SetForcedEnvironment("");
            SetDebugTime(null);
            SetCaptureChromeHidden(false);
            SetLocalPlayerVisible(!_hidePlayerForScreenshots);
            SetInvulnerable(GetLocalPlayer(), false);
            if (priorBoom >= 0f) SetCameraBoom(priorBoom);
            _stillJobRunning = false;
            var done = shotIndex;
            Announce(done >= plan.Count - startIndex
                ? $"orbit capture finished: {done}/{plan.Count - startIndex} -> {outDir}"
                : $"orbit capture ENDED EARLY: {done}/{plan.Count - startIndex} -> {outDir}");
        }

        private void AppendReceipt(string json)
        {
            try
            {
                File.AppendAllText(ShotReceiptsPath, json + "\n", Encoding.UTF8);
            }
            catch (Exception ex)
            {
                Logger.LogWarning($"Could not append receipt: {ex.Message}");
            }
        }

        private void ConsoleAim(Terminal.ConsoleEventArgs args)
        {
            if (!args.TryParameterFloat(1, out var yaw) || !args.TryParameterFloat(2, out var pitch))
            {
                Announce("Usage: aim <yaw 0-360> <pitch, + is down>");
                return;
            }
            Announce(TryAim(yaw, pitch) ? $"aimed yaw {yaw:0.#} pitch {pitch:0.#}" : "aim failed");
        }

        /// <summary>
        /// The spike: does writing the player's look direction actually move the camera,
        /// and does it survive the next frame, or does GameCamera reassert control?
        /// Reports the angle between the requested direction and the camera's real
        /// forward vector, immediately and again after a second of gameplay.
        /// </summary>
        private void ConsoleAimTest(Terminal.ConsoleEventArgs args)
        {
            StartCoroutine(AimTest());
        }

        private IEnumerator AimTest()
        {
            var results = new StringBuilder();
            results.AppendLine("{");
            results.AppendLine("  \"cases\": [");
            var cases = new[] { new[] { 0f, 40f }, new[] { 90f, 40f }, new[] { 180f, 20f }, new[] { 270f, 55f } };
            var lines = new System.Collections.Generic.List<string>();

            foreach (var c in cases)
            {
                float yaw = c[0], pitch = c[1];
                var want = Quaternion.Euler(pitch, yaw, 0f) * Vector3.forward;
                if (!TryAim(yaw, pitch))
                {
                    lines.Add($"    {{ \"yaw\": {JsonNumber(yaw)}, \"error\": \"aim call failed\" }}");
                    continue;
                }

                yield return null;                       // let LateUpdate run once
                var immediate = AngleFrom(want);
                yield return new WaitForSeconds(1.0f);   // ...and let the game fight back
                var settled = AngleFrom(want);

                lines.Add($"    {{ \"yaw\": {JsonNumber(yaw)}, \"pitch\": {JsonNumber(pitch)}, "
                          + $"\"err_immediate_deg\": {JsonNumberOrNull(immediate)}, "
                          + $"\"err_after_1s_deg\": {JsonNumberOrNull(settled)} }}");
                Logger.LogInfo($"aimtest yaw={yaw} pitch={pitch} "
                               + $"immediate={immediate:0.##} after1s={settled:0.##}");
            }

            results.AppendLine(string.Join(",\n", lines));
            results.AppendLine("  ]");
            results.AppendLine("}");
            WriteJson("comfy-camera-proof-aimtest.json", results.ToString());
            Announce("aimtest written to comfy-camera-proof-aimtest.json");
        }

        /// <summary>
        /// Where the sun and the moon actually are, per forced time of day.
        ///
        /// The night-sky planner needs three numbers a screenshot cannot give it
        /// cleanly: the bearing and altitude of the body lighting the sky, and how
        /// big its disc is. Fitting a circle to the moon's limb in a captured frame
        /// does work -- it gave azimuth 75, altitude 67 and an angular radius of 44
        /// degrees at t=0.90 -- but that limb is cut by trees and by the ring
        /// feature, and a fit over those is a fit over noise. EnvMan already knows.
        ///
        /// Three things get written, because the first alone is not enough:
        ///   1. the directional light's vector. The body is at -forward. Colour and
        ///      intensity come too, so it is possible to tell whether the light is
        ///      tracking the sun or the moon at a given hour rather than assuming.
        ///   2. every EnvMan field naming a sun, a moon or a phase, with its value.
        ///      If a runtime phase field exists it can be set for a shot the way
        ///      m_debugTime is, without touching the save. If it does not, phase is
        ///      whatever the world's day gives us, and gets recorded rather than
        ///      chosen. Only Get*/Is* methods are invoked -- a zero-argument method
        ///      matching "sun" could just as easily be UpdateSunLight().
        ///   3. any renderer in the sky hierarchy with its bounds and its distance
        ///      from the sky camera, which is the one source of the disc's angular
        ///      radius that is not a curve fit.
        ///
        /// Reads only, and puts the operator's time back when it is done.
        /// </summary>
        private void ConsoleSky(Terminal.ConsoleEventArgs args)
        {
            if (_stillJobRunning)
            {
                Announce("busy: a capture job is already running");
                return;
            }
            var times = new System.Collections.Generic.List<float>();
            for (var i = 1; i < args.Length; i++)
            {
                foreach (var part in (args[i] ?? "").Split(','))
                {
                    if (float.TryParse(part, NumberStyles.Float,
                                       CultureInfo.InvariantCulture, out var t))
                    {
                        times.Add(Mathf.Clamp01(t));
                    }
                }
            }
            if (times.Count == 0)
            {
                // The night band at 0.02, wrapping through midnight, plus the
                // daylight side -- so the dump can be checked against the golden
                // and dawn frames that already exist rather than only trusted.
                for (var k = 30; k <= 50; k++) times.Add(k / 50f);   // 0.60 .. 1.00
                for (var k = 0; k <= 20; k++) times.Add(k / 50f);    // 0.00 .. 0.40
            }
            StartCoroutine(SkyDumpRoutine(times));
        }

        private IEnumerator SkyDumpRoutine(System.Collections.Generic.List<float> times)
        {
            _stillJobRunning = true;
            Announce($"sky dump: {times.Count} time(s)");
            var samples = new System.Collections.Generic.List<string>();
            foreach (var t in times)
            {
                SetDebugTime(t);
                // EnvMan smooths toward a forced time rather than snapping to it, so
                // a reading taken on the next frame is a reading of the transition.
                // Sample twice and publish both: if they disagree it has not settled,
                // and that is a fact about the dump rather than about the sky.
                yield return new WaitForSeconds(1.0f);
                var settling = ReadSky();
                yield return new WaitForSeconds(0.5f);
                var settled = ReadSky();
                samples.Add("    { \"time_of_day\": " + JsonNumber(t)
                            + ", \"settling\": " + settling
                            + ", \"settled\": " + settled + " }");
            }
            SetDebugTime(null);

            var json = new StringBuilder();
            json.AppendLine("{");
            json.AppendLine($"  \"written_at\": {JsonString(DateTime.Now.ToString("o", CultureInfo.InvariantCulture))},");
            json.AppendLine($"  \"env_fields\": {EnvManSkyFields()},");
            json.AppendLine($"  \"sky_renderers\": {SkyRenderers()},");
            json.AppendLine("  \"samples\": [");
            json.AppendLine(string.Join(",\n", samples.ToArray()));
            json.AppendLine("  ]");
            json.AppendLine("}");
            WriteJson("comfy-camera-proof-sky.json", json.ToString());
            _stillJobRunning = false;
            Announce("sky dump written to comfy-camera-proof-sky.json");
        }

        /// <summary>The directional light right now, as a bearing and an altitude.</summary>
        private string ReadSky()
        {
            var env = EnvMan.instance;
            if (env == null) return "null";
            var light = FindField(typeof(EnvMan), "m_dirLight")?.GetValue(env) as Light;
            if (light == null) return "null";
            var forward = light.transform.forward;
            var body = -forward;              // light travels FROM the body toward us
            var mag = Mathf.Max(body.magnitude, 1e-6f);
            var az = Mathf.Repeat(Mathf.Atan2(body.x, body.z) * Mathf.Rad2Deg, 360f);
            var alt = Mathf.Asin(Mathf.Clamp(body.y / mag, -1f, 1f)) * Mathf.Rad2Deg;
            var c = light.color;
            return "{ \"forward\": " + JsonVector(forward)
                   + ", \"body_azimuth_deg\": " + JsonNumber(az)
                   + ", \"body_altitude_deg\": " + JsonNumber(alt)
                   + ", \"intensity\": " + JsonNumber(light.intensity)
                   + ", \"enabled\": " + JsonBool(light.enabled)
                   + ", \"color\": { \"r\": " + JsonNumber(c.r)
                   + ", \"g\": " + JsonNumber(c.g)
                   + ", \"b\": " + JsonNumber(c.b) + " } }";
        }

        private string EnvManSkyFields()
        {
            var env = EnvMan.instance;
            if (env == null) return "[]";
            var wanted = new Regex("moon|phase|sun", RegexOptions.IgnoreCase);
            var items = new System.Collections.Generic.List<string>();
            var flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance;
            for (var type = typeof(EnvMan); type != null && type != typeof(MonoBehaviour);
                 type = type.BaseType)
            {
                foreach (var fi in type.GetFields(flags))
                {
                    if (!wanted.IsMatch(fi.Name)) continue;
                    var field = fi;
                    items.Add("    { \"kind\": \"field\", \"name\": " + JsonString(field.Name)
                              + ", \"type\": " + JsonString(field.FieldType.Name)
                              + ", \"value\": " + JsonString(SafeValue(() => field.GetValue(env)))
                              + " }");
                }
                foreach (var mi in type.GetMethods(flags))
                {
                    // Get*/Is* only. A zero-argument method matching "sun" is as
                    // likely to be UpdateSunLight() as GetSunDirection(), and a dump
                    // that mutates the thing it is measuring is not a dump.
                    if (!wanted.IsMatch(mi.Name)) continue;
                    if (mi.GetParameters().Length != 0) continue;
                    if (!mi.Name.StartsWith("Get") && !mi.Name.StartsWith("Is")) continue;
                    var method = mi;
                    items.Add("    { \"kind\": \"method\", \"name\": " + JsonString(method.Name)
                              + ", \"type\": " + JsonString(method.ReturnType.Name)
                              + ", \"value\": " + JsonString(SafeValue(() => method.Invoke(env, null)))
                              + " }");
                }
            }
            return items.Count == 0 ? "[]" : "[\n" + string.Join(",\n", items.ToArray()) + "\n  ]";
        }

        private string SkyRenderers()
        {
            var items = new System.Collections.Generic.List<string>();
            try
            {
                var cam = GameCamera.instance;
                var sky = cam == null
                    ? null
                    : FindField(typeof(GameCamera), "m_skyCamera")?.GetValue(cam) as Camera;
                if (sky != null)
                {
                    var origin = sky.transform.position;
                    foreach (var r in sky.transform.root.GetComponentsInChildren<Renderer>(true))
                    {
                        var b = r.bounds;
                        items.Add("    { \"path\": " + JsonString(PathOf(r.transform))
                                  + ", \"enabled\": " + JsonBool(r.enabled)
                                  + ", \"lossy_scale\": " + JsonVector(r.transform.lossyScale)
                                  + ", \"extents\": " + JsonVector(b.extents)
                                  + ", \"center\": " + JsonVector(b.center)
                                  + ", \"distance_from_sky_cam\": "
                                  + JsonNumber(Vector3.Distance(origin, b.center)) + " }");
                    }
                }
            }
            catch (Exception ex)
            {
                items.Add("    { \"error\": " + JsonString(ex.Message) + " }");
            }
            return items.Count == 0 ? "[]" : "[\n" + string.Join(",\n", items.ToArray()) + "\n  ]";
        }

        private static string PathOf(Transform t)
        {
            var sb = new StringBuilder(t.name);
            for (var p = t.parent; p != null; p = p.parent) sb.Insert(0, p.name + "/");
            return sb.ToString();
        }

        private static string SafeValue(Func<object> get)
        {
            try
            {
                var v = get();
                if (v == null) return "null";
                if (v is Vector3) { var q = (Vector3)v; return $"({JsonNumber(q.x)}, {JsonNumber(q.y)}, {JsonNumber(q.z)})"; }
                if (v is float) return ((float)v).ToString("0.#####", CultureInfo.InvariantCulture);
                var f = v as IFormattable;
                return f != null ? f.ToString(null, CultureInfo.InvariantCulture) : v.ToString();
            }
            catch (Exception ex)
            {
                return "<" + ex.GetType().Name + ">";
            }
        }

        private static float? AngleFrom(Vector3 want)
        {
            var fwd = CameraForward();
            return fwd.HasValue ? Vector3.Angle(fwd.Value, want) : (float?)null;
        }

        private void ConsoleCaptureHere(Terminal.ConsoleEventArgs args)
        {
            if (_stillJobRunning)
            {
                Logger.LogWarning("Capture job is already running.");
                return;
            }

            var variantSet = args.Length >= 2 ? args[1] : "basic";
            StartCoroutine(CaptureHere(variantSet));
        }

        private void ConsoleEnv(Terminal.ConsoleEventArgs args)
        {
            var name = args.Length >= 2 ? args[1] : "";
            if (string.IsNullOrWhiteSpace(name) || name.Equals("noforce", StringComparison.OrdinalIgnoreCase) || name.Equals("clearforce", StringComparison.OrdinalIgnoreCase))
            {
                SetForcedEnvironment("");
                WriteJson("comfy-camera-proof-env.json", "{\n  \"forced_environment\": null\n}\n");
                return;
            }

            SetForcedEnvironment(name);
            WriteJson("comfy-camera-proof-env.json", "{\n  \"forced_environment\": " + JsonString(name) + "\n}\n");
        }

        private void ConsoleTime(Terminal.ConsoleEventArgs args)
        {
            if (args.Length < 2 || args[1].Equals("off", StringComparison.OrdinalIgnoreCase))
            {
                SetDebugTime(null);
                WriteJson("comfy-camera-proof-time.json", "{\n  \"debug_time\": null\n}\n");
                return;
            }

            if (!args.TryParameterFloat(1, out var time))
            {
                WriteJson("comfy-camera-proof-time.json", "{\n  \"ok\": false,\n  \"error\": \"Usage: comfyproof_time 0.0..1.0 or comfyproof_time off\"\n}\n");
                return;
            }

            time = Mathf.Clamp01(time);
            SetDebugTime(time);
            WriteJson("comfy-camera-proof-time.json", "{\n  \"debug_time\": " + JsonNumber(time) + "\n}\n");
        }

        private void ConsoleHidePlayer(Terminal.ConsoleEventArgs args)
        {
            var on = args.Length < 2 || !args[1].Equals("off", StringComparison.OrdinalIgnoreCase);
            _hidePlayerForScreenshots = on;
            SetLocalPlayerVisible(!on);
            WriteJson("comfy-camera-proof-hideplayer.json", "{\n  \"hide_player_for_screenshots\": " + JsonBool(on) + "\n}\n");
        }

        private void ConsoleEnvList(Terminal.ConsoleEventArgs args)
        {
            WriteEnvironmentNames();
        }

        /// <summary>
        /// The four names this project shoots -- Clear, Misty, Rain, ThunderStorm -- were
        /// picked by hand, and comfy-camera-proof-envs.json had never been written once in
        /// 4,536 receipts, so nobody has ever seen the list they were picked from. Writing
        /// it at the top of every plan run costs a reflection walk and settles the question
        /// permanently: whatever storms this build of the game has, they are named here.
        /// </summary>
        private void WriteEnvironmentNames()
        {
            var names = GetEnvironmentNames();
            var json = new StringBuilder();
            json.AppendLine("{");
            json.AppendLine("  \"environments\": [");
            for (var i = 0; i < names.Count; i++)
            {
                json.Append("    ");
                json.Append(JsonString(names[i]));
                json.AppendLine(i == names.Count - 1 ? "" : ",");
            }
            json.AppendLine("  ]");
            json.AppendLine("}");
            WriteJson("comfy-camera-proof-envs.json", json.ToString());
            Logger.LogInfo($"Wrote {names.Count} environment names.");
        }

        private void WriteStatusProof(string reason)
        {
            var player = GetLocalPlayer();
            var position = player == null ? (Vector3?)null : ((Component)player).transform.position;
            var json = new StringBuilder();
            json.AppendLine("{");
            json.AppendLine($"  \"reason\": {JsonString(reason)},");
            json.AppendLine($"  \"plugin_loaded\": true,");
            json.AppendLine($"  \"player_present\": {JsonBool(player != null)},");
            json.AppendLine($"  \"waypoints_path\": {JsonString(WaypointsPath)},");
            json.AppendLine($"  \"waypoints_exists\": {JsonBool(File.Exists(WaypointsPath))},");
            json.AppendLine($"  \"position\": {(position.HasValue ? JsonVector(position.Value) : "null")}");
            json.AppendLine("}");
            WriteJson("comfy-camera-proof-status.json", json.ToString());
            Logger.LogInfo("Comfy Camera Proof status file written.");
        }

        private object GetLocalPlayer()
        {
            var playerType = FindType("Player");
            return playerType?.GetField("m_localPlayer", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static)?.GetValue(null);
        }

        private bool TryTeleport(object player, Vector3 target)
        {
            try
            {
                var type = player.GetType();
                var method = type.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)
                    .FirstOrDefault(m => m.Name == "TeleportTo" && m.GetParameters().Length == 3);
                if (method != null)
                {
                    var result = method.Invoke(player, new object[] { target, Quaternion.identity, true });
                    if (result is bool ok && ok)
                    {
                        return true;
                    }
                }

                ((Component)player).transform.position = target;
                return true;
            }
            catch (Exception ex)
            {
                Logger.LogError($"Teleport proof failed: {ex}");
                return false;
            }
        }

        /// <summary>
        /// Point the camera. GameCamera follows the local player's look direction, so
        /// aiming means writing the player's yaw and pitch rather than touching the
        /// camera transform — anything written straight onto the camera is overwritten
        /// on its next LateUpdate.
        ///
        /// yaw is degrees clockwise from +Z, pitch is positive looking DOWN (Unity's
        /// x-euler convention), matching what plan_shots.py emits.
        /// </summary>
        private bool TryAim(float yawDeg, float pitchDeg)
        {
            var player = GetLocalPlayer();
            if (player == null)
            {
                return false;
            }

            try
            {
                var type = player.GetType();
                var flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance;

                // m_lookYaw is a Quaternion (heading only); m_lookPitch is degrees.
                var yawField = type.GetField("m_lookYaw", flags);
                var pitchField = type.GetField("m_lookPitch", flags);
                if (yawField == null || pitchField == null)
                {
                    Logger.LogError("Aim failed: m_lookYaw/m_lookPitch not found on Player.");
                    return false;
                }

                yawField.SetValue(player, Quaternion.Euler(0f, yawDeg, 0f));
                pitchField.SetValue(player, pitchDeg);

                // The body should face the same way, or the character turns side-on in
                // frame and the camera pivots around a shoulder instead of the eye.
                ((Component)player).transform.rotation = Quaternion.Euler(0f, yawDeg, 0f);
                return true;
            }
            catch (Exception ex)
            {
                Logger.LogError($"Aim failed: {ex}");
                return false;
            }
        }

        /// <summary>Where the camera actually ended up pointing, for verification.</summary>
        private static Vector3? CameraForward()
        {
            var cam = Camera.main;
            return cam == null ? (Vector3?)null : cam.transform.forward;
        }

        private bool TryResolveGroundHeight(float x, float z, out float? height)
        {
            height = null;
            try
            {
                if (ZoneSystem.instance == null)
                {
                    return false;
                }

                if (ZoneSystem.instance.GetGroundHeight(new Vector3(x, 0f, z), out var groundHeight))
                {
                    height = groundHeight;
                    return true;
                }
            }
            catch (Exception ex)
            {
                Logger.LogWarning($"Ground-height proof failed: {ex.Message}");
            }
            return false;
        }

        private static Type FindType(string name)
        {
            return AppDomain.CurrentDomain.GetAssemblies()
                .Select(a => a.GetType(name, false))
                .FirstOrDefault(t => t != null);
        }

        private Waypoint LoadFirstWaypoint()
        {
            var waypoints = LoadWaypoints();
            return waypoints.Count > 0 ? waypoints[0] : null;
        }

        private System.Collections.Generic.List<Waypoint> LoadWaypoints()
        {
            var waypoints = new System.Collections.Generic.List<Waypoint>();
            if (!File.Exists(WaypointsPath))
            {
                return waypoints;
            }

            var text = File.ReadAllText(WaypointsPath);
            var matches = Regex.Matches(text, "\\{[^{}]*\"rank\"\\s*:\\s*(\\d+)[^{}]*\"x\"\\s*:\\s*(-?\\d+(?:\\.\\d+)?)[^{}]*\"z\"\\s*:\\s*(-?\\d+(?:\\.\\d+)?)[^{}]*(?:\"y\"\\s*:\\s*(-?\\d+(?:\\.\\d+)?|null))?[^{}]*\\}");
            foreach (Match match in matches)
            {
                // Read y with its own regex rather than the optional group above: the
                // greedy [^{}]* ahead of that group swallows the field, so it never
                // captures once anything follows "z" in the object.
                float? y = null;
                var yMatch = Regex.Match(match.Value, "\"y\"\\s*:\\s*(-?\\d+(?:\\.\\d+)?|null)");
                if (yMatch.Success && yMatch.Groups[1].Value != "null")
                {
                    y = float.Parse(yMatch.Groups[1].Value, CultureInfo.InvariantCulture);
                }
                var waypoint = new Waypoint
                {
                    Rank = int.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture),
                    X = float.Parse(match.Groups[2].Value, CultureInfo.InvariantCulture),
                    Z = float.Parse(match.Groups[3].Value, CultureInfo.InvariantCulture),
                    Y = y
                };

                // Optional shot-list detail, read from the same object body.
                var pieces = Regex.Match(match.Value, "\"pieces\"\\s*:\\s*(\\d+)");
                if (pieces.Success)
                {
                    waypoint.Pieces = int.Parse(pieces.Groups[1].Value, CultureInfo.InvariantCulture);
                }
                var height = Regex.Match(match.Value, "\"height_m\"\\s*:\\s*(-?\\d+(?:\\.\\d+)?)");
                if (height.Success)
                {
                    waypoint.HeightM = float.Parse(height.Groups[1].Value, CultureInfo.InvariantCulture);
                }

                waypoints.Add(waypoint);
            }

            return waypoints.OrderBy(w => w.Rank).ToList();
        }

        private IEnumerator CaptureStills(int limit, float settleSeconds)
        {
            _stillJobRunning = true;
            var outDir = Path.Combine(ConfigDir, "comfy-gallery-proof");
            Directory.CreateDirectory(outDir);

            var waypoints = LoadWaypoints();
            if (limit > 0)
            {
                waypoints = waypoints.Take(limit).ToList();
            }

            var manifest = new StringBuilder();
            manifest.AppendLine("{");
            manifest.AppendLine($"  \"started_at\": {JsonString(DateTime.Now.ToString("o", CultureInfo.InvariantCulture))},");
            manifest.AppendLine($"  \"settle_seconds\": {JsonNumber(settleSeconds)},");
            var items = new System.Collections.Generic.List<string>();

            for (var i = 0; i < waypoints.Count; i++)
            {
                var waypoint = waypoints[i];
                var player = GetLocalPlayer();
                if (player == null)
                {
                    Logger.LogError("Still capture stopped: Player.m_localPlayer not present.");
                    break;
                }

                var target = new Vector3(waypoint.X, waypoint.Y ?? 80f, waypoint.Z);
                if (!waypoint.Y.HasValue && TryResolveGroundHeight(waypoint.X, waypoint.Z, out var ground) && ground.HasValue)
                {
                    target.y = ground.Value + 55f;
                }

                PlacePlayer(player, target);
                yield return WaitForStablePlayer(target, 15f);
                yield return new WaitForSeconds(settleSeconds);

                player = GetLocalPlayer();
                if (player == null)
                {
                    Logger.LogError($"Still capture stopped before waypoint #{waypoint.Rank}: Player.m_localPlayer not present.");
                    break;
                }

                var fileName = $"{waypoint.Rank:00}_waypoint.png";
                var path = Path.Combine(outDir, fileName);
                if (_hidePlayerForScreenshots)
                {
                    SetLocalPlayerVisible(false);
                }
                SetCaptureChromeHidden(true);
                yield return null;
                ScreenCapture.CaptureScreenshot(path);
                Logger.LogInfo($"Captured still for waypoint #{waypoint.Rank}: {path}");
                yield return new WaitForSeconds(1f);
                SetCaptureChromeHidden(false);

                items.Add($"    {{ \"rank\": {waypoint.Rank}, \"x\": {JsonNumber(waypoint.X)}, \"y\": {JsonNumber(target.y)}, \"z\": {JsonNumber(waypoint.Z)}, \"still\": {JsonString(fileName)} }}");
            }

            manifest.AppendLine($"  \"count\": {items.Count},");
            manifest.AppendLine("  \"items\": [");
            manifest.AppendLine(string.Join(",\n", items));
            manifest.AppendLine("  ]");
            manifest.AppendLine("}");
            File.WriteAllText(Path.Combine(outDir, "gallery-proof.json"), manifest.ToString(), Encoding.UTF8);
            _stillJobRunning = false;
            Logger.LogInfo($"Still capture job finished. Output: {outDir}");
        }

        private IEnumerator CaptureVariantStills(int limit, float settleSeconds, string variantSet)
        {
            _stillJobRunning = true;
            var outDir = Path.Combine(ConfigDir, "comfy-gallery-proof");
            Directory.CreateDirectory(outDir);

            var waypoints = LoadWaypoints();
            if (limit > 0)
            {
                waypoints = waypoints.Take(limit).ToList();
            }

            var variants = GetVariants(variantSet);
            var items = new System.Collections.Generic.List<string>();

            for (var i = 0; i < waypoints.Count; i++)
            {
                var waypoint = waypoints[i];
                var player = GetLocalPlayer();
                if (player == null)
                {
                    Logger.LogError("Variant still capture stopped: Player.m_localPlayer not present.");
                    break;
                }

                var target = new Vector3(waypoint.X, waypoint.Y ?? 80f, waypoint.Z);
                if (!waypoint.Y.HasValue && TryResolveGroundHeight(waypoint.X, waypoint.Z, out var ground) && ground.HasValue)
                {
                    target.y = ground.Value + 55f;
                }

                PlacePlayer(player, target);
                yield return WaitForStablePlayer(target, 15f);
                yield return new WaitForSeconds(settleSeconds);

                // Hide once per waypoint, not once per mood, so the player never
                // reappears during the settle between variants.
                if (_hidePlayerForScreenshots)
                {
                    SetLocalPlayerVisible(false);
                }
                SetCaptureChromeHidden(true);

                foreach (var variant in variants)
                {
                    player = GetLocalPlayer();
                    if (player == null)
                    {
                        Logger.LogError($"Variant still capture stopped before waypoint #{waypoint.Rank}: Player.m_localPlayer not present.");
                        break;
                    }

                    SetForcedEnvironment(variant.Environment);
                    SetDebugTime(variant.TimeOfDay);
                    yield return new WaitForSeconds(Mathf.Max(2f, settleSeconds / 3f));

                    var fileName = $"{waypoint.Rank:00}_{variant.Slug}.png";
                    var path = Path.Combine(outDir, fileName);
                    ScreenCapture.CaptureScreenshot(path);
                    Logger.LogInfo($"Captured {variant.Slug} still for waypoint #{waypoint.Rank}: {path}");
                    yield return new WaitForSeconds(1f);

                    items.Add($"    {{ \"rank\": {waypoint.Rank}, \"variant\": {JsonString(variant.Slug)}, \"environment\": {JsonString(variant.Environment)}, \"timeOfDay\": {JsonNumber(variant.TimeOfDay)}, \"x\": {JsonNumber(waypoint.X)}, \"y\": {JsonNumber(target.y)}, \"z\": {JsonNumber(waypoint.Z)}, \"still\": {JsonString(fileName)} }}");
                }
            }

            SetForcedEnvironment("");
            SetDebugTime(null);
            SetCaptureChromeHidden(false);
            SetLocalPlayerVisible(!_hidePlayerForScreenshots);

            var manifest = new StringBuilder();
            manifest.AppendLine("{");
            manifest.AppendLine($"  \"started_at\": {JsonString(DateTime.Now.ToString("o", CultureInfo.InvariantCulture))},");
            manifest.AppendLine($"  \"settle_seconds\": {JsonNumber(settleSeconds)},");
            manifest.AppendLine($"  \"variant_set\": {JsonString(variantSet)},");
            manifest.AppendLine($"  \"count\": {items.Count},");
            manifest.AppendLine("  \"items\": [");
            manifest.AppendLine(string.Join(",\n", items));
            manifest.AppendLine("  ]");
            manifest.AppendLine("}");
            File.WriteAllText(Path.Combine(outDir, "gallery-variants-proof.json"), manifest.ToString(), Encoding.UTF8);
            _stillJobRunning = false;
            Logger.LogInfo($"Variant still capture job finished. Output: {outDir}");
        }

        private IEnumerator CaptureHere(string variantSet)
        {
            _stillJobRunning = true;
            var outRoot = Path.Combine(ConfigDir, "comfy-manual-captures");
            var runId = DateTime.Now.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture);
            var outDir = Path.Combine(outRoot, runId);
            Directory.CreateDirectory(outDir);

            var player = GetLocalPlayer();
            var position = player == null ? Vector3.zero : ((Component)player).transform.position;
            var variants = GetVariants(variantSet);
            var items = new System.Collections.Generic.List<string>();

            // Hide once for the whole run. Toggling per shot made the player flicker
            // back into view during the settle between moods.
            if (_hidePlayerForScreenshots)
            {
                SetLocalPlayerVisible(false);
            }
            SetCaptureChromeHidden(true);
            yield return null;   // let the hide land before the first shot

            var settle = Mathf.Max(1f, _settleSeconds.Value);
            var shot = 0;
            foreach (var variant in variants)
            {
                SetForcedEnvironment(variant.Environment);
                SetDebugTime(variant.TimeOfDay);
                yield return new WaitForSeconds(settle);

                var fileName = $"{variant.Slug}.png";
                var path = Path.Combine(outDir, fileName);
                ScreenCapture.CaptureScreenshot(path);
                shot++;
                Logger.LogInfo($"Captured {shot}/{variants.Count} {variant.Slug}: {path}");
                yield return new WaitForSeconds(1f);

                items.Add($"    {{ \"variant\": {JsonString(variant.Slug)}, \"environment\": {JsonString(variant.Environment)}, \"timeOfDay\": {JsonNumber(variant.TimeOfDay)}, \"still\": {JsonString(fileName)} }}");
            }

            SetForcedEnvironment("");
            SetDebugTime(null);
            SetCaptureChromeHidden(false);
            // Restore to the standing hideplayer preference, not unconditionally visible.
            SetLocalPlayerVisible(!_hidePlayerForScreenshots);

            var manifest = new StringBuilder();
            manifest.AppendLine("{");
            manifest.AppendLine($"  \"run_id\": {JsonString(runId)},");
            manifest.AppendLine($"  \"variant_set\": {JsonString(variantSet)},");
            manifest.AppendLine($"  \"position\": {JsonVector(position)},");
            manifest.AppendLine($"  \"count\": {items.Count},");
            manifest.AppendLine("  \"items\": [");
            manifest.AppendLine(string.Join(",\n", items));
            manifest.AppendLine("  ]");
            manifest.AppendLine("}");
            File.WriteAllText(Path.Combine(outDir, "capture.json"), manifest.ToString(), Encoding.UTF8);
            _stillJobRunning = false;
            Logger.LogInfo($"Manual capture finished. Output: {outDir}");
        }

        // -------------------------------------------------------------------------
        // Light. Hold the builders' own fires lit for the length of a shot.
        //
        // Read out of assembly_valheim 0.221.12 with ilspycmd, not off the field
        // names: the annotation layer has been inverted before, and believing it cost
        // ComfyQuestLab two rounds of watching a gallery fall down.
        //
        //   IsBurning() = !m_blocked && state == 1 && !underwater
        //                 && (fuel > 0f || m_infiniteFuel)
        //
        // and UpdateFireplace's drain sits behind `IsBurning() && !m_infiniteFuel`.
        // So m_infiniteFuel is honest, and it alone makes a fire burn at fuel zero.
        //
        // Why this is needed at all: GetTimeSinceLastUpdate() reads s_lastTime and
        // burns off every second that passed while the zone was unloaded. A capture
        // run opens a disposable copy of a world nobody has walked in for months, so
        // the first UpdateFireplace tick takes every hearth, brazier and groundtorch
        // in it straight to zero. Every twilight and night frame in the corpus so far
        // was shot with the builders' lighting switched off, and the runbook's own
        // conclusion is that the lighting is the thing twilight exists to show.
        //
        // Wet is a SECOND mechanism and m_disableCoverCheck does not gate it.
        // CheckWet() runs off its own InvokeRepeating("CheckEnv", 4, 4) and, when
        // EnvMan.IsWet(), swaps m_enabledObjectHigh for m_enabledObjectLow and toggles
        // off anything with m_canTurnOff. That is the storm case exactly: the one
        // condition that puts the lights out before you photograph them. Cancelling
        // CheckEnv and clearing m_wet is what holds a fire at full strength in a
        // ThunderStorm. m_disableCoverCheck only clears m_blocked, which is the
        // buried-under-terrain and no-headroom test.
        //
        // m_infiniteFuel, m_disableCoverCheck, m_wet and m_blocked are plain instance
        // fields -- not synced, nothing written to the world. Only fuel and state are
        // ZDO-backed, and both are put back exactly as they were found.
        // -------------------------------------------------------------------------

        private sealed class HeldFire
        {
            public Fireplace Fire;
            public ZDO Zdo;
            public bool InfiniteFuel;
            public bool DisableCoverCheck;
            public float Fuel;
            public int State;
            public bool FuelWritten;
            public bool StateWritten;
        }

        private sealed class HeldLod
        {
            public LightLod Lod;
            public float LightDistance;
            public float ShadowDistance;
        }

        private readonly System.Collections.Generic.List<HeldFire> _heldFires =
            new System.Collections.Generic.List<HeldFire>();
        private readonly System.Collections.Generic.List<HeldLod> _heldLods =
            new System.Collections.Generic.List<HeldLod>();
        private int _lightLimitWas = int.MinValue;
        private int _shadowLimitWas = int.MinValue;

        // What the last sweep found, for the receipt. A build's light count has been
        // the missing targeting signal for the twilight lane, and the scan cannot
        // produce it: scan_features.py's fire vocabulary was written from the craftable
        // build menu and misses Candle_resin, the MountainKit braziers and the CastleKit
        // groundtorches, ~200k placements between them. The camera is standing in the
        // room. It does not need a vocabulary, it can count the components, and counting
        // them costs nothing on top of lighting them.
        private int _firesFound;
        private int _firesWereBurning;
        private int _firesWereWet;
        private int _firesLit;
        private int _firesUnowned;
        private int _lodsWidened;

        private void HoldFiresLit(Vector3 center, float radius, float lodDistance)
        {
            ReleaseHeldLight();
            _firesFound = _firesWereBurning = _firesWereWet = _firesLit = 0;
            _firesUnowned = _lodsWidened = 0;

            var wetField = FindField(typeof(Fireplace), "m_wet");
            var blockedField = FindField(typeof(Fireplace), "m_blocked");
            var updateState = typeof(Fireplace).GetMethod("UpdateState",
                BindingFlags.NonPublic | BindingFlags.Instance);
            var r2 = radius * radius;

            foreach (var fire in UnityEngine.Object.FindObjectsByType<Fireplace>(FindObjectsSortMode.None))
            {
                if (fire == null) continue;
                if ((fire.transform.position - center).sqrMagnitude > r2) continue;
                var view = fire.GetComponent<ZNetView>();
                var zdo = view == null || !view.IsValid() ? null : view.GetZDO();
                if (zdo == null) continue;

                try
                {
                    _firesFound++;
                    if (fire.IsBurning()) _firesWereBurning++;
                    else _firesLit++;
                    if (wetField != null && (bool)wetField.GetValue(fire)) _firesWereWet++;

                    var held = new HeldFire
                    {
                        Fire = fire,
                        Zdo = zdo,
                        InfiniteFuel = fire.m_infiniteFuel,
                        DisableCoverCheck = fire.m_disableCoverCheck,
                        Fuel = zdo.GetFloat(ZDOVars.s_fuel, fire.m_startFuel),
                        State = zdo.GetInt(ZDOVars.s_state, 1)
                    };

                    fire.m_infiniteFuel = true;
                    fire.m_disableCoverCheck = true;
                    if (blockedField != null) blockedField.SetValue(fire, false);

                    // CheckEnv re-wets on a 4 s timer. Without cancelling it the low
                    // flame comes back between the sweep and the shutter.
                    fire.CancelInvoke("CheckEnv");
                    if (wetField != null) wetField.SetValue(fire, false);

                    // fuel also drives the wood-pile visuals (m_full/m_half/m_emptyObject),
                    // so a fire burning on m_infiniteFuel alone still photographs as an
                    // empty pit with flames in it. Written straight to the ZDO rather than
                    // through the public SetFuel, which routes via RPC_SetFuelAmount and
                    // plays m_fuelAddedEffects: a puff and a sound on every fire at once,
                    // in frame.
                    //
                    // Only the ZDO's owner may write it. That is the whole multiplayer
                    // contract, and it is the line between "this is local rendering" and
                    // "this edits somebody's world". The four fields above stay safe
                    // either way: IsBurning() reads m_infiniteFuel directly, so an
                    // unowned fire still renders lit in this client and is untouched
                    // everywhere else. Only these two writes need the guard. A capture
                    // run is single-player against a disposable copy and owns everything
                    // in it, so this should never fire -- which is why the count is
                    // recorded rather than assumed away.
                    if (view.IsOwner())
                    {
                        if (held.Fuel < fire.m_maxFuel)
                        {
                            zdo.Set(ZDOVars.s_fuel, fire.m_maxFuel);
                            held.FuelWritten = true;
                        }
                        if (held.State != 1)
                        {
                            zdo.Set(ZDOVars.s_state, 1);
                            held.StateWritten = true;
                        }
                    }
                    else
                    {
                        _firesUnowned++;
                    }

                    if (updateState != null) updateState.Invoke(fire, null);
                    _heldFires.Add(held);
                }
                catch (Exception ex)
                {
                    Logger.LogWarning($"Could not hold a fireplace lit: {ex.Message}");
                }
            }

            if (lodDistance > 0f) WidenLightLod(center, radius, lodDistance);
            Logger.LogInfo($"  fires: found {_firesFound}, burning {_firesWereBurning}, "
                           + $"wet {_firesWereWet}, lit {_firesLit}"
                           + (_firesUnowned > 0 ? $", {_firesUnowned} not ours (fuel left alone)" : "")
                           + $"; light lods {_lodsWidened}");
        }

        /// <summary>
        /// A held fire is only worth the sweep if its light reaches the lens. LightLod
        /// culls both the light and its shadow by distance -- 40 m and 20 m by default,
        /// against orbits planned out to 120 m -- and LightLod.m_lightLimit is a static
        /// cap on how many lights may be on at once regardless of distance, which is the
        /// one that bites a hall with thirty braziers in it. The UpdateLoop coroutine
        /// re-reads both every second, so raising them lands well inside settle.
        /// </summary>
        private void WidenLightLod(Vector3 center, float radius, float distance)
        {
            _lightLimitWas = LightLod.m_lightLimit;
            _shadowLimitWas = LightLod.m_shadowLimit;
            LightLod.m_lightLimit = -1;
            LightLod.m_shadowLimit = -1;

            var r2 = radius * radius;
            foreach (var lod in UnityEngine.Object.FindObjectsByType<LightLod>(FindObjectsSortMode.None))
            {
                if (lod == null) continue;
                if ((lod.transform.position - center).sqrMagnitude > r2) continue;
                if (lod.m_lightDistance >= distance && lod.m_shadowDistance >= distance) continue;
                _heldLods.Add(new HeldLod
                {
                    Lod = lod,
                    LightDistance = lod.m_lightDistance,
                    ShadowDistance = lod.m_shadowDistance
                });
                lod.m_lightDistance = Mathf.Max(lod.m_lightDistance, distance);
                lod.m_shadowDistance = Mathf.Max(lod.m_shadowDistance, distance);
                _lodsWidened++;
            }
        }

        private void ReleaseHeldLight()
        {
            var wetField = FindField(typeof(Fireplace), "m_wet");
            foreach (var held in _heldFires)
            {
                try
                {
                    if (held.Fire == null) continue;
                    held.Fire.m_infiniteFuel = held.InfiniteFuel;
                    held.Fire.m_disableCoverCheck = held.DisableCoverCheck;
                    if (held.Zdo != null)
                    {
                        if (held.FuelWritten) held.Zdo.Set(ZDOVars.s_fuel, held.Fuel);
                        if (held.StateWritten) held.Zdo.Set(ZDOVars.s_state, held.State);
                    }
                    // Put the wet check back on its own timer rather than leaving the fire
                    // permanently dry for whoever loads this world next.
                    held.Fire.CancelInvoke("CheckEnv");
                    held.Fire.InvokeRepeating("CheckEnv", 0f, 4f);
                    if (wetField != null) wetField.SetValue(held.Fire, false);
                }
                catch (Exception)
                {
                    // A fire whose zone unloaded mid-run is not worth a warning per zone.
                }
            }
            _heldFires.Clear();

            foreach (var held in _heldLods)
            {
                if (held.Lod == null) continue;
                held.Lod.m_lightDistance = held.LightDistance;
                held.Lod.m_shadowDistance = held.ShadowDistance;
            }
            _heldLods.Clear();

            if (_lightLimitWas != int.MinValue) LightLod.m_lightLimit = _lightLimitWas;
            if (_shadowLimitWas != int.MinValue) LightLod.m_shadowLimit = _shadowLimitWas;
            _lightLimitWas = _shadowLimitWas = int.MinValue;
        }

        /// <summary>
        /// Fire one of the game's own lightning flashes on a bearing we choose, and hold
        /// it long enough to photograph.
        ///
        /// Thunder.DoFlash() is private and picks its bearing at random, so this does the
        /// same work against the same public m_flashEffect: place the effect at
        /// m_flashAltitude on a chosen bearing, then rotate every Light it carries to face
        /// back at the subject. That rotation is the whole reason a strike lights the
        /// scene instead of only the sky, and it is why a driven flash can be a key light
        /// rather than a lucky one.
        ///
        /// The hold is the deliberate part, and the part to be plain about. LightFlicker
        /// ramps in over m_fadeInDuration, holds, then decays across the last
        /// m_fadeDuration of m_ttl and destroys itself. A real strike is shorter than the
        /// shutter is reliable at 4K, so the spawned flicker is re-timed to a flat hold
        /// and the frame is taken inside it. The light is the game's; the exposure is
        /// ours, and the receipt records both the bearing and the hold.
        ///
        /// Thunder rides the environment's m_psystems, which EnvMan switches off for a
        /// player InShelter when the setup is m_psystemsOutsideOnly, so indoors there may
        /// be no live Thunder at all. FindObjectsOfTypeAll reaches the inactive one for
        /// its EffectList, which is all this needs.
        /// </summary>
        private string DriveFlash(Vector3 subject, Vector3 camera, float bearingOffsetDeg, float hold)
        {
            try
            {
                Thunder thunder = null;
                foreach (var t in Resources.FindObjectsOfTypeAll<Thunder>())
                {
                    if (t != null && t.m_flashEffect != null) { thunder = t; break; }
                }
                if (thunder == null) return "no_thunder";

                var toSubject = subject - camera;
                toSubject.y = 0f;
                if (toSubject.sqrMagnitude < 0.001f) toSubject = Vector3.forward;
                var baseYaw = Mathf.Atan2(toSubject.x, toSubject.z) * Mathf.Rad2Deg;
                var yaw = (baseYaw + bearingOffsetDeg) * Mathf.Deg2Rad;

                // Near end of the game's own envelope: far enough to read as sky, close
                // enough that the falloff still lands on the subject.
                var dist = Mathf.Lerp(thunder.m_flashDistanceMin, thunder.m_flashDistanceMax, 0.3f);
                var pos = subject + new Vector3(Mathf.Sin(yaw), 0f, Mathf.Cos(yaw)) * dist;
                pos.y += thunder.m_flashAltitude;
                var rotation = Quaternion.LookRotation((subject - pos).normalized);

                var spawned = thunder.m_flashEffect.Create(pos, Quaternion.identity);
                if (spawned == null || spawned.Length == 0) return "no_effect";

                var lit = 0;
                foreach (var obj in spawned)
                {
                    if (obj == null) continue;
                    foreach (var light in obj.GetComponentsInChildren<Light>())
                    {
                        light.transform.rotation = rotation;
                        lit++;
                    }
                    foreach (var flicker in obj.GetComponentsInChildren<LightFlicker>())
                    {
                        flicker.m_fadeInDuration = 0f;
                        flicker.m_fadeDuration = Mathf.Min(0.15f, hold * 0.25f);
                        flicker.m_ttl = hold;
                    }
                }
                if (lit == 0) return "sky_only";
                return Settings.ReduceFlashingLights ? "reduced_flashing" : "ok";
            }
            catch (Exception ex)
            {
                Logger.LogWarning($"Could not drive a flash: {ex.Message}");
                return "error";
            }
        }

        private void SetForcedEnvironment(string name)
        {
            if (EnvMan.instance == null)
            {
                Logger.LogWarning("Cannot force environment: EnvMan.instance is null.");
                return;
            }
            EnvMan.instance.SetForceEnvironment(name ?? "");
        }

        private static void PlacePlayer(object player, Vector3 target)
        {
            var component = (Component)player;
            component.transform.position = target;
            var body = component.GetComponent<Rigidbody>();
            if (body != null)
            {
                body.position = target;
                body.velocity = Vector3.zero;
            }
        }

        private bool _hudWasAlreadyHidden;
        private bool _cursorWasVisible;

        /// <summary>
        /// Hide everything that is not the world: HUD, crosshair, and mouse cursor.
        /// Restores whatever the player had before — pressing Ctrl+F3 yourself first
        /// still leaves the HUD off afterwards.
        /// </summary>
        private void SetCaptureChromeHidden(bool hide)
        {
            try
            {
                var hud = Hud.instance;
                if (hud != null)
                {
                    var hidden = typeof(Hud).GetField("m_userHidden",
                        BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                    if (hidden != null)
                    {
                        if (hide)
                        {
                            _hudWasAlreadyHidden = (bool)hidden.GetValue(hud);
                            hidden.SetValue(hud, true);
                        }
                        else
                        {
                            hidden.SetValue(hud, _hudWasAlreadyHidden);
                        }
                    }

                    // The crosshair is drawn outside the HUD's own hide toggle on some builds.
                    SetHudMemberActive(hud, "m_crosshair", !hide);
                    SetHudMemberActive(hud, "m_crosshairBow", !hide);
                }

                if (hide)
                {
                    _cursorWasVisible = Cursor.visible;
                    Cursor.visible = false;
                }
                else
                {
                    Cursor.visible = _cursorWasVisible;
                }
            }
            catch (Exception ex)
            {
                Logger.LogWarning($"Could not toggle capture chrome: {ex.Message}");
            }
        }

        private static void SetHudMemberActive(Hud hud, string fieldName, bool active)
        {
            var field = typeof(Hud).GetField(fieldName,
                BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
            var value = field?.GetValue(hud);
            if (value is GameObject go)
            {
                go.SetActive(active);
            }
            else if (value is Component component)
            {
                component.gameObject.SetActive(active);
            }
        }

        private void SetLocalPlayerVisible(bool visible)
        {
            var player = GetLocalPlayer();
            if (player == null)
            {
                return;
            }

            var component = (Component)player;
            foreach (var renderer in component.GetComponentsInChildren<Renderer>(true))
            {
                renderer.enabled = visible;
            }
        }

        private IEnumerator WaitForStablePlayer(Vector3 target, float timeoutSeconds)
        {
            var start = Time.time;
            var stableFor = 0f;
            var lastPosition = new Vector3(float.NaN, float.NaN, float.NaN);

            while (Time.time - start < timeoutSeconds)
            {
                var player = GetLocalPlayer();
                if (player == null)
                {
                    stableFor = 0f;
                    yield return null;
                    continue;
                }

                var position = ((Component)player).transform.position;
                var nearTarget = Vector3.Distance(position, target) <= 15f;
                var stable = !float.IsNaN(lastPosition.x) && Vector3.Distance(position, lastPosition) <= 0.1f;
                if (nearTarget && stable)
                {
                    stableFor += Time.deltaTime;
                    if (stableFor >= 1.5f)
                    {
                        yield break;
                    }
                }
                else
                {
                    stableFor = 0f;
                }

                lastPosition = position;
                yield return null;
            }

            Logger.LogWarning("Timed out waiting for stable player position; continuing with settle delay.");
        }

        private void SetDebugTime(float? timeOfDay)
        {
            if (EnvMan.instance == null)
            {
                Logger.LogWarning("Cannot force time: EnvMan.instance is null.");
                return;
            }

            var type = typeof(EnvMan);
            type.GetField("m_debugTimeOfDay", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)?.SetValue(EnvMan.instance, timeOfDay.HasValue);
            type.GetField("m_debugTime", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)?.SetValue(EnvMan.instance, timeOfDay.GetValueOrDefault());
        }

        private System.Collections.Generic.List<string> GetEnvironmentNames()
        {
            var names = new System.Collections.Generic.List<string>();
            if (EnvMan.instance == null)
            {
                return names;
            }

            var field = typeof(EnvMan).GetField("m_environments", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
            if (!(field?.GetValue(EnvMan.instance) is System.Collections.IEnumerable envs))
            {
                return names;
            }

            foreach (var env in envs)
            {
                var nameField = env.GetType().GetField("m_name", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance);
                var name = nameField?.GetValue(env) as string;
                if (!string.IsNullOrWhiteSpace(name))
                {
                    names.Add(name);
                }
            }
            return names.Distinct().OrderBy(n => n).ToList();
        }

        /// <summary>
        /// Time-of-day values are constrained to the band that actually produces a
        /// usable frame. Measured over 34 captures of the old presets: 0.25 came back
        /// too dark 88% of the time and 0.90 was unusable in 33 of 34 shots, so half of
        /// every session was being thrown away. Nothing below 0.33 or above 0.77 here.
        /// Steps are deliberately denser toward dusk, where the best shots land.
        /// </summary>
        private static System.Collections.Generic.List<Variant> GetVariants(string variantSet)
        {
            if (variantSet.Equals("weather", StringComparison.OrdinalIgnoreCase))
            {
                return new System.Collections.Generic.List<Variant>
                {
                    new Variant("w01_clear_mid",    "Clear",        0.50f),
                    new Variant("w02_clear_dusk",   "Clear",        0.71f),
                    new Variant("w03_misty_morn",   "Misty",        0.40f),
                    new Variant("w04_misty_dusk",   "Misty",        0.69f),
                    new Variant("w05_rain_mid",     "Rain",         0.52f),
                    new Variant("w06_rain_dusk",    "Rain",         0.70f),
                    new Variant("w07_storm_mid",    "ThunderStorm", 0.55f),
                    new Variant("w08_storm_dusk",   "ThunderStorm", 0.68f),
                    new Variant("w09_clear_gold",   "Clear",        0.66f),
                    new Variant("w10_misty_gold",   "Misty",        0.64f),
                    new Variant("w11_clear_late",   "Clear",        0.745f),
                    new Variant("w12_clear_last",   "Clear",        0.77f)
                };
            }

            if (variantSet.Equals("quick", StringComparison.OrdinalIgnoreCase))
            {
                return new System.Collections.Generic.List<Variant>
                {
                    new Variant("t38_morning", "Clear", 0.38f),
                    new Variant("t50_noon",    "Clear", 0.50f),
                    new Variant("t65_gold",    "Clear", 0.65f),
                    new Variant("t72_dusk",    "Clear", 0.72f)
                };
            }

            // basic — the everything set. Getting here costs a flight and a framing;
            // another dozen frames costs seconds, so shoot the whole matrix. Grouped by
            // environment so EnvMan only crossfades weather three times per run.
            //
            // Revision 2, tuned against measured output rather than assumption:
            //   - 0.77 dropped: came back at luminance 25, as dead as the old 0.90.
            //     The dusk cliff is steep — 0.70 is 82, 0.74 is 49, 0.77 is 25.
            //   - 0.26/0.29/0.32 added: 0.33 measured 135 (bright daylight) while the
            //     old 0.25 measured 36 (dead), so sunrise is somewhere in between and
            //     the morning golden hour was never sampled at all. These three are
            //     deliberately a probe; if they come back dead we have found the dawn
            //     edge, which is worth as much as a good frame.
            //   - misty cut 4 -> 2: fog runs bright but flat (luminance ~190, contrast
            //     ~70), so the midday ones were paying for themselves in brightness and
            //     not in image.
            return new System.Collections.Generic.List<Variant>
            {
                // clear — sampled by how fast the light moves, not evenly by clock.
                // Measured per-pixel change between consecutive frames over 9 runs:
                // the two transitions run 3-4x faster than the middle of the day
                // (t29->t32 = 48, t67->t70 = 39, against 11-19 across the plateau),
                // yet every step used to get the same resolution. So the ramps are
                // dense and the flat part is sparse. 0.35 and 0.38 were the two
                // smallest deltas in the whole set and are gone; 0.26 is gone because
                // it lands before sunrise (highlights only 131 — dim, not moody).
                new Variant("a_clear_t29",  "Clear", 0.29f),
                new Variant("a_clear_t30",  "Clear", 0.30f),
                new Variant("a_clear_t31",  "Clear", 0.31f),
                new Variant("a_clear_t32",  "Clear", 0.32f),
                new Variant("a_clear_t44",  "Clear", 0.44f),
                new Variant("a_clear_t50",  "Clear", 0.50f),
                new Variant("a_clear_t56",  "Clear", 0.56f),
                new Variant("a_clear_t61",  "Clear", 0.61f),
                new Variant("a_clear_t64",  "Clear", 0.64f),
                new Variant("a_clear_t67",  "Clear", 0.67f),
                new Variant("a_clear_t68",  "Clear", 0.68f),
                new Variant("a_clear_t69",  "Clear", 0.69f),
                new Variant("a_clear_t70",  "Clear", 0.70f),
                new Variant("a_clear_t72",  "Clear", 0.72f),
                new Variant("a_clear_t74",  "Clear", 0.74f),

                // misty — kept only at low sun, where the flatness reads as depth
                new Variant("b_misty_t40",  "Misty", 0.40f),
                new Variant("b_misty_t66",  "Misty", 0.66f),

                // rain — wet stone takes torchlight, which is where the good shots came from
                new Variant("c_rain_t45",   "Rain", 0.45f),
                new Variant("c_rain_t58",   "Rain", 0.58f),
                new Variant("c_rain_t68",   "Rain", 0.68f),
                new Variant("c_rain_t72",   "Rain", 0.72f),

                // storm — dark, so keep it near midday where there is light to work with
                new Variant("d_storm_t50",  "ThunderStorm", 0.50f),
                new Variant("d_storm_t58",  "ThunderStorm", 0.58f),
                new Variant("d_storm_t66",  "ThunderStorm", 0.66f)
            };
        }

        private bool TryWaypointFromArgs(Terminal.ConsoleEventArgs args, out Waypoint waypoint)
        {
            waypoint = null;
            if (args == null || args.Length < 4)
            {
                return false;
            }

            if (!args.TryParameterFloat(1, out var x) ||
                !args.TryParameterFloat(2, out var y) ||
                !args.TryParameterFloat(3, out var z))
            {
                return false;
            }

            waypoint = new Waypoint { Rank = 0, X = x, Y = y, Z = z };
            return true;
        }

        private void WriteJson(string fileName, string json)
        {
            Directory.CreateDirectory(ConfigDir);
            File.WriteAllText(Path.Combine(ConfigDir, fileName), json, Encoding.UTF8);
        }

        private static string JsonString(string value) => "\"" + (value ?? "").Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
        private static string JsonBool(bool value) => value ? "true" : "false";
        private static string JsonNumber(float value) => value.ToString("0.###", CultureInfo.InvariantCulture);
        private static string JsonNumberOrNull(float? value) => value.HasValue ? JsonNumber(value.Value) : "null";
        private static string JsonVector(Vector3 value) => $"{{ \"x\": {JsonNumber(value.x)}, \"y\": {JsonNumber(value.y)}, \"z\": {JsonNumber(value.z)} }}";

        private sealed class Waypoint
        {
            public int Rank;
            public float X;
            public float Z;
            public float? Y;
            public int Pieces;
            public float HeightM;
        }

        private sealed class Variant
        {
            public readonly string Slug;
            public readonly string Environment;
            public readonly float TimeOfDay;

            public Variant(string slug, string environment, float timeOfDay)
            {
                Slug = slug;
                Environment = environment;
                TimeOfDay = timeOfDay;
            }
        }
    }
}
