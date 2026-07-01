namespace Comfy.ControlSurface.Core;

using System;
using System.Collections;
using System.Globalization;
using System.IO;

using UnityEngine;

public static class SubmissionService {
  static ComfyControlSurface _plugin;
  static bool _isSubmitting;

  public static void Initialize(ComfyControlSurface plugin) {
    _plugin = plugin;
  }

  public static void SubmitDefault() {
    ControlAction action = ActionDefinitionLoader.GetDefaultAction();
    if (action == null) {
      string message =
          ActionDefinitionLoader.Actions.Count > 1
              ? "Multiple actions are configured; run comfy_submit <action_id>."
              : $"No action loaded: {ActionDefinitionLoader.LastError ?? "unknown error"}";
      PlayerStatus.Show(message);
      ComfyControlSurface.LogWarning(message);
      return;
    }

    Submit(action.ActionId);
  }

  public static void Submit(string actionId) {
    if (_plugin == null) {
      ComfyControlSurface.LogError("SubmissionService is not initialized.");
      return;
    }

    if (_isSubmitting) {
      PlayerStatus.Show("Submission already running.");
      return;
    }

    ControlAction action = ActionDefinitionLoader.FindAction(actionId);
    if (action == null) {
      string message = $"Unknown action: {actionId}";
      PlayerStatus.Show(message);
      ComfyControlSurface.LogWarning(message);
      return;
    }

    _plugin.StartCoroutine(SubmitCoroutine(action));
  }

  static IEnumerator SubmitCoroutine(ControlAction action) {
    _isSubmitting = true;

    DateTime createdAtUtc = DateTime.UtcNow;
    string runId = createdAtUtc.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture);
    string slug = action.ActionId.Replace("_", "-");
    string suffix = Guid.NewGuid().ToString("N").Substring(0, 4);
    string submissionId = $"{runId}-{slug}-{suffix}";
    TraceWriter trace = new(submissionId);
    GameContext context = null;
    string screenshotRelativePath = null;
    string screenshotPath = null;

    try {
      trace.Event("action_selected", ok: true, action.ActionId);

      context = GameContext.Capture();
      trace.Context(context.Position, context.Biome);

      if (action.RequiresScreenshot) {
        screenshotRelativePath = $"evidence/{submissionId}.png";
        screenshotPath = Path.Combine(WorkbenchPaths.EvidenceDir, $"{submissionId}.png");

        ScreenCapture.CaptureScreenshot(screenshotPath);
      } else {
        trace.Event("screenshot_skipped", ok: true, "action does not require screenshot");
      }
    } catch (Exception ex) {
      HandleFailure(trace, ex);
      _isSubmitting = false;
      yield break;
    }

    if (action.RequiresScreenshot) {
      float deadline = Time.realtimeSinceStartup + 10f;

      while (!File.Exists(screenshotPath) && Time.realtimeSinceStartup < deadline) {
        yield return null;
      }
    }

