namespace Comfy.ControlSurface;

using System;
using System.Globalization;
using System.IO;
using System.Reflection;

using BepInEx;
using BepInEx.Logging;

using HarmonyLib;

using Comfy.ControlSurface.Config;
using Comfy.ControlSurface.Core;
using Comfy.ControlSurface.Core.Commands;

[BepInPlugin(PluginGuid, PluginName, PluginVersion)]
public sealed class ComfyControlSurface : BaseUnityPlugin {
  public const string PluginGuid = "comfy.valheim.controlsurface";
  public const string PluginName = "ComfyControlSurface";
  public const string PluginVersion = "0.1.0";

  static ManualLogSource _logger;
  static Harmony _harmony;

  public static ComfyControlSurface Instance { get; private set; }

  void Awake() {
    Instance = this;
    _logger = Logger;

    PluginConfig.BindConfig(Config);

    string configRoot = Path.GetDirectoryName(Config.ConfigFilePath);
    WorkbenchPaths.Initialize(configRoot, PluginConfig.ControlRootOverride.Value);
    SubmissionService.Initialize(this);

    LogInfo("Comfy control surface loaded.");

    StartupStatus.WritePluginLoaded();
    ActionDefinitionLoader.LoadActions();
    ControlSurfaceCommands.ToggleCommands(toggleOn: true);

    _harmony = Harmony.CreateAndPatchAll(Assembly.GetExecutingAssembly(), harmonyInstanceId: PluginGuid);
  }

  void Update() {
    if (PluginConfig.IsModEnabled.Value && PluginConfig.SubmitShortcut.Value.IsDown()) {
      SubmissionService.SubmitDefault();
    }
  }

  void OnDestroy() {
    ControlSurfaceCommands.ToggleCommands(toggleOn: false);
    _harmony?.UnpatchSelf();
  }

  public static void LogInfo(object value) {
    _logger?.LogInfo(WithTimestamp(value));
  }

  public static void LogWarning(object value) {
    _logger?.LogWarning(WithTimestamp(value));
  }

  public static void LogError(object value) {
    _logger?.LogError(WithTimestamp(value));
  }

  static string WithTimestamp(object value) {
    return $"[{DateTime.Now.ToString(DateTimeFormatInfo.InvariantInfo)}] {value}";
  }
}
