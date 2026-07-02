namespace Comfy.ControlSurface.Core;

using UnityEngine;

/// <summary>Design tokens from the quest-log design pass (DESIGN-PROMPT-quest-log.md
/// deliverable): flat colors, one serif family, geometric markers, no emoji.</summary>
public static class PanelTheme {
  // palette (flat colors only)
  public static readonly Color Panel = New("221A12");        // panel solid
  public static readonly Color Inset = New("2B2118");
  public static readonly Color Line = New("48392A");
  public static readonly Color LineSoft = New("382B1F");
  public const string Text = "#e8ddc8";
  public const string Dim = "#a2937a";
  public const string Faint = "#6f6250";
  public const string Gold = "#c9a24a";
  public const string Armed = "#e0a83f";
  public const string Success = "#7ba85f";
  public const string Error = "#c25a41";

  // markers (flat geometric glyphs — the no-emoji system)
  public const string MarkArmed = "◇";      // ◇ hollow diamond
  public const string MarkAuto = "◆";       // ◆ filled diamond
  public const string MarkManual = "■";     // ■ square
  public const string MarkIrl = "○";        // ○ ring
  public const string MarkShot = "▣";       // ▣ photo frame
  public const string MarkVideo = "▶";      // ▶ play
  public const string MarkGroup = "▪▪"; // ▪▪
  public const string MarkCheck = "✓";      // ✓
  public const string MarkBar = "▍";        // ▍ section bar

  static Texture2D _panelTex;
  static Texture2D _insetTex;
  static Texture2D _lineTex;
  static Font _serif;
  static bool _fontSearched;

  public static Texture2D PanelTex => _panelTex ??= MakeTex(Panel);
  public static Texture2D InsetTex => _insetTex ??= MakeTex(Inset);
  public static Texture2D LineTex => _lineTex ??= MakeTex(Line);

  /// <summary>The game's own serif (AveriaSerifLibre) if it can be found; null falls
  /// back to the IMGUI default.</summary>
  public static Font Serif {
    get {
      if (!_fontSearched) {
        _fontSearched = true;
        foreach (Font font in Resources.FindObjectsOfTypeAll<Font>()) {
          if (font != null && font.name.StartsWith("AveriaSerifLibre")) {
            _serif = font;
            break;
          }
        }
      }

      return _serif;
    }
  }

  public static string GuildAccent(string guild) {
    return (guild ?? string.Empty).ToLowerInvariant() switch {
      "slayers" => "#b1503a",
      "rangers" => "#6f9450",
      _ => Gold
    };
  }

  static Color New(string hex) {
    return ColorUtility.TryParseHtmlString("#" + hex, out Color color) ? color : Color.magenta;
  }

  static Texture2D MakeTex(Color color) {
    Texture2D tex = new(1, 1, TextureFormat.RGBA32, mipChain: false) {
      hideFlags = HideFlags.HideAndDontSave
    };
    tex.SetPixel(0, 0, color);
    tex.Apply();
    return tex;
  }
}
