namespace Comfy.ControlSurface.Core;

using System;
using System.Collections.Generic;

using UnityEngine;

/// <summary>The F7 overlay panel, in the "Ledger" direction from the design pass:
/// dense rows, thin dividers, geometric markers, guild-accented sections.</summary>
public static class ControlSurfacePanel {
  enum PanelView {
    Home,
    Slayers,
    SlayerRankProof,
    QuestLog
  }

  const float ReceiptSeconds = 120f;

  static readonly string[] SlayerRanks = ["Thrall", "Thegn", "Jarl"];

  static bool _isOpen;
  static PanelView _view = PanelView.Home;
  static Rect _window = new(80f, 80f, 420f, 560f);
  static Vector2 _scroll;
  static string _expandedQuestId;

  static bool _stylesReady;
  static GUIStyle _windowStyle, _titleStyle, _headerBtnStyle, _sectionStyle, _nameStyle,
      _bodyStyle, _metaStyle, _tagStyle, _rowBtnStyle, _bigBtnStyle, _insetStyle, _hintStyle;

  public static bool IsOpen => _isOpen;

  public static void Toggle() {
    _isOpen = !_isOpen;
    if (_isOpen) {
      ActionDefinitionLoader.LoadActions();
      QuestViewLoader.LoadQuestView();
    }
  }

  public static void Close() {
    _isOpen = false;
  }

  public static void Draw() {
    if (!_isOpen) {
      return;
    }

    EnsureStyles();
    _window = GUILayout.Window(481620, _window, DrawWindow, GUIContent.none, _windowStyle);
  }

  static void EnsureStyles() {
    if (_stylesReady) {
      return;
    }

    _stylesReady = true;
    Font serif = PanelTheme.Serif;

    _windowStyle = new GUIStyle(GUI.skin.window) {
      padding = new RectOffset(14, 14, 10, 14)
    };
    _windowStyle.normal.background = PanelTheme.PanelTex;
    _windowStyle.onNormal.background = PanelTheme.PanelTex;

    _titleStyle = Rich(20, serif, FontStyle.Bold);
    _headerBtnStyle = new GUIStyle(GUI.skin.button) { richText = true, fontSize = 14 };
    _sectionStyle = Rich(13, null, FontStyle.Bold);
    _nameStyle = Rich(16, serif, FontStyle.Bold);
    _bodyStyle = Rich(14, serif, FontStyle.Normal);
    _bodyStyle.wordWrap = true;
    _metaStyle = Rich(12, null, FontStyle.Normal);
    _tagStyle = Rich(11, null, FontStyle.Bold);
    _tagStyle.alignment = TextAnchor.MiddleRight;
    _rowBtnStyle = new GUIStyle(GUI.skin.button) { fontSize = 12, fontStyle = FontStyle.Bold };
    _bigBtnStyle = new GUIStyle(GUI.skin.button) {
      richText = true, fontSize = 15, alignment = TextAnchor.MiddleLeft,
      padding = new RectOffset(12, 12, 8, 8)
    };
    if (serif != null) {
      _bigBtnStyle.font = serif;
    }

    _insetStyle = new GUIStyle { padding = new RectOffset(11, 11, 9, 9) };
    _insetStyle.normal.background = PanelTheme.InsetTex;
    _hintStyle = Rich(11, null, FontStyle.Normal);
    _hintStyle.alignment = TextAnchor.MiddleCenter;
  }

  static GUIStyle Rich(int size, Font font, FontStyle style) {
    GUIStyle s = new(GUI.skin.label) {
      richText = true, fontSize = size, fontStyle = style, wordWrap = false
    };
    if (font != null) {
      s.font = font;
    }

    return s;
  }

  static void Divider() {
    Rect r = GUILayoutUtility.GetRect(1f, 1f, GUILayout.ExpandWidth(true));
    GUI.DrawTexture(r, PanelTheme.LineTex);
  }

  static void DrawWindow(int windowId) {
    GUILayout.BeginVertical();

    DrawHeader();
    Divider();
    GUILayout.Space(4f);

    _scroll = GUILayout.BeginScrollView(_scroll, GUILayout.ExpandHeight(true));
    switch (_view) {
      case PanelView.Home:
        DrawHome();
        break;
      case PanelView.Slayers:
        DrawSlayers();
        break;
      case PanelView.SlayerRankProof:
        DrawSlayerRankProof();
        break;
      case PanelView.QuestLog:
        DrawQuestLog();
        break;
      default:
        _view = PanelView.Home;
        DrawHome();
        break;
    }
    GUILayout.EndScrollView();

    GUILayout.Space(6f);
    Divider();
    GUILayout.Label(
        $"<color={PanelTheme.Faint}>F7 to toggle · Esc to close · drag by the title bar</color>",
        _hintStyle);

    GUILayout.EndVertical();
    GUI.DragWindow(new Rect(0f, 0f, 10000f, 40f));
  }

