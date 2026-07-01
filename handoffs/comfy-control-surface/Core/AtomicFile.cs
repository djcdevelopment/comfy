namespace Comfy.ControlSurface.Core;

using System.IO;
using System.Text;

public static class AtomicFile {
  public static void WriteAllText(string finalPath, string content) {
    string dir = Path.GetDirectoryName(finalPath);
    if (!string.IsNullOrWhiteSpace(dir)) {
      Directory.CreateDirectory(dir);
    }

    string tempPath = finalPath + ".tmp";
    File.WriteAllText(tempPath, content, Encoding.UTF8);

    if (File.Exists(finalPath)) {
      File.Delete(finalPath);
    }

    File.Move(tempPath, finalPath);
  }
}
