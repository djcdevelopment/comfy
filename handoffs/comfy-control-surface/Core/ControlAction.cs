namespace Comfy.ControlSurface.Core;

public sealed class ControlAction {
  public string ActionId { get; set; }
  public string Label { get; set; }
  public string Description { get; set; }
  public string SubmissionType { get; set; }
  public bool RequiresScreenshot { get; set; }
  public bool RequiresTarget { get; set; }
  public string BridgeKind { get; set; }
  public string BridgeOutDir { get; set; }
}
