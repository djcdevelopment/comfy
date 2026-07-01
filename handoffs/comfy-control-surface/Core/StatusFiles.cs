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

  public static void WriteReceipt(ControlAction action, string submissionId, string screenshotPath, string payloadPath) {
    string json =
        "{\n"
        + $"  \"created_at_utc\": {JsonText.Utc(DateTime.UtcNow)},\n"
        + $"  \"submission_id\": {JsonText.String(submissionId)},\n"
        + $"  \"action_id\": {JsonText.String(action.ActionId)},\n"
        + $"  \"submission_type\": {JsonText.String(action.SubmissionType)},\n"
        + "  \"workflow\": {\n"
        + $"    \"guild\": {JsonText.NullableString(action.WorkflowGuild)},\n"
        + $"    \"era\": {JsonText.NullableString(action.WorkflowEra)},\n"
        + $"    \"source\": {JsonText.NullableString(action.WorkflowSource)},\n"
        + $"    \"category\": {JsonText.NullableString(action.WorkflowCategory)},\n"
        + $"    \"rank\": {JsonText.NullableString(action.WorkflowRank)},\n"
        + $"    \"tier\": {JsonText.NullableString(action.WorkflowTier)},\n"
        + $"    \"bot_command_template\": {JsonText.NullableString(action.WorkflowCommandTemplate)}\n"
        + "  },\n"
        + $"  \"payload\": {JsonText.String(payloadPath)},\n"
        + $"  \"screenshot\": {JsonText.NullableString(screenshotPath)},\n"
        + "  \"next_step\": \"Run the bridge consumer and send the generated review/export for human review.\"\n"
        + "}\n";

    AtomicFile.WriteAllText(Path.Combine(WorkbenchPaths.ReceiptsDir, $"{submissionId}.json"), json);
    AtomicFile.WriteAllText(Path.Combine(WorkbenchPaths.StatusDir, "last-receipt.json"), json);
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
