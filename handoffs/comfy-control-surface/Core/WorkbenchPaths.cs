namespace Comfy.ControlSurface.Core;

using System;
using System.IO;

public static class WorkbenchPaths {
  public static string Root { get; private set; }
  public static string ActionsFile { get; private set; }
  public static string OutboxDir { get; private set; }
  public static string EvidenceDir { get; private set; }
  public static string TracesDir { get; private set; }
  public static string StatusDir { get; private set; }
  public static string ReceiptsDir { get; private set; }
  public static string FailedDir { get; private set; }

  public static void Initialize(string configRoot, string overrideRoot) {
    Root =
        !string.IsNullOrWhiteSpace(overrideRoot)
            ? Path.GetFullPath(overrideRoot)
            : Path.Combine(configRoot ?? PathsFallback(), "comfy-control");

    ActionsFile = Path.Combine(Root, "actions.json");
    OutboxDir = Path.Combine(Root, "outbox");
    EvidenceDir = Path.Combine(Root, "evidence");
    TracesDir = Path.Combine(Root, "traces");
    StatusDir = Path.Combine(Root, "status");
    ReceiptsDir = Path.Combine(Root, "receipts");
    FailedDir = Path.Combine(Root, "failed");

    EnsureDirectories();
  }

  public static void EnsureDirectories() {
    Directory.CreateDirectory(Root);
    Directory.CreateDirectory(OutboxDir);
    Directory.CreateDirectory(EvidenceDir);
    Directory.CreateDirectory(TracesDir);
    Directory.CreateDirectory(StatusDir);
    Directory.CreateDirectory(ReceiptsDir);
    Directory.CreateDirectory(FailedDir);
  }

  static string PathsFallback() {
    return Path.Combine(Environment.CurrentDirectory, "BepInEx", "config");
  }
}
