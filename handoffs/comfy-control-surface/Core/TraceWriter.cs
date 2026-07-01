namespace Comfy.ControlSurface.Core;

using System;
using System.IO;
using System.Text;

using UnityEngine;

public sealed class TraceWriter {
  readonly string _traceFile;

  public string TraceId { get; }
  public string RelativeTraceFile { get; }

  public TraceWriter(string traceId) {
    TraceId = traceId;
    RelativeTraceFile = $"traces/{traceId}.trace.jsonl";
    _traceFile = Path.Combine(WorkbenchPaths.TracesDir, $"{traceId}.trace.jsonl");
    Directory.CreateDirectory(Path.GetDirectoryName(_traceFile));
  }

  public void Event(string step, bool ok, string detail = null) {
    Append(
        "{"
        + $"\"ts_utc\":{JsonText.Utc(DateTime.UtcNow)},"
        + $"\"trace_id\":{JsonText.String(TraceId)},"
        + $"\"step\":{JsonText.String(step)},"
        + $"\"ok\":{JsonText.Bool(ok)},"
        + $"\"detail\":{JsonText.NullableString(detail)}"
        + "}");
  }

  public void Error(string step, Exception ex) {
    Error(step, ex.Message);
  }

  public void Error(string step, string error) {
    Append(
        "{"
        + $"\"ts_utc\":{JsonText.Utc(DateTime.UtcNow)},"
        + $"\"trace_id\":{JsonText.String(TraceId)},"
        + $"\"step\":{JsonText.String(step)},"
        + "\"ok\":false,"
        + $"\"error\":{JsonText.String(error)}"
        + "}");
  }

  public void Context(Vector3 position, string biome) {
    Append(
        "{"
        + $"\"ts_utc\":{JsonText.Utc(DateTime.UtcNow)},"
        + $"\"trace_id\":{JsonText.String(TraceId)},"
        + "\"step\":\"context_captured\","
        + "\"ok\":true,"
        + $"\"position\":{JsonText.Vector(position)},"
        + $"\"biome\":{JsonText.String(biome)}"
        + "}");
  }

  void Append(string line) {
    File.AppendAllText(_traceFile, line + "\n", Encoding.UTF8);
  }
}
