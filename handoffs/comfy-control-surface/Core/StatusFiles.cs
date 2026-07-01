namespace Comfy.ControlSurface.Core;

using System;
using System.IO;

public static class StatusFiles {
  public static void WriteLastSubmission(string submissionId, string traceId, string payloadPath) {
    string json =
        "{\n"
        + $"  \"created_at_utc\": {JsonText.Utc(DateTime.UtcNow)},\n"
        + $"  \"submission_id\": {JsonText.String(submissionId)},\n"
        + $"  \"trace_id\": {JsonText.String(traceId)},\n"
        + $"  \"payload\": {JsonText.String(payloadPath)}\n"
        + "}\n";

    AtomicFile.WriteAllText(Path.Combine(WorkbenchPaths.StatusDir, "last-submission.json"), json);
  }

  public static void WriteLastError(string step, string error, string traceId) {
    string json =
        "{\n"
        + $"  \"created_at_utc\": {JsonText.Utc(DateTime.UtcNow)},\n"
        + $"  \"step\": {JsonText.String(step)},\n"
        + $"  \"error\": {JsonText.String(error)},\n"
        + $"  \"trace_id\": {JsonText.NullableString(traceId)}\n"
        + "}\n";

    AtomicFile.WriteAllText(Path.Combine(WorkbenchPaths.StatusDir, "last-error.json"), json);
  }
}
