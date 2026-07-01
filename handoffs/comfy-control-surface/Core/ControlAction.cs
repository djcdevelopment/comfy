namespace Comfy.ControlSurface.Core;

public sealed class ControlAction {
  public string ActionId { get; set; }
  public string Label { get; set; }
  public string Description { get; set; }
  public string SubmissionType { get; set; }
  public string WorkflowGuild { get; set; }
  public string WorkflowEra { get; set; }
  public string WorkflowSource { get; set; }
  public string WorkflowCategory { get; set; }
  public string WorkflowRank { get; set; }
  public string WorkflowTier { get; set; }
  public string WorkflowCommandTemplate { get; set; }
  public bool RequiresScreenshot { get; set; }
  public bool RequiresTarget { get; set; }
  public string BridgeKind { get; set; }
  public string BridgeOutDir { get; set; }
}
