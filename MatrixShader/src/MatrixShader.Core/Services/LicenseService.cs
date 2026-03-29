using System.Net.Http;
using System.Text;

namespace MatrixShader.Core.Services;

/// <summary>
/// License service — server-authoritative validation.
/// Client checks if a key file exists on disk (offline use after activation).
/// Activation sends key to server for HMAC validation + machine limit check.
/// The client NEVER has the signing secret.
/// </summary>
public sealed class LicenseService : ILicenseService
{
    private static readonly string LicenseDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "MatrixShader");

    private static readonly string LicensePath = Path.Combine(LicenseDir, "license.key");

    private const string ValidateUrl = "https://matrixshader.com/api/validate";
    private static readonly TimeSpan ServerTimeout = TimeSpan.FromSeconds(8);

    private bool? _cachedResult;

    /// <inheritdoc/>
    public bool IsLicensed
    {
        get
        {
            if (_cachedResult.HasValue)
                return _cachedResult.Value;

            // Licensed = key file exists with valid format on disk.
            // The key was validated by the server during activation.
            var key = GetInstalledKey();
            _cachedResult = key != null && HasValidFormat(key);
            return _cachedResult.Value;
        }
    }

    /// <inheritdoc/>
    public ActivationResult Activate(string key)
    {
        if (!HasValidFormat(key))
            return ActivationResult.InvalidKey;

        // Server does the real validation (HMAC + machine limit)
        var serverResult = CheckServerActivation(key);
        if (serverResult != ActivationResult.Success)
            return serverResult;

        try
        {
            Directory.CreateDirectory(LicenseDir);
            File.WriteAllText(LicensePath, key.Trim().ToUpperInvariant());
            _cachedResult = true;
            DiagnosticLogger.Info("LICENSE", "License activated successfully");
            return ActivationResult.Success;
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Error("LICENSE", $"Failed to save license: {ex.Message}");
            return ActivationResult.SaveFailed;
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

    /// <summary>
    /// Checks format only — REDPILL-XXXX-XXXX-XXXX-XXXX.
    /// Does NOT validate the HMAC signature (server does that).
    /// </summary>
    public bool ValidateKey(string key) => HasValidFormat(key);

    private static bool HasValidFormat(string key)
    {
        if (string.IsNullOrWhiteSpace(key))
            return false;

        key = key.Trim().ToUpperInvariant();
        var parts = key.Split('-');
        if (parts.Length != 5)
            return false;

        if (parts[0] != "REDPILL")
            return false;

        for (int i = 1; i <= 4; i++)
        {
            if (parts[i].Length != 4)
                return false;
            if (!parts[i].All(c => char.IsLetterOrDigit(c)))
                return false;
        }

        return true;
    }

    /// <summary>
    /// Calls /api/validate to check key validity + activation count.
    /// The SERVER does HMAC validation — client never has the secret.
    /// </summary>
    private static ActivationResult CheckServerActivation(string key)
    {
        try
        {
            using var client = new HttpClient { Timeout = ServerTimeout };

            var fingerprint = MachineFingerprint.Get();
            var normalizedKey = key.Trim().ToUpperInvariant();
            var payload = $"{{\"key\":\"{normalizedKey}\",\"fingerprint\":\"{fingerprint}\"}}";

            var content = new StringContent(payload, Encoding.UTF8, "application/json");
            var response = client.PostAsync(ValidateUrl, content).GetAwaiter().GetResult();

            if (response.StatusCode == System.Net.HttpStatusCode.Forbidden)
            {
                DiagnosticLogger.Warn("LICENSE", "Activation limit exceeded for this key");
                return ActivationResult.ActivationLimitExceeded;
            }

            if (response.IsSuccessStatusCode)
            {
                DiagnosticLogger.Info("LICENSE", $"Server validation: {(int)response.StatusCode}");
                return ActivationResult.Success;
            }

            DiagnosticLogger.Warn("LICENSE", $"Server error {(int)response.StatusCode}, activation blocked");
            return ActivationResult.ServerUnreachable;
        }
        catch (Exception ex)
        {
            DiagnosticLogger.Warn("LICENSE", $"Server unreachable: {ex.Message}");
            return ActivationResult.ServerUnreachable;
        }
    }
}
