namespace Comfy.ControlSurface.Core;

using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

public static class ActionDefinitionLoader {
  static readonly Regex SchemaVersionRegex = new("\"schema_version\"\\s*:\\s*(\\d+)", RegexOptions.CultureInvariant);
  static readonly Regex ActionsArrayRegex = new("\"actions\"\\s*:\\s*\\[(.*)\\]", RegexOptions.CultureInvariant | RegexOptions.Singleline);
  static readonly Regex FieldRegexTemplate = new("", RegexOptions.CultureInvariant);

  public static IReadOnlyList<ControlAction> Actions { get; private set; } = Array.Empty<ControlAction>();
  public static string LastError { get; private set; }

  public static bool LoadActions() {
    WorkbenchPaths.EnsureDirectories();

    try {
      if (!File.Exists(WorkbenchPaths.ActionsFile)) {
        AtomicFile.WriteAllText(WorkbenchPaths.ActionsFile, DefaultActionsJson());
      }

      string json = File.ReadAllText(WorkbenchPaths.ActionsFile, Encoding.UTF8);
      List<ControlAction> actions = ParseActions(json);

      if (actions.Count == 0) {
        throw new InvalidOperationException("No actions were found in actions.json.");
      }

      Actions = actions;
      LastError = null;

      WriteActionStatus(ok: true, error: null);
      StartupStatus.AppendStartupTrace("actions_loaded", ok: true, $"loaded {actions.Count} action(s)");
      return true;
    } catch (Exception ex) {
      Actions = Array.Empty<ControlAction>();
      LastError = ex.Message;

      WriteActionStatus(ok: false, error: ex.Message);
      StartupStatus.AppendStartupTrace("actions_loaded", ok: false, ex.Message);
      ComfyControlSurface.LogError($"Failed to load actions: {ex.Message}");
      return false;
    }
  }

  public static ControlAction GetDefaultAction() {
    if (Actions.Count == 0) {
      LoadActions();
    }

    return Actions.Count == 1 ? Actions[0] : null;
  }

  public static ControlAction FindAction(string actionId) {
    if (Actions.Count == 0) {
      LoadActions();
    }

    foreach (ControlAction action in Actions) {
      if (string.Equals(action.ActionId, actionId, StringComparison.OrdinalIgnoreCase)) {
        return action;
      }
    }

    return null;
  }

  static List<ControlAction> ParseActions(string json) {
    Match schema = SchemaVersionRegex.Match(json);
    if (!schema.Success || schema.Groups[1].Value != "1") {
      throw new InvalidOperationException("actions.json schema_version must be 1.");
    }

    Match actionsArray = ActionsArrayRegex.Match(json);
    if (!actionsArray.Success) {
      throw new InvalidOperationException("actions.json must contain an actions array.");
    }

    List<ControlAction> actions = [];

    foreach (string objectText in ExtractObjects(actionsArray.Groups[1].Value)) {
      ControlAction action = new() {
        ActionId = ReadString(objectText, "action_id"),
        Label = ReadString(objectText, "label"),
        Description = ReadString(objectText, "description"),
        SubmissionType = ReadString(objectText, "submission_type"),
        WorkflowGuild = ReadString(objectText, "guild"),
        WorkflowEra = ReadValue(objectText, "era"),
        WorkflowSource = ReadString(objectText, "source"),
        WorkflowCategory = ReadString(objectText, "category"),
        WorkflowRank = ReadString(objectText, "rank"),
        WorkflowTier = ReadValue(objectText, "tier"),
        WorkflowCommandTemplate = ReadString(objectText, "bot_command_template"),
        RequiresScreenshot = ReadBool(objectText, "requires_screenshot"),
        RequiresTarget = ReadBool(objectText, "requires_target"),
        BridgeKind = ReadString(objectText, "kind"),
        BridgeOutDir = ReadString(objectText, "out_dir")
      };

      ValidateAction(action);
      actions.Add(action);
    }

    return actions;
  }

