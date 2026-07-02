namespace Comfy.ControlSurface.Patches;

using System;
using System.Reflection;

using HarmonyLib;

using UnityEngine;

using Comfy.ControlSurface.Core;

/// <summary>
/// While the control-surface panel is open: release the mouse cursor so the panel is
/// clickable, and stop the local player from taking input so clicking the panel does
/// not swing a weapon. Patched manually with guards — if a game update renames either
/// method, the plugin still loads and the panel falls back to the Tab-menu workaround.
/// </summary>
public static class PanelInputPatches {
  public static void Apply(Harmony harmony) {
    TryPatch(
        harmony,
        AccessTools.Method(typeof(GameCamera), "UpdateMouseCapture"),
        nameof(UpdateMouseCapturePostfix),
        "GameCamera.UpdateMouseCapture");

    TryPatch(
        harmony,
        AccessTools.Method(typeof(Character), "TakeInput"),
        nameof(TakeInputPostfix),
        "Character.TakeInput");
  }

  static void TryPatch(Harmony harmony, MethodBase target, string postfixName, string label) {
    try {
      if (target == null) {
        throw new InvalidOperationException("method not found");
      }

      harmony.Patch(target, postfix: new HarmonyMethod(typeof(PanelInputPatches), postfixName));
      StartupStatus.AppendStartupTrace("panel_input_patch", ok: true, label);
    } catch (Exception ex) {
      StartupStatus.AppendStartupTrace("panel_input_patch", ok: false, $"{label}: {ex.Message}");
      ComfyControlSurface.LogWarning(
          $"Could not patch {label} ({ex.Message}). The panel still works: open your "
          + "inventory (Tab) while the panel is up to free the cursor.");
    }
  }

  static void UpdateMouseCapturePostfix() {
    if (ControlSurfacePanel.IsOpen) {
      Cursor.lockState = CursorLockMode.None;
      Cursor.visible = true;
    }
  }

  static void TakeInputPostfix(Character __instance, ref bool __result) {
    if (ControlSurfacePanel.IsOpen && __instance == Player.m_localPlayer) {
      __result = false;
    }
  }
}
