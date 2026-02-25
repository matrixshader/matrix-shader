using System.Reflection;
using System.Text.RegularExpressions;
using MatrixShader.Core.Helpers;

namespace MatrixShader.Core.Services;

/// <summary>
/// Checks for new versions of MatrixShader on GitHub releases.
/// Runs asynchronously on startup — never blocks, never crashes the app.
/// </summary>
public static class UpdateChecker
{
    private const string ReleasesApi = "https://api.github.com/repos/matrixshader/matrix-shader/releases/latest";
    private static readonly TimeSpan Timeout = TimeSpan.FromSeconds(5);

    /// <summary>
    /// Checks GitHub for a newer release and prints a notification if one exists.
    /// Fire-and-forget — swallows all exceptions.
    /// </summary>
    public static async Task CheckAsync()
    {
        try
        {
            var currentVersion = GetCurrentVersion();
            if (currentVersion == null)
                return;

            using var http = new HttpClient();
            http.DefaultRequestHeaders.Add("User-Agent", "MatrixShader-UpdateCheck");
            http.Timeout = Timeout;

            var json = await http.GetStringAsync(ReleasesApi);

            // Parse tag_name from JSON (e.g., "v1.1.0" or "1.1.0")
            var match = Regex.Match(json, @"""tag_name"":\s*""v?(\d+\.\d+\.\d+)""");
            if (!match.Success)
                return;

            var latestVersion = Version.Parse(match.Groups[1].Value);

            if (latestVersion > currentVersion)
            {
                Console.WriteLine();
                Console.Write($" \x1b[33m UPDATE: v{latestVersion} available");
                Console.WriteLine($" \x1b[90m— run: irm https://matrixshader.com/install.ps1 | iex\x1b[0m");
                Console.WriteLine();
            }
        }
        catch
        {
            // Silently ignore — no internet, timeout, rate limit, etc.
            // Never punish the user for a failed update check.
        }
    }

    /// <summary>
    /// Gets the current assembly version.
    /// </summary>
    private static Version? GetCurrentVersion()
    {
        try
        {
            var version = Assembly.GetEntryAssembly()?.GetName().Version;
            // Assembly version is 1.0.0.0 — compare as 1.0.0
            if (version != null)
                return new Version(version.Major, version.Minor, version.Build);
            return null;
        }
        catch
        {
            return null;
        }
    }
}
