using System.Security.Cryptography;
using System.Text;

namespace MatrixShader.Core.Services;

/// <summary>
/// Generates a deterministic machine fingerprint for activation tracking.
/// SHA256 of (MachineName + UserName + OSVersion), truncated to 16 hex chars.
/// </summary>
public static class MachineFingerprint
{
    private static string? _cached;

    public static string Get()
    {
        if (_cached != null)
            return _cached;

        var raw = string.Join("|",
            Environment.MachineName,
            Environment.UserName,
            Environment.OSVersion.ToString());

        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(raw));
        _cached = Convert.ToHexString(hash)[..16].ToLowerInvariant();
        return _cached;
    }
}
