namespace MatrixShader.Core.Services;

/// <summary>
/// Service for managing Red Pill license validation.
/// Offline-first: validates locally via HMAC-SHA256, no phone-home.
/// </summary>
public interface ILicenseService
{
    /// <summary>
    /// Checks if a valid Red Pill license is installed.
    /// </summary>
    bool IsLicensed { get; }

    /// <summary>
    /// Validates and activates a license key.
    /// </summary>
    /// <param name="key">License key in format REDPILL-XXXX-XXXX-XXXX-XXXX</param>
    /// <returns>True if key is valid and was saved</returns>
    bool Activate(string key);

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