  static void DrawHeader() {
    GUILayout.BeginHorizontal(GUILayout.Height(32f));

    if (_view != PanelView.Home) {
      if (GUILayout.Button("<", _headerBtnStyle, GUILayout.Width(34f), GUILayout.Height(28f))) {
        _view = _view == PanelView.SlayerRankProof ? PanelView.Slayers : PanelView.Home;
        _expandedQuestId = null;
      }
    }

    GUILayout.Label($"<color={PanelTheme.Gold}>{TitleForView(_view)}</color>", _titleStyle);
    GUILayout.FlexibleSpace();

    if (_view == PanelView.QuestLog && QuestViewLoader.Quests.Count > 0) {
      GUILayout.Label(
          $"<color={PanelTheme.Faint}>{QuestViewLoader.Quests.Count}</color>",
          _titleStyle, GUILayout.ExpandWidth(false));
      GUILayout.Space(8f);
    }

    if (GUILayout.Button("×", _headerBtnStyle, GUILayout.Width(34f), GUILayout.Height(28f))) {
      Close();
    }

    GUILayout.EndHorizontal();
  }

  static string TitleForView(PanelView view) {
    return view switch {
      PanelView.Slayers => "Slayers",
      PanelView.SlayerRankProof => "Rank Proof",
      PanelView.QuestLog => "Quest Log",
      _ => "Comfy Control"
    };
  }

  // ---------------------------------------------------------------- home

  static void DrawHome() {
    string questLabel =
        $"<b>Quest Log{(QuestViewLoader.Quests.Count > 0 ? $" ({QuestViewLoader.Quests.Count})" : "")}</b>\n"
        + $"<size=12><color={PanelTheme.Dim}>See & capture your tracked quests</color></size>";

    if (GUILayout.Button(questLabel, _bigBtnStyle, GUILayout.Height(52f))) {
      QuestViewLoader.LoadQuestView();
      _view = PanelView.QuestLog;
    }

    GUILayout.Space(10f);
    GUILayout.Label($"<color={PanelTheme.Faint}><b>RANK PROOF</b></color>", _metaStyle);
    GUILayout.Space(2f);

    string slayerAccent = PanelTheme.GuildAccent("Slayers");
    string rankLabel =
        $"<color={slayerAccent}>{PanelTheme.MarkArmed}</color> <b>Slayers — Rank Proof</b>\n"
        + $"<size=12><color={PanelTheme.Dim}>Submit for your next rank</color></size>";

    if (GUILayout.Button(rankLabel, _bigBtnStyle, GUILayout.Height(52f))) {
      _view = PanelView.SlayerRankProof;
    }

    GUILayout.Space(14f);
    if (GUILayout.Button("Reload quest file", _rowBtnStyle, GUILayout.Width(140f), GUILayout.Height(28f))) {
      QuestViewLoader.LoadQuestView();
    }
  }

  static void DrawSlayers() {
    if (GUILayout.Button("Rank Proof", _bigBtnStyle, GUILayout.Height(46f))) {
      _view = PanelView.SlayerRankProof;
    }
  }

  static void DrawSlayerRankProof() {
    Dictionary<string, ControlAction> actions = SlayerRankActions();

    foreach (string rank in SlayerRanks) {
      bool hasAction = actions.TryGetValue(rank, out ControlAction action);
      GUI.enabled = hasAction;

      if (GUILayout.Button(rank, _bigBtnStyle, GUILayout.Height(42f)) && hasAction) {
        SubmissionService.Submit(action.ActionId);
        Close();
      }
    }

    GUI.enabled = true;
  }

  // ---------------------------------------------------------------- quest log

  static void DrawQuestLog() {
    if (QuestViewLoader.LastError != null) {
      DrawErrorState();
      return;
    }

    if (!QuestViewLoader.FileExists || QuestViewLoader.Quests.Count == 0) {
      DrawEmptyState();
      return;
    }

    string currentGuild = null;
    int guildCount = 0;

    foreach (TrackedQuest quest in QuestViewLoader.Quests) {
      if (quest.Guild != currentGuild) {
        currentGuild = quest.Guild;
        guildCount = CountGuild(currentGuild);
        GUILayout.Space(6f);
        string accent = PanelTheme.GuildAccent(currentGuild);
        GUILayout.Label(
            $"<color={accent}>{PanelTheme.MarkBar}</color> <b><color={accent}>{currentGuild.ToUpperInvariant()}</color></b>"
            + $" <color={PanelTheme.Faint}>· {guildCount}</color>",
            _sectionStyle);
      }

      DrawQuestRow(quest);
      Divider();
    }
  }

  static int CountGuild(string guild) {
    int count = 0;
    foreach (TrackedQuest quest in QuestViewLoader.Quests) {
      if (quest.Guild == guild) {
        count++;
      }
    }

    return count;
  }

