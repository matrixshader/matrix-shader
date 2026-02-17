namespace MatrixShader.Core.Services;

/// <summary>
/// Result of a license activation attempt.
/// </summary>
public enum ActivationResult
{
    /// <summary>Key is valid, saved, and server-verified (or server was unreachable).</summary>
    Success,

    /// <summary>Key format or HMAC signature is invalid.</summary>
    InvalidKey,

    /// <summary>Key is valid but has been activated on too many machines.</summary>
    ActivationLimitExceeded,

    /// <summary>Failed to save key to disk.</summary>
    SaveFailed,
}

/// <summary>
/// Service for managing Red Pill license validation.
/// Offline-first with server-side activation tracking.
/// </summary>
public interface ILicenseService
{
    /// <summary>
    /// Checks if a valid Red Pill license is installed.
    /// </summary>
    bool IsLicensed { get; }

    /// <summary>
    /// Validates and activates a license key.
    /// Performs offline HMAC check, then server activation tracking.
    /// </summary>
    /// <param name="key">License key in format REDPILL-XXXX-XXXX-XXXX-XXXX</param>
    /// <returns>Activation result indicating success or failure reason</returns>
    ActivationResult Activate(string key);

    /// <summary>
    /// Gets the installed license key, or null if none.
    /// </summary>
    string? GetInstalledKey();

    /// <summary>
    /// Validates a license key format and signature without saving.
    /// </summary>
    /// <param name="key">License key to validate</param>
    /// <returns>True if key format and HMAC are valid</returns>
    bool ValidateKey(string key);
}
