namespace Comfy.ControlSurface.Core.Commands;

using System.Collections.Generic;

using Comfy.ControlSurface.Core;

public static class ControlSurfaceCommands {
  static readonly List<Terminal.ConsoleCommand> Commands = [];

  public static void ToggleCommands(bool toggleOn) {
    Commands.Clear();

    if (toggleOn) {
      Commands.Add(new Terminal.ConsoleCommand("comfy_submit", "submit a Comfy control-surface action: comfy_submit [action_id]", Submit));
      Commands.Add(new Terminal.ConsoleCommand("comfy_control_status", "write and show Comfy control-surface status", Status));
      Commands.Add(new Terminal.ConsoleCommand("comfy_control_reload", "reload BepInEx/config/comfy-control/actions.json", Reload));
    }
  }

  static object Submit(Terminal.ConsoleEventArgs args) {
    if (args.Length >= 2) {
      SubmissionService.Submit(args[1]);
    } else {
      SubmissionService.SubmitDefault();
    }

    return true;
  }

  static object Status(Terminal.ConsoleEventArgs args) {
    ActionDefinitionLoader.LoadActions();
    string message =
        ActionDefinitionLoader.LastError == null
            ? $"Comfy control loaded {ActionDefinitionLoader.Actions.Count} action(s). Root: {WorkbenchPaths.Root}"
            : $"Comfy control action load failed: {ActionDefinitionLoader.LastError}";

    PlayerStatus.Show(message);
    ComfyControlSurface.LogInfo(message);
    return true;
  }

  static object Reload(Terminal.ConsoleEventArgs args) {
    bool ok = ActionDefinitionLoader.LoadActions();
    string message = ok ? "Comfy control actions reloaded." : $"Comfy control reload failed: {ActionDefinitionLoader.LastError}";
    PlayerStatus.Show(message);
    return ok;
  }
}
