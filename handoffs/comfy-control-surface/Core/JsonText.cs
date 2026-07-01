namespace Comfy.ControlSurface.Core;

using System;
using System.Globalization;
using System.Text;

using UnityEngine;

public static class JsonText {
  public static string String(string value) {
    if (value == null) {
      return "null";
    }

    StringBuilder builder = new();
    builder.Append('"');

    foreach (char c in value) {
      switch (c) {
        case '\\':
          builder.Append("\\\\");
          break;
        case '"':
          builder.Append("\\\"");
          break;
        case '\n':
          builder.Append("\\n");
          break;
        case '\r':
          builder.Append("\\r");
          break;
        case '\t':
          builder.Append("\\t");
          break;
        default:
          if (char.IsControl(c)) {
            builder.Append("\\u");
            builder.Append(((int) c).ToString("x4", CultureInfo.InvariantCulture));
          } else {
            builder.Append(c);
          }
          break;
      }
    }

    builder.Append('"');
    return builder.ToString();
  }

  public static string Bool(bool value) {
    return value ? "true" : "false";
  }

  public static string Number(float value) {
    return value.ToString("0.###", CultureInfo.InvariantCulture);
  }

  public static string Number(double value) {
    return value.ToString("0.###", CultureInfo.InvariantCulture);
  }

  public static string NullableString(string value) {
    return string.IsNullOrWhiteSpace(value) ? "null" : String(value);
  }

  public static string Vector(Vector3 value) {
    return $"{{ \"x\": {Number(value.x)}, \"y\": {Number(value.y)}, \"z\": {Number(value.z)} }}";
  }

  public static string Utc(DateTime value) {
    return String(value.ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", CultureInfo.InvariantCulture));
  }
}
