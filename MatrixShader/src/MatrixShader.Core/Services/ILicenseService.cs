namespace MatrixShader.Core.Services;

/// <summary>
/// Result of a license activation attempt.
/// </summary>
public enum ActivationResult
{
    /// <summary>Key is valid, saved, and server-verified.</summary>
    Success,

    /// <summary>Key format or HMAC signature is invalid.</summary>
    InvalidKey,

    /// <summary>Key is valid but has been activated on too many machines.</summary>
    ActivationLimitExceeded,

    /// <summary>Failed to save key to disk.</summary>
    SaveFailed,

    /// <summary>Server unreachable — activation requires server verification on first use.</summary>
    ServerUnreachable,
}

/// <summary>
/// Service for managing Red Pill license validation.
/// Server-verified activation with fully offline post-activation use.
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