  static void DrawQuestRow(TrackedQuest quest) {
    bool expanded = _expandedQuestId == quest.QuestId;
    float cooldown = quest.HasTrigger ? QuestTriggerService.CooldownRemaining(quest.QuestId) : 0f;

    GUILayout.BeginVertical();
    GUILayout.Space(5f);

    GUILayout.BeginHorizontal();

    // left marker + name (click to expand)
    string marker = RowMarker(quest, cooldown);
    string nameLabel = $"{marker} <color={PanelTheme.Text}>{quest.Name}</color>";
    if (GUILayout.Button(nameLabel, _nameStyle, GUILayout.ExpandWidth(true))) {
      _expandedQuestId = expanded ? null : quest.QuestId;
    }

    // right cluster
    if (quest.AutoChecked) {
      GUILayout.Label($"<color={PanelTheme.Success}>{PanelTheme.MarkAuto} VERIFIED</color>", _tagStyle);
    } else if (quest.Venue == "irl") {
      GUILayout.Label($"<color={PanelTheme.Faint}>IRL</color>", _tagStyle);
    } else if (quest.HasTrigger && cooldown > 0f) {
      GUILayout.Label(
          $"<color={PanelTheme.Faint}>{PanelTheme.MarkArmed} Re-arms {cooldown:0}s</color>", _tagStyle);
    } else if (quest.HasTrigger) {
      GUILayout.Label($"<color={PanelTheme.Armed}>{PanelTheme.MarkArmed} WATCHING</color>", _tagStyle);
    } else if (GUILayout.Button("Capture", _rowBtnStyle, GUILayout.Width(70f), GUILayout.Height(26f))) {
      SubmissionService.Submit(quest.ToAction());
      Close();
    }

    GUILayout.EndHorizontal();

    // meta line: category + evidence markers
    GUILayout.Label(
        $"<color={PanelTheme.Dim}>{quest.Category}</color>   <color={PanelTheme.Faint}>{EvidenceMarkers(quest)}</color>",
        _metaStyle);

    // receipt strip
    if (SubmissionService.TryGetRecentSubmission(quest.ToAction().ActionId, out int shots, out float age)
        && age < ReceiptSeconds) {
      GUILayout.Label(
          $"<color={PanelTheme.Success}>{PanelTheme.MarkCheck} Proof saved · {shots} shot{(shots == 1 ? "" : "s")} · awaiting guild-master review</color>",
          _metaStyle);
    }

    if (expanded) {
      DrawExpandedSlab(quest);
    }

    GUILayout.Space(5f);
    GUILayout.EndVertical();
  }

  static string RowMarker(TrackedQuest quest, float cooldown) {
    if (quest.AutoChecked) {
      return $"<color={PanelTheme.Success}>{PanelTheme.MarkAuto}</color>";
    }

    if (quest.Venue == "irl") {
      return $"<color={PanelTheme.Faint}>{PanelTheme.MarkIrl}</color>";
    }

    if (quest.HasTrigger) {
      string color = cooldown > 0f ? PanelTheme.Faint : PanelTheme.Armed;
      return $"<color={color}>{PanelTheme.MarkArmed}</color>";
    }

    return $"<color={PanelTheme.Gold}>{PanelTheme.MarkManual}</color>";
  }

  static string EvidenceMarkers(TrackedQuest quest) {
    if (quest.AutoChecked) {
      return "no proof";
    }

    List<string> parts = [];
    if (quest.Screenshots > 0) {
      parts.Add($"{PanelTheme.MarkShot} ×{quest.Screenshots}");
    }

    if (quest.VideoAlternative) {
      parts.Add($"{PanelTheme.MarkVideo} vid");
    }

    if (quest.LinkRequired) {
      parts.Add($"{PanelTheme.MarkIrl} link");
    }

    if (quest.GroupTurnin || quest.Coopable) {
      parts.Add($"{PanelTheme.MarkGroup} group");
    }

    return string.Join("  ", parts);
  }

