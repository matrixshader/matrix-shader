using System.Security.Cryptography;
using System.Text;

namespace MatrixShader.Core.Services;

/// <summary>
/// Offline license validation using HMAC-SHA256.
/// Key format: REDPILL-XXXX-XXXX-XXXX-XXXX where the last group is a truncated HMAC
/// of the first three groups, keyed with an embedded product secret.
///
/// Design philosophy: honest people pay, pirates never would have.
/// Don't punish paying customers with aggressive DRM.
/// </summary>
public sealed class LicenseService : ILicenseService
{
    // Product secret for HMAC validation — injected at build time from gitignored file.
    // Source: MatrixShader/license-secret.key (never committed to git).
    // Generated class: LicenseSecret.g.cs (in obj/, also gitignored).
    private static readonly byte[] ProductSecret = Encoding.UTF8.GetBytes(
        LicenseSecret.Value);

    private static readonly string LicenseDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "MatrixShader");

    private static readonly string LicensePath = Path.Combine(LicenseDir, "license.key");

    private bool? _cachedResult;

    /// <inheritdoc/>
    public bool IsLicensed
    {
        get
        {
            if (_cachedResult.HasValue)
                return _cachedResult.Value;

            var key = GetInstalledKey();
            _cachedResult = key != null && ValidateKey(key);
            return _cachedResult.Value;
        }
    }

    /// <inheritdoc/>
    public bool Activate(string key)
    {
        if (!ValidateKey(key))
            return false;

        try
        {
            Directory.CreateDirectory(LicenseDir);
            File.WriteAllText(LicensePath, key.Trim().ToUpperInvariant());
            _cachedResult = true;
            DiagnosticLogger.Info("LICENSE", "License activated successfully");
            return true;
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Error("LICENSE", $"Failed to save license: {ex.Message}");
            return false;
        }
    }

    /// <inheritdoc/>
    public string? GetInstalledKey()
    {
        try
        {
            if (!File.Exists(LicensePath))
                return null;

            var key = File.ReadAllText(LicensePath).Trim();
            return string.IsNullOrWhiteSpace(key) ? null : key;
        }
        catch
        {
            return null;
        }
    }

    /// <inheritdoc/>
    public bool ValidateKey(string key)
    {
        if (string.IsNullOrWhiteSpace(key))
            return false;

        key = key.Trim().ToUpperInvariant();

        // Format: REDPILL-XXXX-XXXX-XXXX-XXXX
        var parts = key.Split('-');
        if (parts.Length != 5)
            return false;

        if (parts[0] != "REDPILL")
            return false;

        // Each group after prefix should be 4 alphanumeric chars
        for (int i = 1; i <= 4; i++)
        {
            if (parts[i].Length != 4)
                return false;
            if (!parts[i].All(c => char.IsLetterOrDigit(c)))
                return false;
        }

        // The payload is groups 1-3, the signature is group 4
        var payload = $"{parts[0]}-{parts[1]}-{parts[2]}-{parts[3]}";
        var expectedSig = ComputeSignature(payload);

        return string.Equals(parts[4], expectedSig, StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>
    /// Generates a license key for a given payload seed.
    /// Used by the key generation tool (not shipped to users).
    /// </summary>
    public static string GenerateKey(string seed)
    {
        // Create 3 groups from the seed hash
        using var sha = SHA256.Create();
        var hash = sha.ComputeHash(Encoding.UTF8.GetBytes(seed));

        var g1 = ToBase36(hash, 0, 4);
        var g2 = ToBase36(hash, 4, 4);
        var g3 = ToBase36(hash, 8, 4);

        var payload = $"REDPILL-{g1}-{g2}-{g3}";
        var sig = ComputeSignature(payload);

        return $"{payload}-{sig}";
    }

    private static string ComputeSignature(string payload)
    {
        using var hmac = new HMACSHA256(ProductSecret);
        var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(payload));
        // Take first 4 chars of base36-encoded HMAC
        return ToBase36(hash, 0, 4);
    }

    private static string ToBase36(byte[] bytes, int offset, int length)
    {
        const string chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        var sb = new StringBuilder(length);
        for (int i = 0; i < length; i++)
        {
            var idx = (offset + i < bytes.Length) ? bytes[offset + i] % 36 : 0;
            sb.Append(chars[idx]);
        }
        return sb.ToString();
    }
}
