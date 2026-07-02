namespace Comfy.ControlSurface.Core;

using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

public static class QuestViewLoader {
  static readonly Regex SchemaVersionRegex = new("\"schema_version\"\\s*:\\s*(\\d+)", RegexOptions.CultureInvariant);
  static readonly Regex QuestsArrayRegex = new("\"quests\"\\s*:\\s*\\[(.*)\\]", RegexOptions.CultureInvariant | RegexOptions.Singleline);

  public static IReadOnlyList<TrackedQuest> Quests { get; private set; } = Array.Empty<TrackedQuest>();
  public static string PlayerName { get; private set; }
  public static string LastError { get; private set; }
  public static bool FileExists => File.Exists(WorkbenchPaths.QuestViewFile);

  public static bool LoadQuestView() {
    WorkbenchPaths.EnsureDirectories();

    try {
      if (!File.Exists(WorkbenchPaths.QuestViewFile)) {
        Quests = Array.Empty<TrackedQuest>();
        PlayerName = null;
        LastError = null;
        WriteQuestViewStatus(ok: true, error: null, present: false);
        return true;
      }

      string json = File.ReadAllText(WorkbenchPaths.QuestViewFile, Encoding.UTF8);
      List<TrackedQuest> quests = ParseQuests(json, out string playerName);

      Quests = quests;
      PlayerName = playerName;
      LastError = null;

      WriteQuestViewStatus(ok: true, error: null, present: true);
      StartupStatus.AppendStartupTrace("quest_view_loaded", ok: true, $"loaded {quests.Count} tracked quest(s)");
      return true;
    } catch (Exception ex) {
      Quests = Array.Empty<TrackedQuest>();
      PlayerName = null;
      LastError = ex.Message;

      WriteQuestViewStatus(ok: false, error: ex.Message, present: true);
      StartupStatus.AppendStartupTrace("quest_view_loaded", ok: false, ex.Message);
      ComfyControlSurface.LogError($"Failed to load quest view: {ex.Message}");
      return false;
    }
  }

  static List<TrackedQuest> ParseQuests(string json, out string playerName) {
    Match schema = SchemaVersionRegex.Match(json);
    if (!schema.Success || schema.Groups[1].Value != "1") {
      throw new InvalidOperationException("quest-view.json schema_version must be 1.");
    }

    playerName = ActionDefinitionLoader.ReadString(json, "name");

    Match questsArray = QuestsArrayRegex.Match(json);
    if (!questsArray.Success) {
      throw new InvalidOperationException("quest-view.json must contain a quests array.");
    }

    List<TrackedQuest> quests = [];

    foreach (string objectText in ActionDefinitionLoader.ExtractObjects(questsArray.Groups[1].Value)) {
      TrackedQuest quest = new() {
        QuestId = ActionDefinitionLoader.ReadString(objectText, "quest_id"),
        Name = ActionDefinitionLoader.ReadString(objectText, "name"),
        Guild = ActionDefinitionLoader.ReadString(objectText, "guild"),
        Era = ActionDefinitionLoader.ReadValue(objectText, "era"),
        Category = ActionDefinitionLoader.ReadString(objectText, "category"),
        Requirements = ActionDefinitionLoader.ReadString(objectText, "requirements"),
        Reward = ActionDefinitionLoader.ReadString(objectText, "reward"),
        EvidenceNote = ActionDefinitionLoader.ReadString(objectText, "evidence_note"),
        BotCommand = ActionDefinitionLoader.ReadString(objectText, "bot_command"),
        Coopable = ActionDefinitionLoader.ReadBool(objectText, "coopable"),
        Screenshots = ParseScreenshots(objectText),
        VideoAlternative = ActionDefinitionLoader.ReadBool(objectText, "video_alternative"),
        LinkRequired = ActionDefinitionLoader.ReadBool(objectText, "link"),
        GroupTurnin = ActionDefinitionLoader.ReadBool(objectText, "group_turnin"),
        AutoChecked = ActionDefinitionLoader.ReadBool(objectText, "auto_checked"),
        Venue = ActionDefinitionLoader.ReadString(objectText, "venue") ?? "in_game",
        TriggerEvent = ActionDefinitionLoader.ReadString(objectText, "event"),
        TriggerTarget = ActionDefinitionLoader.ReadString(objectText, "target"),
        TriggerWeaponSkill = ActionDefinitionLoader.ReadString(objectText, "weapon_skill"),
        TriggerProjectile = ActionDefinitionLoader.ReadBool(objectText, "projectile"),
        TriggerShots = ParseShots(objectText)
      };

      ValidateQuest(quest);
      quests.Add(quest);
    }

    return quests;
  }

  static int ParseScreenshots(string objectText) {
    string value = ActionDefinitionLoader.ReadValue(objectText, "screenshots");
    return int.TryParse(value, out int count) ? count : 0;
  }

  static readonly Regex ShotsArrayRegex =
      new("\"shots\"\\s*:\\s*\\[([^\\]]*)\\]", RegexOptions.CultureInvariant);
  static readonly Regex QuotedStringRegex =
      new("\"((?:\\\\.|[^\"])*)\"", RegexOptions.CultureInvariant);

  static List<string> ParseShots(string objectText) {
    Match match = ShotsArrayRegex.Match(objectText);
    if (!match.Success) {
      return null;
    }

    List<string> shots = [];
    foreach (Match item in QuotedStringRegex.Matches(match.Groups[1].Value)) {
      shots.Add(item.Groups[1].Value);
    }

    return shots.Count > 0 ? shots : null;
  }

  static void ValidateQuest(TrackedQuest quest) {
    if (string.IsNullOrWhiteSpace(quest.QuestId)) {
      throw new InvalidOperationException("A tracked quest is missing quest_id.");
    }

    if (string.IsNullOrWhiteSpace(quest.Name)) {
      throw new InvalidOperationException($"Tracked quest {quest.QuestId} is missing name.");
    }

    if (string.IsNullOrWhiteSpace(quest.Guild)) {
      throw new InvalidOperationException($"Tracked quest {quest.QuestId} is missing guild.");
    }
  }

  static void WriteQuestViewStatus(bool ok, string error, bool present) {
    string path = Path.Combine(WorkbenchPaths.StatusDir, "quest-view-status.json");
    string json =
        "{\n"
        + $"  \"quest_view_present\": {JsonText.Bool(present)},\n"
        + $"  \"quest_view_loaded\": {JsonText.Bool(ok)},\n"
        + $"  \"quest_count\": {Quests.Count},\n"
        + $"  \"player\": {JsonText.NullableString(PlayerName)},\n"
        + $"  \"quest_view_file\": {JsonText.String(WorkbenchPaths.QuestViewFile)},\n"
        + $"  \"error\": {JsonText.NullableString(error)}\n"
        + "}\n";

    AtomicFile.WriteAllText(path, json);

    if (!ok) {
      StatusFiles.WriteLastError("quest_view_loaded", error, traceId: StartupStatus.StartupTraceId);
    }
  }
}
