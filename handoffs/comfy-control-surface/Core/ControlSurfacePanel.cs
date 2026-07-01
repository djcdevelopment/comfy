namespace Comfy.ControlSurface.Core;

using System;
using System.Collections.Generic;

using UnityEngine;

public static class ControlSurfacePanel {
  enum PanelView {
    Home,
    Slayers,
    SlayerRankProof
  }

  static readonly string[] SlayerRanks = ["Thrall", "Thegn", "Jarl"];

  static bool _isOpen;
  static PanelView _view = PanelView.Home;
  static Rect _window = new(80f, 80f, 360f, 260f);
  static Vector2 _scroll;

  public static void Toggle() {
    _isOpen = !_isOpen;
    if (_isOpen) {
      ActionDefinitionLoader.LoadActions();
    }
  }

  public static void Close() {
    _isOpen = false;
  }

  public static void Draw() {
    if (!_isOpen) {
      return;
    }

    _window = GUI.Window(481620, _window, DrawWindow, "Comfy");
  }

  static void DrawWindow(int windowId) {
    GUILayout.BeginVertical(GUILayout.Width(340f));

    DrawToolbar();

    _scroll = GUILayout.BeginScrollView(_scroll, GUILayout.Height(178f));
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
      default:
        _view = PanelView.Home;
        DrawHome();
        break;
    }
    GUILayout.EndScrollView();

    GUILayout.FlexibleSpace();
    GUILayout.BeginHorizontal();
    GUILayout.FlexibleSpace();
    if (GUILayout.Button("Close", GUILayout.Width(88f), GUILayout.Height(28f))) {
      Close();
    }
    GUILayout.EndHorizontal();

    GUILayout.EndVertical();
    GUI.DragWindow(new Rect(0f, 0f, 10000f, 22f));
  }

  static void DrawToolbar() {
    GUILayout.BeginHorizontal();

    GUI.enabled = _view != PanelView.Home;
    if (GUILayout.Button("<", GUILayout.Width(36f), GUILayout.Height(28f))) {
      _view = _view == PanelView.SlayerRankProof ? PanelView.Slayers : PanelView.Home;
    }
    GUI.enabled = true;

    GUILayout.Label(TitleForView(_view), GUILayout.Height(28f));

    GUILayout.EndHorizontal();
  }

  static string TitleForView(PanelView view) {
    return view switch {
      PanelView.Slayers => "Slayers",
      PanelView.SlayerRankProof => "Rank Proof",
      _ => "Workflows"
    };
  }

  static void DrawHome() {
    if (GUILayout.Button("Slayers", GUILayout.Height(42f))) {
      _view = PanelView.Slayers;
    }
  }

  static void DrawSlayers() {
    if (GUILayout.Button("Rank Proof", GUILayout.Height(42f))) {
      _view = PanelView.SlayerRankProof;
    }
  }

  static void DrawSlayerRankProof() {
    Dictionary<string, ControlAction> actions = SlayerRankActions();

    foreach (string rank in SlayerRanks) {
      bool hasAction = actions.TryGetValue(rank, out ControlAction action);
      GUI.enabled = hasAction;

      if (GUILayout.Button(rank, GUILayout.Height(42f)) && hasAction) {
        SubmissionService.Submit(action.ActionId);
        Close();
      }
    }

    GUI.enabled = true;
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
