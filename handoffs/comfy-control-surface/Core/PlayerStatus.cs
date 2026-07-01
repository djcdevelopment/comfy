namespace Comfy.ControlSurface.Core;

using System;
using System.Reflection;

public static class PlayerStatus {
  public static void Show(string message) {
    try {
      if (MessageHud.instance) {
        MessageHud.instance.ShowMessage(MessageHud.MessageType.Center, message);
        return;
      }
    } catch (Exception ex) {
      ComfyControlSurface.LogWarning($"MessageHud status failed: {ex.Message}");
    }

    try {
      if (Chat.instance) {
        MethodInfo method =
            typeof(Chat).GetMethod("AddMessage", BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic)
            ?? typeof(Chat).GetMethod("AddString", BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);

        if (method != null) {
          method.Invoke(Chat.instance, new object[] { message });
          return;
        }
      }
    } catch (Exception ex) {
      ComfyControlSurface.LogWarning($"Chat status failed: {ex.Message}");
    }

    ComfyControlSurface.LogInfo(message);
  }
}
