namespace Comfy.ControlSurface.Core;

public sealed class TrackedQuest {
  public string QuestId { get; set; }
  public string Name { get; set; }
  public string Guild { get; set; }
  public string Era { get; set; }
  public string Category { get; set; }
  public string Requirements { get; set; }
  public string Reward { get; set; }
  public string EvidenceNote { get; set; }
  public string BotCommand { get; set; }
  public bool Coopable { get; set; }
  public int Screenshots { get; set; }
  public bool VideoAlternative { get; set; }
  public bool LinkRequired { get; set; }
  public bool GroupTurnin { get; set; }
  public bool AutoChecked { get; set; }
  public string Venue { get; set; }
  public string TriggerEvent { get; set; }
  public string TriggerTarget { get; set; }
  public string TriggerWeaponSkill { get; set; }
  public bool TriggerProjectile { get; set; }
  public System.Collections.Generic.List<string> TriggerShots { get; set; }

  public bool IsCapturable => !AutoChecked && Venue != "irl";
  public bool HasTrigger => !string.IsNullOrWhiteSpace(TriggerEvent);

  public bool WantsFirstHitShot =>
      TriggerShots != null && TriggerShots.Contains("on_first_hit");

  public ControlAction ToAction() {
    return new ControlAction {
      ActionId = $"quest_{Slug(Guild)}_{QuestId}",
      Label = $"{Guild}: {Name}",
      Description = Requirements,
      SubmissionType = "quest_proof",
      WorkflowGuild = Guild,
      WorkflowEra = Era,
      WorkflowSource = "quest-view.json",
      WorkflowCategory = Category,
      WorkflowRank = null,
      WorkflowTier = null,
      WorkflowCommandTemplate = BotCommand,
      RequiresScreenshot = Screenshots > 0,
      RequiresTarget = false,
      BridgeKind = "file",
      BridgeOutDir = "BepInEx/config/comfy-control/outbox"
    };
  }

  static string Slug(string value) {
    return string.IsNullOrWhiteSpace(value) ? "unknown" : value.ToLowerInvariant().Replace(" ", "_");
  }
}
