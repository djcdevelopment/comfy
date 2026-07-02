namespace Comfy.ControlSurface.Patches;

using System;
using System.Reflection;

using HarmonyLib;

using Comfy.ControlSurface.Core;

/// <summary>
/// Hooks the world-object damage paths that quest triggers listen to. Patched manually
/// with guards — if a game update renames a method, the plugin still loads and the
/// affected trigger falls back to manual capture.
/// </summary>
public static class QuestTriggerPatches {
  public static void Apply(Harmony harmony) {
    TryPatch(harmony, typeof(TreeBase), "Damage", nameof(TreeBaseDamagePostfix), "TreeBase.Damage");
    TryPatch(harmony, typeof(TreeLog), "Damage", nameof(TreeLogDamagePostfix), "TreeLog.Damage");
    TryPatch(harmony, typeof(Destructible), "Damage", nameof(DestructibleDamagePostfix), "Destructible.Damage");
    TryPatch(harmony, typeof(Character), "RPC_Damage", nameof(CharacterRpcDamagePostfix), "Character.RPC_Damage");
  }

  static void TryPatch(Harmony harmony, Type targetType, string methodName, string postfixName, string label) {
    try {
      MethodBase target = AccessTools.Method(targetType, methodName);
      if (target == null) {
        throw new InvalidOperationException("method not found");
      }

      harmony.Patch(target, postfix: new HarmonyMethod(typeof(QuestTriggerPatches), postfixName));
      StartupStatus.AppendStartupTrace("quest_trigger_patch", ok: true, label);
    } catch (Exception ex) {
      StartupStatus.AppendStartupTrace("quest_trigger_patch", ok: false, $"{label}: {ex.Message}");
      ComfyControlSurface.LogWarning(
          $"Could not patch {label} ({ex.Message}). Quests triggering on it fall back to manual capture.");
    }
  }

  static void TreeBaseDamagePostfix(TreeBase __instance, HitData __0) {
    QuestTriggerService.OnLocalPlayerHit("tree", __instance.name, __0);
  }

  static void TreeLogDamagePostfix(TreeLog __instance, HitData __0) {
    QuestTriggerService.OnLocalPlayerHit("tree", __instance.name, __0);
  }

  static void DestructibleDamagePostfix(Destructible __instance, HitData __0) {
    QuestTriggerService.OnLocalPlayerHit("destructible", __instance.name, __0);
  }

  static void CharacterRpcDamagePostfix(Character __instance, long __0, HitData __1) {
    QuestTriggerService.OnCreatureDamaged(__instance, __1, __instance.IsDead());
  }
}
