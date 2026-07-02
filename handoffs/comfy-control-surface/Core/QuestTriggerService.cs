namespace Comfy.ControlSurface.Core;

using System;
using System.Collections.Generic;

using UnityEngine;

/// <summary>
/// Automatic evidence capture: when a game event matches a tracked quest's trigger
/// spec, submit proof exactly as if the player pressed Capture — at the moment the
/// event happens, so the action itself is in frame.
/// </summary>
public static class QuestTriggerService {
  const float CooldownSeconds = 60f;

  static readonly Dictionary<string, float> _lastFired = new(StringComparer.OrdinalIgnoreCase);

  sealed class ActiveSequence {
    public TrackedQuest Quest;
    public int TargetInstanceId;
    public SubmissionService.SequenceRequest Request;
  }

  static ActiveSequence _sequence;

  /// <summary>Kill-event triggers. Fired from the creature damage hook: once on every
  /// local-player hit (died = false) and once when the blow was fatal (died = true).
  /// A quest with an on_first_hit shot arms a two-shot sequence bound to that creature;
  /// the kill confirms it. A kill-only quest submits a single shot on the death.</summary>
  public static void OnCreatureDamaged(Character character, HitData hit, bool died) {
    if (QuestViewLoader.Quests.Count == 0 || character == null || hit == null || character.IsPlayer()) {
      return;
    }

    Character attacker = hit.GetAttacker();
    if (attacker == null || attacker != Player.m_localPlayer) {
      return;
    }

    // progress a pending sequence first
    if (_sequence != null) {
      if (_sequence.Request == null || _sequence.Request.Abandoned) {
        _sequence = null;
      } else if (died && character.GetInstanceID() == _sequence.TargetInstanceId) {
        _sequence.Request.KillConfirmed = true;
        ComfyControlSurface.LogInfo($"Quest sequence kill confirmed: {_sequence.Quest.QuestId}");
        _sequence = null;
        return;
      }
    }

    string skill = hit.m_skill.ToString();
    string targetName = character.name;

    foreach (TrackedQuest quest in QuestViewLoader.Quests) {
      if (!quest.HasTrigger || !quest.IsCapturable) {
        continue;
      }

      if (!string.Equals(quest.TriggerEvent, "kill", StringComparison.OrdinalIgnoreCase)) {
        continue;
      }

      if (!CreatureMatches(quest.TriggerTarget, targetName)) {
        continue;
      }

      if (!string.IsNullOrWhiteSpace(quest.TriggerWeaponSkill)
          && !string.Equals(quest.TriggerWeaponSkill, skill, StringComparison.OrdinalIgnoreCase)) {
        continue;
      }

      if (quest.TriggerProjectile && !hit.m_ranged) {
        continue;
      }

      if (OnCooldown(quest.QuestId)) {
        continue;
      }

      if (quest.WantsFirstHitShot) {
        if (_sequence != null || SubmissionService.IsSequenceRunning) {
          continue;
        }

        SubmissionService.SequenceRequest request = SubmissionService.SubmitSequence(quest.ToAction());
        if (request == null) {
          continue;
        }

        if (died) {
          // the first matching blow was also the killing blow
          request.KillConfirmed = true;
        } else {
          _sequence = new ActiveSequence {
            Quest = quest,
            TargetInstanceId = character.GetInstanceID(),
            Request = request
          };
        }

        _lastFired[quest.QuestId] = Time.realtimeSinceStartup;
        ComfyControlSurface.LogInfo(
            $"Quest sequence armed: {quest.QuestId} (target {targetName}, skill {skill}, died {died})");
        PlayerStatus.Show($"Quest evidence armed: {quest.Name}");
        return;
      }

      if (died) {
        _lastFired[quest.QuestId] = Time.realtimeSinceStartup;
        ComfyControlSurface.LogInfo($"Quest trigger fired: {quest.QuestId} (kill {targetName}, skill {skill})");
        PlayerStatus.Show($"Quest evidence: {quest.Name}");
        SubmissionService.Submit(quest.ToAction());
        return;
      }
    }
  }

  static bool CreatureMatches(string filter, string creatureName) {
    if (string.IsNullOrWhiteSpace(filter) || string.Equals(filter, "any", StringComparison.OrdinalIgnoreCase)) {
      return true;
    }

    string name = (creatureName ?? string.Empty).ToLowerInvariant().Replace("(clone)", "").Trim();
    return name.Contains(filter.ToLowerInvariant());
  }

  static bool OnCooldown(string questId) {
    return CooldownRemaining(questId) > 0f;
  }

  /// <summary>Seconds until this quest's trigger re-arms; 0 when armed.</summary>
  public static float CooldownRemaining(string questId) {
    if (!_lastFired.TryGetValue(questId, out float last)) {
      return 0f;
    }

    float remaining = CooldownSeconds - (Time.realtimeSinceStartup - last);
    return remaining > 0f ? remaining : 0f;
  }

  public static void OnLocalPlayerHit(string targetKind, string targetName, HitData hit) {
    if (QuestViewLoader.Quests.Count == 0 || hit == null) {
      return;
    }

    Character attacker = hit.GetAttacker();
    if (attacker == null || attacker != Player.m_localPlayer) {
      return;
    }

    string skill = hit.m_skill.ToString();

    foreach (TrackedQuest quest in QuestViewLoader.Quests) {
      if (!quest.HasTrigger || !quest.IsCapturable) {
        continue;
      }

      if (!string.Equals(quest.TriggerEvent, "hit", StringComparison.OrdinalIgnoreCase)) {
        continue;
      }

      if (!TargetMatches(quest.TriggerTarget, targetKind, targetName)) {
        continue;
      }

      if (!string.IsNullOrWhiteSpace(quest.TriggerWeaponSkill)
          && !string.Equals(quest.TriggerWeaponSkill, skill, StringComparison.OrdinalIgnoreCase)) {
        continue;
      }

      if (_lastFired.TryGetValue(quest.QuestId, out float last)
          && Time.realtimeSinceStartup - last < CooldownSeconds) {
        continue;
      }

      _lastFired[quest.QuestId] = Time.realtimeSinceStartup;

      ComfyControlSurface.LogInfo(
          $"Quest trigger fired: {quest.QuestId} (target {targetKind}:{targetName}, skill {skill})");
      PlayerStatus.Show($"Quest evidence: {quest.Name}");
      SubmissionService.Submit(quest.ToAction());
      return;  // one submission per hit
    }
  }

  static bool TargetMatches(string filter, string targetKind, string targetName) {
    if (string.IsNullOrWhiteSpace(filter) || string.Equals(filter, "any", StringComparison.OrdinalIgnoreCase)) {
      return true;
    }

    string name = (targetName ?? string.Empty).ToLowerInvariant();
    bool isTree = string.Equals(targetKind, "tree", StringComparison.OrdinalIgnoreCase);
    bool isBush = name.Contains("bush") || name.Contains("shrub");

    return filter.ToLowerInvariant() switch {
      "tree_or_bush" => isTree || isBush,
      "tree" => isTree,
      "bush" => isBush,
      _ => false
    };
  }
}
