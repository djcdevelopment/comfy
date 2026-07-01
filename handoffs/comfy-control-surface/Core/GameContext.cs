namespace Comfy.ControlSurface.Core;

using System;
using System.Reflection;

using UnityEngine;

public sealed class GameContext {
  public string PlayerName { get; set; }
  public string PlayerId { get; set; }
  public string WorldName { get; set; }
  public string WorldSeed { get; set; }
  public Vector3 Position { get; set; }
  public string Biome { get; set; }

  public static GameContext Capture() {
    Player player = Player.m_localPlayer;
    if (!player) {
      throw new InvalidOperationException("Player.m_localPlayer is not available.");
    }

    Vector3 position = player.transform.position;

    return new GameContext {
      PlayerName = TryGetPlayerName(player),
      PlayerId = TryGetPlayerId(player),
      WorldName = TryGetWorldName(),
      WorldSeed = null,
      Position = position,
      Biome = TryGetBiome(position)
    };
  }

  static string TryGetPlayerName(Player player) {
    try {
      MethodInfo method = typeof(Player).GetMethod("GetPlayerName", BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
      if (method?.Invoke(player, null) is string name && !string.IsNullOrWhiteSpace(name)) {
        return name;
      }
    } catch {
      // Fall through to reflection fields.
    }

    try {
      FieldInfo field = typeof(Player).GetField("m_playerName", BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
      if (field?.GetValue(player) is string name && !string.IsNullOrWhiteSpace(name)) {
        return name;
      }
    } catch {
      // Fall through.
    }

    return "unknown";
  }

  static string TryGetPlayerId(Player player) {
    try {
      MethodInfo method = typeof(Player).GetMethod("GetPlayerID", BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
      object value = method?.Invoke(player, null);
      return value?.ToString();
    } catch {
      return null;
    }
  }

  static string TryGetWorldName() {
    try {
      if (ZNet.instance?.GetWorldName() is string worldName && !string.IsNullOrWhiteSpace(worldName)) {
        return worldName;
      }
    } catch {
      // Fall through.
    }

    return null;
  }

  static string TryGetBiome(Vector3 position) {
    try {
      if (WorldGenerator.instance != null) {
        return WorldGenerator.instance.GetBiome(position).ToString();
      }
    } catch {
      // Fall through.
    }

    return "unknown";
  }
}