    try {
      if (action.RequiresScreenshot) {
        if (!File.Exists(screenshotPath)) {
          throw new IOException($"Screenshot was not written: {screenshotPath}");
        }

        trace.Event("screenshot_captured", ok: true, screenshotRelativePath);
      }

      string payload = BuildPayload(action, context, createdAtUtc, runId, submissionId, screenshotRelativePath, trace);
      ValidatePayload(action, context, screenshotRelativePath, trace);
      trace.Event("payload_validated", ok: true, submissionId);

      string payloadPath = Path.Combine(WorkbenchPaths.OutboxDir, $"{submissionId}.json");
      AtomicFile.WriteAllText(payloadPath, payload);
      trace.Event("payload_written", ok: true, $"outbox/{submissionId}.json");

      string relativePayloadPath = $"outbox/{submissionId}.json";
      StatusFiles.WriteLastSubmission(submissionId, trace.TraceId, relativePayloadPath);
      StatusFiles.WriteReceipt(action, submissionId, screenshotRelativePath, relativePayloadPath);

      string message = $"Submission saved: {submissionId}";
      PlayerStatus.Show(message);
      trace.Event("player_status_shown", ok: true, message);
      ComfyControlSurface.LogInfo(message);
    } catch (Exception ex) {
      HandleFailure(trace, ex);
    } finally {
      _isSubmitting = false;
    }
  }

  static void HandleFailure(TraceWriter trace, Exception ex) {
    trace.Error("submission_failed", ex);
    StatusFiles.WriteLastError("submission_failed", ex.Message, trace.TraceId);

    string message = $"Submission failed. Trace: {trace.TraceId}";
    PlayerStatus.Show(message);
    trace.Event("player_status_shown", ok: false, message);
    ComfyControlSurface.LogError($"{message}: {ex.Message}");
  }

  static void ValidatePayload(ControlAction action, GameContext context, string screenshotRelativePath, TraceWriter trace) {
    if (string.IsNullOrWhiteSpace(action.ActionId)) {
      throw new InvalidOperationException("Payload action_id is empty.");
    }

    if (string.IsNullOrWhiteSpace(action.SubmissionType)) {
      throw new InvalidOperationException("Payload submission_type is empty.");
    }

    if (!IsFinite(context.Position.x) || !IsFinite(context.Position.y) || !IsFinite(context.Position.z)) {
      throw new InvalidOperationException("Payload position contains a non-finite value.");
    }

    if (action.RequiresScreenshot && string.IsNullOrWhiteSpace(screenshotRelativePath)) {
      throw new InvalidOperationException("Action requires screenshot but no screenshot path was created.");
    }

    if (string.IsNullOrWhiteSpace(trace.RelativeTraceFile)) {
      throw new InvalidOperationException("Trace file path is empty.");
    }
  }

  static bool IsFinite(float value) {
    return !float.IsNaN(value) && !float.IsInfinity(value);
  }

  static string BuildPayload(
      ControlAction action,
      GameContext context,
      DateTime createdAtUtc,
      string runId,
      string submissionId,
      string screenshotRelativePath,
      TraceWriter trace) {
    return
        "{\n"
        + "  \"schema_version\": 1,\n"
        + $"  \"submission_id\": {JsonText.String(submissionId)},\n"
        + $"  \"run_id\": {JsonText.String(runId)},\n"
        + $"  \"action_id\": {JsonText.String(action.ActionId)},\n"
        + $"  \"submission_type\": {JsonText.String(action.SubmissionType)},\n"
        + $"  \"created_at_utc\": {JsonText.Utc(createdAtUtc)},\n"
        + "  \"status\": \"ready_for_review\",\n"
        + "  \"workflow\": {\n"
        + $"    \"guild\": {JsonText.NullableString(action.WorkflowGuild)},\n"
        + $"    \"era\": {JsonText.NullableString(action.WorkflowEra)},\n"
        + $"    \"source\": {JsonText.NullableString(action.WorkflowSource)},\n"
        + $"    \"category\": {JsonText.NullableString(action.WorkflowCategory)},\n"
        + $"    \"rank\": {JsonText.NullableString(action.WorkflowRank)},\n"
        + $"    \"tier\": {JsonText.NullableString(action.WorkflowTier)},\n"
        + $"    \"bot_command_template\": {JsonText.NullableString(action.WorkflowCommandTemplate)}\n"
        + "  },\n"
        + "  \"player\": {\n"
        + $"    \"name\": {JsonText.String(context.PlayerName)},\n"
        + $"    \"player_id\": {JsonText.NullableString(context.PlayerId)}\n"
        + "  },\n"
        + "  \"world\": {\n"
        + $"    \"name\": {JsonText.NullableString(context.WorldName)},\n"
        + $"    \"seed\": {JsonText.NullableString(context.WorldSeed)}\n"
        + "  },\n"
        + "  \"position\": {\n"
        + $"    \"x\": {JsonText.Number(context.Position.x)},\n"
        + $"    \"y\": {JsonText.Number(context.Position.y)},\n"
        + $"    \"z\": {JsonText.Number(context.Position.z)},\n"
        + $"    \"biome\": {JsonText.String(context.Biome)}\n"
        + "  },\n"
        + "  \"target\": null,\n"
        + "  \"evidence\": {\n"
        + $"    \"screenshot\": {JsonText.NullableString(screenshotRelativePath)}\n"
        + "  },\n"
        + "  \"notes\": \"\",\n"
        + "  \"trace\": {\n"
        + $"    \"trace_id\": {JsonText.String(trace.TraceId)},\n"
        + $"    \"trace_file\": {JsonText.String(trace.RelativeTraceFile)}\n"
        + "  }\n"
        + "}\n";
  }
}
