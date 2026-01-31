using Microsoft.Toolkit.Uwp.Notifications;

namespace MatrixShader.Hotkeys;

/// <summary>
/// Toast notification support for hotkey conflict warnings.
/// Uses Windows 10/11 native toast notifications via Microsoft.Toolkit.Uwp.Notifications.
/// </summary>
public static class ToastNotifications
{
    /// <summary>
    /// App User Model ID for toast notification attribution.
    /// Required for non-packaged (non-MSIX) apps to show toasts.
    /// </summary>
    private const string AppId = "MatrixShader.Hotkeys";

    /// <summary>
    /// Shows a toast notification warning about hotkey conflicts.
    /// Displays which hotkeys failed to register and directs user to Redpill for configuration.
    /// </summary>
    /// <param name="failedHotkeys">List of hotkeys that failed to register.</param>
    public static void ShowConflictWarning(IReadOnlyList<FailedHotkey> failedHotkeys)
    {
        if (failedHotkeys.Count == 0)
            return;

        try
        {
            var builder = new ToastContentBuilder();

            // Header
            builder.AddText("Matrix Shader: Hotkey Conflicts");

            // Subtitle with count
            builder.AddText($"{failedHotkeys.Count} hotkey(s) could not be registered:");

            // Build list of failed hotkeys (limit to first 5 to avoid overflow)
            var displayCount = Math.Min(failedHotkeys.Count, 5);
            var hotkeyList = string.Join("\n", failedHotkeys
                .Take(displayCount)
                .Select(h => $"  {h.DisplayName}: {h.ActionName}"));

            if (failedHotkeys.Count > displayCount)
            {
                hotkeyList += $"\n  ... and {failedHotkeys.Count - displayCount} more";
            }

            builder.AddText(hotkeyList);

            // Action guidance
            builder.AddText("Open Redpill control panel to configure hotkeys.");

            // Attribution text
            builder.AddAttributionText("Matrix Shader Hotkey Service");

            // Set app logo (use generic app icon)
            // Note: For non-packaged apps, we use inline icon

            // Duration - long to ensure user sees it
            builder.SetToastDuration(ToastDuration.Long);

            // Show the toast
            builder.Show();
        }
        catch
        {
            // Fail silently - toast notifications are non-critical
            // User can still use Redpill to check hotkey status
        }
    }

    /// <summary>
    /// Shows a simple informational toast notification.
    /// </summary>
    /// <param name="title">Toast title.</param>
    /// <param name="message">Toast message body.</param>
    public static void ShowInfo(string title, string message)
    {
        try
        {
            new ToastContentBuilder()
                .AddText(title)
                .AddText(message)
                .AddAttributionText("Matrix Shader")
                .Show();
        }
        catch
        {
            // Fail silently
        }
    }

    /// <summary>
    /// Uninstalls toast notification registration for non-packaged apps.
    /// Should be called during application shutdown to clean up.
    /// </summary>
    public static void Cleanup()
    {
        try
        {
            // For non-packaged apps, uninstall removes the AUMID registration
            // and clears any pending notifications
            ToastNotificationManagerCompat.Uninstall();
        }
        catch
        {
            // Fail silently - cleanup is best-effort
        }
    }

    /// <summary>
    /// Checks if toast notifications are supported on this system.
    /// Requires Windows 10 version 1809 or later.
    /// </summary>
    public static bool IsSupported()
    {
        try
        {
            // Try to create a builder - if this fails, toasts aren't supported
            _ = new ToastContentBuilder();
            return true;
        }
        catch
        {
            return false;
        }
    }
}