  static IEnumerable<string> ExtractObjects(string text) {
    int depth = 0;
    int start = -1;
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < text.Length; i++) {
      char c = text[i];

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (c == '\\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }

        continue;
      }

      if (c == '"') {
        inString = true;
      } else if (c == '{') {
        if (depth == 0) {
          start = i;
        }

        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0 && start >= 0) {
          yield return text.Substring(start, i - start + 1);
          start = -1;
        }
      }
    }
  }

  static string ReadString(string json, string fieldName) {
    Regex regex = new($"\"{Regex.Escape(fieldName)}\"\\s*:\\s*\"((?:\\\\.|[^\"])*)\"", RegexOptions.CultureInvariant);
    Match match = regex.Match(json);
    return match.Success ? UnescapeJson(match.Groups[1].Value) : null;
  }

  static bool ReadBool(string json, string fieldName) {
    Regex regex = new($"\"{Regex.Escape(fieldName)}\"\\s*:\\s*(true|false)", RegexOptions.CultureInvariant | RegexOptions.IgnoreCase);
    Match match = regex.Match(json);
    return match.Success && string.Equals(match.Groups[1].Value, "true", StringComparison.OrdinalIgnoreCase);
  }

  static string ReadValue(string json, string fieldName) {
    Regex regex = new($"\"{Regex.Escape(fieldName)}\"\\s*:\\s*(\"((?:\\\\.|[^\"])*)\"|-?\\d+(?:\\.\\d+)?)", RegexOptions.CultureInvariant);
    Match match = regex.Match(json);
    if (!match.Success) {
      return null;
    }

    return match.Groups[2].Success ? UnescapeJson(match.Groups[2].Value) : match.Groups[1].Value;
  }

  static string UnescapeJson(string value) {
    return value
        .Replace("\\\"", "\"")
        .Replace("\\\\", "\\")
        .Replace("\\n", "\n")
        .Replace("\\r", "\r")
        .Replace("\\t", "\t");
  }

  static void ValidateAction(ControlAction action) {
    if (string.IsNullOrWhiteSpace(action.ActionId)) {
      throw new InvalidOperationException("Action is missing action_id.");
    }

    if (string.IsNullOrWhiteSpace(action.Label)) {
      throw new InvalidOperationException($"Action {action.ActionId} is missing label.");
    }

    if (string.IsNullOrWhiteSpace(action.SubmissionType)) {
      throw new InvalidOperationException($"Action {action.ActionId} is missing submission_type.");
    }

    if (string.Equals(action.SubmissionType, "slayer_rank_proof", StringComparison.OrdinalIgnoreCase)
        && string.IsNullOrWhiteSpace(action.WorkflowRank)) {
      throw new InvalidOperationException($"Action {action.ActionId} is missing workflow.rank.");
    }

    if (!string.Equals(action.BridgeKind, "file", StringComparison.OrdinalIgnoreCase)) {
      throw new InvalidOperationException($"Action {action.ActionId} bridge.kind must be file.");
    }
  }

  static void WriteActionStatus(bool ok, string error) {
    string path = Path.Combine(WorkbenchPaths.StatusDir, "plugin-status.json");
    string json =
        "{\n"
        + $"  \"plugin_loaded\": true,\n"
        + $"  \"actions_loaded\": {JsonText.Bool(ok)},\n"
        + $"  \"action_count\": {Actions.Count},\n"
        + $"  \"actions_file\": {JsonText.String(WorkbenchPaths.ActionsFile)},\n"
        + $"  \"error\": {JsonText.NullableString(error)}\n"
        + "}\n";

    AtomicFile.WriteAllText(path, json);

    if (!ok) {
      StatusFiles.WriteLastError("actions_loaded", error, traceId: StartupStatus.StartupTraceId);
    }
  }

  static string DefaultActionsJson() {
    return
        "{\n"
        + "  \"schema_version\": 1,\n"
        + "  \"actions\": [\n"
        + "    {\n"
        + "      \"action_id\": \"slayer_rank_thrall\",\n"
        + "      \"label\": \"Slayer: Thrall Proof\",\n"
        + "      \"description\": \"Create a local proof submission for Slayer rank Thrall.\",\n"
        + "      \"submission_type\": \"slayer_rank_proof\",\n"
        + "      \"workflow\": {\n"
        + "        \"guild\": \"Slayers\",\n"
        + "        \"era\": 16,\n"
        + "        \"source\": \"Mikers's rank chart (transcribed from flowchart)\",\n"
        + "        \"category\": \"rank_proof\",\n"
        + "        \"rank\": \"Thrall\",\n"
        + "        \"tier\": 1,\n"
        + "        \"bot_command_template\": \"/slayer submit rank:{rank} proof:{proof}\"\n"
        + "      },\n"
        + "      \"requires_screenshot\": true,\n"
        + "      \"requires_target\": false,\n"
        + "      \"bridge\": {\n"
        + "        \"kind\": \"file\",\n"
        + "        \"out_dir\": \"BepInEx/config/comfy-control/outbox\"\n"
        + "      }\n"
        + "    },\n"
        + "    {\n"
        + "      \"action_id\": \"slayer_rank_thegn\",\n"
        + "      \"label\": \"Slayer: Thegn Proof\",\n"
        + "      \"description\": \"Create a local proof submission for Slayer rank Thegn.\",\n"
        + "      \"submission_type\": \"slayer_rank_proof\",\n"
        + "      \"workflow\": {\n"
        + "        \"guild\": \"Slayers\",\n"
        + "        \"era\": 16,\n"
        + "        \"source\": \"Mikers's rank chart (transcribed from flowchart)\",\n"
        + "        \"category\": \"rank_proof\",\n"
        + "        \"rank\": \"Thegn\",\n"
        + "        \"tier\": 2,\n"
        + "        \"bot_command_template\": \"/slayer submit rank:{rank} proof:{proof}\"\n"
        + "      },\n"
        + "      \"requires_screenshot\": true,\n"
        + "      \"requires_target\": false,\n"
        + "      \"bridge\": {\n"
        + "        \"kind\": \"file\",\n"
        + "        \"out_dir\": \"BepInEx/config/comfy-control/outbox\"\n"
        + "      }\n"
        + "    },\n"
        + "    {\n"
        + "      \"action_id\": \"slayer_rank_jarl\",\n"
        + "      \"label\": \"Slayer: Jarl Proof\",\n"
        + "      \"description\": \"Create a local proof submission for Slayer rank Jarl.\",\n"
        + "      \"submission_type\": \"slayer_rank_proof\",\n"
        + "      \"workflow\": {\n"
        + "        \"guild\": \"Slayers\",\n"
        + "        \"era\": 16,\n"
        + "        \"source\": \"Mikers's rank chart (transcribed from flowchart)\",\n"
        + "        \"category\": \"rank_proof\",\n"
        + "        \"rank\": \"Jarl\",\n"
        + "        \"tier\": 3,\n"
        + "        \"bot_command_template\": \"/slayer submit rank:{rank} proof:{proof}\"\n"
        + "      },\n"
        + "      \"requires_screenshot\": true,\n"
        + "      \"requires_target\": false,\n"
        + "      \"bridge\": {\n"
        + "        \"kind\": \"file\",\n"
        + "        \"out_dir\": \"BepInEx/config/comfy-control/outbox\"\n"
        + "      }\n"
        + "    }\n"
        + "  ]\n"
        + "}\n";
  }
}