  static void DrawExpandedSlab(TrackedQuest quest) {
    GUILayout.Space(4f);
    GUILayout.BeginVertical(_insetStyle);

    GUILayout.Label($"<color={PanelTheme.Text}>{quest.Requirements ?? "(no requirements text)"}</color>", _bodyStyle);

    if (!string.IsNullOrWhiteSpace(quest.Reward)) {
      GUILayout.Space(3f);
      GUILayout.Label(
          $"<color={PanelTheme.Gold}><b>Reward</b></color> <color={PanelTheme.Text}>{quest.Reward}</color>",
          _metaStyle);
    }

    if (!string.IsNullOrWhiteSpace(quest.EvidenceNote)) {
      GUILayout.Label(
          $"<color={PanelTheme.Dim}>Evidence: {quest.EvidenceNote}</color>", _metaStyle);
    }

    if (quest.HasTrigger && quest.IsCapturable) {
      GUILayout.Space(3f);
      GUILayout.Label(
          $"<color={PanelTheme.Armed}>{PanelTheme.MarkArmed} Fires automatically on the deed — no button needed.</color>",
          _metaStyle);

      GUILayout.BeginHorizontal();
      if (GUILayout.Button("Test capture", _rowBtnStyle, GUILayout.Width(100f), GUILayout.Height(26f))) {
        SubmissionService.Submit(quest.ToAction());
        Close();
      }
      GUILayout.FlexibleSpace();
      GUILayout.EndHorizontal();
    }

    GUILayout.EndVertical();
    GUILayout.Space(2f);
  }

  static void DrawEmptyState() {
    GUILayout.Space(60f);
    GUILayout.Label(
        $"<size=26><color={PanelTheme.Faint}>{PanelTheme.MarkShot}</color></size>", CenterLabel());
    GUILayout.Space(8f);
    GUILayout.Label($"<size=16><b><color={PanelTheme.Text}>No quests loaded</color></b></size>", CenterLabel());
    GUILayout.Space(6f);
    GUILayout.Label(
        $"<color={PanelTheme.Dim}>Pick quests on the <color={PanelTheme.Gold}>Comfy Quest Picker</color> page,\n"
        + $"then drop <b>quest-view.json</b> into</color>\n"
        + $"<color={PanelTheme.Faint}>{WorkbenchPaths.Root}</color>",
        CenterLabel());
    GUILayout.Space(12f);
    GUILayout.BeginHorizontal();
    GUILayout.FlexibleSpace();
    if (GUILayout.Button("Reload", _rowBtnStyle, GUILayout.Width(90f), GUILayout.Height(30f))) {
      QuestViewLoader.LoadQuestView();
    }
    GUILayout.FlexibleSpace();
    GUILayout.EndHorizontal();
  }

  static void DrawErrorState() {
    GUILayout.Space(60f);
    GUILayout.Label(
        $"<size=26><color={PanelTheme.Error}>{PanelTheme.MarkArmed}</color></size>", CenterLabel());
    GUILayout.Space(8f);
    GUILayout.Label(
        $"<size=16><b><color={PanelTheme.Error}>Couldn't read quest file</color></b></size>", CenterLabel());
    GUILayout.Space(6f);
    GUILayout.Label($"<color={PanelTheme.Dim}>{QuestViewLoader.LastError}</color>", CenterWrapped());
    GUILayout.Space(12f);
    GUILayout.BeginHorizontal();
    GUILayout.FlexibleSpace();
    if (GUILayout.Button("Reload", _rowBtnStyle, GUILayout.Width(90f), GUILayout.Height(30f))) {
      QuestViewLoader.LoadQuestView();
    }
    GUILayout.Space(8f);
    if (GUILayout.Button("Open folder", _rowBtnStyle, GUILayout.Width(100f), GUILayout.Height(30f))) {
      Application.OpenURL("file://" + WorkbenchPaths.Root.Replace('\\', '/'));
    }
    GUILayout.FlexibleSpace();
    GUILayout.EndHorizontal();
  }

  static GUIStyle CenterLabel() {
    GUIStyle style = new(_metaStyle) { alignment = TextAnchor.MiddleCenter, wordWrap = false };
    return style;
  }

  static GUIStyle CenterWrapped() {
    GUIStyle style = new(_metaStyle) { alignment = TextAnchor.MiddleCenter, wordWrap = true };
    return style;
  }

  static Dictionary<string, ControlAction> SlayerRankActions() {
    Dictionary<string, ControlAction> actions = new(StringComparer.OrdinalIgnoreCase);

    foreach (ControlAction action in ActionDefinitionLoader.Actions) {
      if (!string.Equals(action.SubmissionType, "slayer_rank_proof", StringComparison.OrdinalIgnoreCase)) {
        continue;
      }

      string rank = !string.IsNullOrWhiteSpace(action.WorkflowRank)
          ? action.WorkflowRank
          : InferRankFromActionId(action.ActionId);

      if (!string.IsNullOrWhiteSpace(rank)) {
        actions[rank] = action;
      }
    }

    return actions;
  }

  static string InferRankFromActionId(string actionId) {
    const string prefix = "slayer_rank_";
    if (string.IsNullOrWhiteSpace(actionId)
        || !actionId.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) {
      return null;
    }

    string rank = actionId.Substring(prefix.Length).Replace("_", " ");
    return CultureTitle(rank);
  }

  static string CultureTitle(string value) {
    if (string.IsNullOrWhiteSpace(value)) {
      return value;
    }

    return char.ToUpperInvariant(value[0]) + value.Substring(1).ToLowerInvariant();
  }
}
