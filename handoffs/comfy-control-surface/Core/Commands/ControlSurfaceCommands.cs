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
      Commands.Add(new Terminal.ConsoleCommand("comfy_quest_reload", "reload BepInEx/config/comfy-control/quest-view.json", ReloadQuestView));
      Commands.Add(new Terminal.ConsoleCommand("comfy_quest_submit", "capture proof for a tracked quest: comfy_quest_submit <quest_id>", SubmitQuest));
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

  static object SubmitQuest(Terminal.ConsoleEventArgs args) {
    if (QuestViewLoader.Quests.Count == 0) {
      QuestViewLoader.LoadQuestView();
    }

    if (args.Length < 2) {
      PlayerStatus.Show("Usage: comfy_quest_submit <quest_id>");
      return false;
    }

    string questId = args[1];
    foreach (TrackedQuest quest in QuestViewLoader.Quests) {
      if (string.Equals(quest.QuestId, questId, System.StringComparison.OrdinalIgnoreCase)) {
        if (!quest.IsCapturable) {
          PlayerStatus.Show($"Quest {quest.Name} is not capturable in-game.");
          return false;
        }

        SubmissionService.Submit(quest.ToAction());
        return true;
      }
    }

    PlayerStatus.Show($"Unknown quest_id: {questId} (check the Quest Log)");
    return false;
  }

  static object ReloadQuestView(Terminal.ConsoleEventArgs args) {
    bool ok = QuestViewLoader.LoadQuestView();
    string message =
        ok
            ? $"Quest view reloaded: {QuestViewLoader.Quests.Count} tracked quest(s)."
            : $"Quest view reload failed: {QuestViewLoader.LastError}";
    PlayerStatus.Show(message);
    return ok;
  }
}
