namespace Comfy.ControlSurface.Core;

using System;
using System.Globalization;
using System.IO;

public static class StartupStatus {
  public static string StartupTraceId { get; private set; }
  static TraceWriter _trace;

  public static void WritePluginLoaded() {
    StartupTraceId = $"plugin-{DateTime.UtcNow.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture)}";
    _trace = new TraceWriter(StartupTraceId);
    _trace.Event("plugin_loaded", ok: true, ComfyControlSurface.PluginVersion);

    string json =
        "{\n"
        + $"  \"plugin_loaded\": true,\n"
        + $"  \"plugin_guid\": {JsonText.String(ComfyControlSurface.PluginGuid)},\n"
        + $"  \"plugin_name\": {JsonText.String(ComfyControlSurface.PluginName)},\n"
        + $"  \"plugin_version\": {JsonText.String(ComfyControlSurface.PluginVersion)},\n"
        + $"  \"loaded_at_utc\": {JsonText.Utc(DateTime.UtcNow)},\n"
        + $"  \"control_root\": {JsonText.String(WorkbenchPaths.Root)},\n"
        + $"  \"trace_id\": {JsonText.String(StartupTraceId)},\n"
        + $"  \"trace_file\": {JsonText.String(_trace.RelativeTraceFile)}\n"
        + "}\n";

    AtomicFile.WriteAllText(Path.Combine(WorkbenchPaths.StatusDir, "plugin-status.json"), json);
  }

  public static void AppendStartupTrace(string step, bool ok, string detail) {
    if (_trace == null) {
      return;
    }

    if (ok) {
      _trace.Event(step, ok: true, detail);
    } else {
      _trace.Error(step, detail);
    }
  }
}
