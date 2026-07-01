namespace Comfy.ControlSurface.Config;

using BepInEx.Configuration;

using UnityEngine;

public static class PluginConfig {
  public static ConfigEntry<bool> IsModEnabled { get; private set; }
  public static ConfigEntry<KeyboardShortcut> SubmitShortcut { get; private set; }
  public static ConfigEntry<bool> ShowDebugMessages { get; private set; }
  public static ConfigEntry<string> ControlRootOverride { get; private set; }

  public static void BindConfig(ConfigFile config) {
    IsModEnabled =
        config.Bind(
            "_Global",
            "isModEnabled",
            true,
            "Globally enable or disable this mod.");

    SubmitShortcut =
        config.Bind(
            "Input",
            "submitShortcut",
            new KeyboardShortcut(KeyCode.F7),
            "Shortcut that opens the Comfy control-surface panel.");

    ShowDebugMessages =
        config.Bind(
            "Debug",
            "showDebugMessages",
            false,
            "Show extra in-game debug messages for control-surface actions.");

    ControlRootOverride =
        config.Bind(
            "Debug",
            "controlRootOverride",
            "",
            "Optional absolute override for the comfy-control workbench root. Leave empty for BepInEx/config/comfy-control.");
  }
}
