using BepInEx;
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
    [BepInPlugin("com.comfy.camera-proof", "Comfy Camera Proof", "0.1.0")]
    public sealed class Plugin : BaseUnityPlugin
    {
        private string ConfigDir => Paths.ConfigPath;
        private string WaypointsPath => Path.Combine(ConfigDir, "waypoints.json");
        private bool _stillJobRunning;
        private bool _hidePlayerForScreenshots = true;

        private void Awake()
        {
            RegisterConsoleCommands();
            Logger.LogInfo("Comfy Camera Proof loaded. F8/status and F9/move proof commands are available.");
        }

        private void Update()
        {
            if (Input.GetKeyDown(KeyCode.F8))
            {
                WriteStatusProof("hotkey-f8");
            }

            if (Input.GetKeyDown(KeyCode.F9))
            {
                StartCoroutine(TeleportProof(null));
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
                new Terminal.ConsoleCommand("comfyproof_hideplayer", "hide/show local player: comfyproof_hideplayer on|off", ConsoleHidePlayer);
                new Terminal.ConsoleCommand("comfyproof_variantstills", "capture env/time variants: comfyproof_variantstills [limit] [settle] [variantSet]", ConsoleVariantStills);
                new Terminal.ConsoleCommand("comfyproof_capture", "capture variants at current position: comfyproof_capture [variantSet]", ConsoleCaptureHere);
                new Terminal.ConsoleCommand("capture", "capture variants at current position: capture [variantSet]", ConsoleCaptureHere);
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
                float? y = null;
                if (match.Groups[4].Success && match.Groups[4].Value != "null")
                {
                    y = float.Parse(match.Groups[4].Value, CultureInfo.InvariantCulture);
                }
                waypoints.Add(new Waypoint
                {
                    Rank = int.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture),
                    X = float.Parse(match.Groups[2].Value, CultureInfo.InvariantCulture),
                    Z = float.Parse(match.Groups[3].Value, CultureInfo.InvariantCulture),
                    Y = y
                });
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
                SetLocalPlayerVisible(!_hidePlayerForScreenshots);
                ScreenCapture.CaptureScreenshot(path);
                Logger.LogInfo($"Captured still for waypoint #{waypoint.Rank}: {path}");
                yield return new WaitForSeconds(1f);
                SetLocalPlayerVisible(true);

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
                    SetLocalPlayerVisible(!_hidePlayerForScreenshots);
                    ScreenCapture.CaptureScreenshot(path);
                    Logger.LogInfo($"Captured {variant.Slug} still for waypoint #{waypoint.Rank}: {path}");
                    yield return new WaitForSeconds(1f);
                    SetLocalPlayerVisible(true);

                    items.Add($"    {{ \"rank\": {waypoint.Rank}, \"variant\": {JsonString(variant.Slug)}, \"environment\": {JsonString(variant.Environment)}, \"timeOfDay\": {JsonNumber(variant.TimeOfDay)}, \"x\": {JsonNumber(waypoint.X)}, \"y\": {JsonNumber(target.y)}, \"z\": {JsonNumber(waypoint.Z)}, \"still\": {JsonString(fileName)} }}");
                }
            }

            SetForcedEnvironment("");
            SetDebugTime(null);

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

            foreach (var variant in variants)
            {
                SetForcedEnvironment(variant.Environment);
                SetDebugTime(variant.TimeOfDay);
                yield return new WaitForSeconds(3f);

                var fileName = $"{variant.Slug}.png";
                var path = Path.Combine(outDir, fileName);
                SetLocalPlayerVisible(!_hidePlayerForScreenshots);
                ScreenCapture.CaptureScreenshot(path);
                Logger.LogInfo($"Captured manual {variant.Slug} still: {path}");
                yield return new WaitForSeconds(1f);
                SetLocalPlayerVisible(true);

                items.Add($"    {{ \"variant\": {JsonString(variant.Slug)}, \"environment\": {JsonString(variant.Environment)}, \"timeOfDay\": {JsonNumber(variant.TimeOfDay)}, \"still\": {JsonString(fileName)} }}");
            }

            SetForcedEnvironment("");
            SetDebugTime(null);

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

        private static System.Collections.Generic.List<Variant> GetVariants(string variantSet)
        {
            if (variantSet.Equals("weather", StringComparison.OrdinalIgnoreCase))
            {
                return new System.Collections.Generic.List<Variant>
                {
                    new Variant("clear_day", "Clear", 0.50f),
                    new Variant("misty_morning", "Misty", 0.25f),
                    new Variant("rain_day", "Rain", 0.50f),
                    new Variant("storm_night", "ThunderStorm", 0.85f)
                };
            }

            return new System.Collections.Generic.List<Variant>
            {
                new Variant("morning_clear", "Clear", 0.25f),
                new Variant("noon_clear", "Clear", 0.50f),
                new Variant("sunset_clear", "Clear", 0.72f),
                new Variant("night_clear", "Clear", 0.90f)
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
