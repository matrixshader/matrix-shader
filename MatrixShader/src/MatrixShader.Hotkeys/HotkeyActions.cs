using MatrixShader.Core.Models;
using MatrixShader.Core.Native;
using MatrixShader.Core.Services;

namespace MatrixShader.Hotkeys;

/// <summary>
/// Implements all 12 hotkey action handlers.
/// Each action integrates with existing Core services.
/// All actions fail silently on errors (per CONTEXT.md).
/// </summary>
public sealed class HotkeyActions
{
    private readonly IIdentityService _identityService;
    private readonly ILayoutService _layoutService;
    private readonly IConfigService _configService;
    private readonly IShaderService _shaderService;
    private readonly ITerminalSettingsService _terminalSettingsService;

    // Shader cycling constants
    private const int MinShaderIndex = 1;
    private const int MaxShaderIndex = 8;

    // Speed adjustment constants
    private const float SpeedDelta = 0.1f;
    private const float MinSpeed = 0.1f;
    private const float MaxSpeed = 3.0f;

    // Opacity adjustment constants
    private const int OpacityDelta = 5;
    private const int MinOpacity = 0;
    private const int MaxOpacity = 100;

    public HotkeyActions(
        IIdentityService identityService,
        ILayoutService layoutService,
        IConfigService configService,
        IShaderService shaderService,
        ITerminalSettingsService terminalSettingsService)
    {
        _identityService = identityService;
        _layoutService = layoutService;
        _configService = configService;
        _shaderService = shaderService;
        _terminalSettingsService = terminalSettingsService;
    }

    /// <summary>
    /// Gets the action handler for the specified hotkey action.
    /// Returns an Action that can be invoked when the hotkey is pressed.
    /// </summary>
    public Action GetHandler(HotkeyAction action) => action switch
    {
        HotkeyAction.SwapLeft => SwapLeft,
        HotkeyAction.SwapRight => SwapRight,
        HotkeyAction.CycleLayout => CycleLayout,
        HotkeyAction.ToggleTransparency => ToggleTransparency,
        HotkeyAction.OpacityDown => OpacityDown,
        HotkeyAction.OpacityUp => OpacityUp,
        HotkeyAction.CycleShader => CycleShader,
        HotkeyAction.SpeedUp => SpeedUp,
        HotkeyAction.SpeedDown => SpeedDown,
        HotkeyAction.ToggleFar => ToggleFar,
        HotkeyAction.ToggleMid => ToggleMid,
        HotkeyAction.ToggleNear => ToggleNear,
        _ => () => { } // Unknown action - do nothing
    };

    #region Window Actions (SwapLeft, SwapRight, CycleLayout)

    /// <summary>
    /// Swaps the focused Matrix window with the one to its left.
    /// Uses IdentityService to find windows and WindowsApi to reposition.
    /// </summary>
    private void SwapLeft()
    {
        try
        {
            var windows = _identityService.FindMatrixWindows()
                .Where(w => !w.IsControlPanel)
                .OrderBy(w => w.Position.Left)
                .ToList();

            if (windows.Count < 2)
                return;

            var foreground = WindowsApi.GetForegroundWindow();
            var currentIdx = windows.FindIndex(w => w.Handle == foreground);

            if (currentIdx <= 0)
                return; // Already leftmost or not found

            SwapWindowPositions(windows[currentIdx], windows[currentIdx - 1]);
        }
        catch
        {
            // Fail silently
        }
    }

    /// <summary>
    /// Swaps the focused Matrix window with the one to its right.
    /// Uses IdentityService to find windows and WindowsApi to reposition.
    /// </summary>
    private void SwapRight()
    {
        try
        {
            var windows = _identityService.FindMatrixWindows()
                .Where(w => !w.IsControlPanel)
                .OrderBy(w => w.Position.Left)
                .ToList();

            if (windows.Count < 2)
                return;

            var foreground = WindowsApi.GetForegroundWindow();
            var currentIdx = windows.FindIndex(w => w.Handle == foreground);

            if (currentIdx < 0 || currentIdx >= windows.Count - 1)
                return; // Already rightmost or not found

            SwapWindowPositions(windows[currentIdx], windows[currentIdx + 1]);
        }
        catch
        {
            // Fail silently
        }
    }

    /// <summary>
    /// Swaps positions of two windows.
    /// </summary>
    private static void SwapWindowPositions(WindowInfo window1, WindowInfo window2)
    {
        var pos1 = window1.Position;
        var pos2 = window2.Position;

        // Move window1 to window2's position
        WindowsApi.PositionWindowExact(window1.Handle, pos2);

        // Move window2 to window1's original position
        WindowsApi.PositionWindowExact(window2.Handle, pos1);
    }

    /// <summary>
    /// Cycles through layout modes (Pillars -> Quads -> Overlap -> Auto).
    /// Uses ConfigService for state and LayoutService to apply.
    /// </summary>
    private void CycleLayout()
    {
        try
        {
            var state = _configService.LoadState();
            var newConfig = _layoutService.CycleMode(state.Layout);

            // Update and save config
            _layoutService.UpdateConfig(newConfig);

            // Find windows and apply new layout
            var windows = _identityService.FindMatrixWindows()
                .Where(w => !w.IsControlPanel)
                .ToList();

            if (windows.Count == 0)
                return;

            var positions = _layoutService.CalculateLayout(windows, newConfig);
            _layoutService.ApplyLayout(positions);
        }
        catch
        {
            // Fail silently
        }
    }

    #endregion

    #region Terminal Settings Actions (ToggleTransparency, OpacityUp/Down, CycleShader)

    /// <summary>
    /// Toggles UseAcrylic on the focused Matrix window's profile.
    /// Uses TerminalSettingsService to modify terminal settings.
    /// </summary>
    private void ToggleTransparency()
    {
        try
        {
            var focusedWindow = GetFocusedMatrixWindow();
            if (focusedWindow == null || string.IsNullOrEmpty(focusedWindow.ProfileName))
                return;

            var settings = _terminalSettingsService.LoadSettings();
            var profile = _terminalSettingsService.GetProfile(settings, focusedWindow.ProfileName);

            if (profile == null)
                return;

            // Toggle UseAcrylic
            var updatedProfile = profile with { UseAcrylic = !profile.UseAcrylic };
            _terminalSettingsService.UpsertProfile(settings, updatedProfile);
            _terminalSettingsService.SaveSettings(settings);
        }
        catch
        {
            // Fail silently
        }
    }

    /// <summary>
    /// Decreases opacity of the focused Matrix window's profile by 5%.
    /// Uses TerminalSettingsService to modify terminal settings.
    /// </summary>
    private void OpacityDown()
    {
        try
        {
            AdjustOpacity(-OpacityDelta);
        }
        catch
        {
            // Fail silently
        }
    }

    /// <summary>
    /// Increases opacity of the focused Matrix window's profile by 5%.
    /// Uses TerminalSettingsService to modify terminal settings.
    /// </summary>
    private void OpacityUp()
    {
        try
        {
            AdjustOpacity(OpacityDelta);
        }
        catch
        {
            // Fail silently
        }
    }

    /// <summary>
    /// Adjusts opacity by the specified delta.
    /// </summary>
    private void AdjustOpacity(int delta)
    {
        var focusedWindow = GetFocusedMatrixWindow();
        if (focusedWindow == null || string.IsNullOrEmpty(focusedWindow.ProfileName))
            return;

        var settings = _terminalSettingsService.LoadSettings();
        var profile = _terminalSettingsService.GetProfile(settings, focusedWindow.ProfileName);

        if (profile == null)
            return;

        // Clamp opacity to valid range
        var newOpacity = Math.Clamp(profile.Opacity + delta, MinOpacity, MaxOpacity);
        var updatedProfile = profile with { Opacity = newOpacity };

        _terminalSettingsService.UpsertProfile(settings, updatedProfile);
        _terminalSettingsService.SaveSettings(settings);
    }

    /// <summary>
    /// Cycles through Matrix-1 to Matrix-8 shaders on the focused window.
    /// Uses TerminalSettingsService to update PixelShaderPath.
    /// </summary>
    private void CycleShader()
    {
        try
        {
            var focusedWindow = GetFocusedMatrixWindow();
            if (focusedWindow == null || string.IsNullOrEmpty(focusedWindow.ProfileName))
                return;

            var settings = _terminalSettingsService.LoadSettings();
            var profile = _terminalSettingsService.GetProfile(settings, focusedWindow.ProfileName);

            if (profile == null)
                return;

            // Determine next shader index
            var currentShaderPath = profile.PixelShaderPath ?? "";
            var nextIndex = GetNextShaderIndex(currentShaderPath);

            // Build new shader path (preserve directory, change filename)
            var directory = Path.GetDirectoryName(currentShaderPath) ?? "";
            var newShaderPath = Path.Combine(directory, $"Matrix-{nextIndex}.hlsl");

            var updatedProfile = profile with { PixelShaderPath = newShaderPath };
            _terminalSettingsService.UpsertProfile(settings, updatedProfile);
            _terminalSettingsService.SaveSettings(settings);
        }
        catch
        {
            // Fail silently
        }
    }

    /// <summary>
    /// Gets the next shader index from the current shader path.
    /// Cycles: 1 -> 2 -> ... -> 8 -> 1
    /// </summary>
    private static int GetNextShaderIndex(string shaderPath)
    {
        // Extract current index from path like "Matrix-3.hlsl"
        var filename = Path.GetFileNameWithoutExtension(shaderPath);
        if (string.IsNullOrEmpty(filename))
            return MinShaderIndex;

        // Try to parse "Matrix-N" format
        if (filename.StartsWith("Matrix-", StringComparison.OrdinalIgnoreCase) &&
            int.TryParse(filename.AsSpan(7), out var currentIndex))
        {
            // Cycle to next index (wrap 8 -> 1)
            return currentIndex >= MaxShaderIndex ? MinShaderIndex : currentIndex + 1;
        }

        return MinShaderIndex;
    }

    #endregion

    #region Shader Actions (SpeedUp/Down, ToggleFar/Mid/Near)

    /// <summary>
    /// Increases rain speed for the focused Matrix window's shader.
    /// Uses ConfigService and ShaderService.
    /// </summary>
    private void SpeedUp()
    {
        try
        {
            AdjustSpeed(SpeedDelta);
        }
        catch
        {
            // Fail silently
        }
    }

    /// <summary>
    /// Decreases rain speed for the focused Matrix window's shader.
    /// Uses ConfigService and ShaderService.
    /// </summary>
    private void SpeedDown()
    {
        try
        {
            AdjustSpeed(-SpeedDelta);
        }
        catch
        {
            // Fail silently
        }
    }

    /// <summary>
    /// Adjusts speed by the specified delta.
    /// </summary>
    private void AdjustSpeed(float delta)
    {
        var focusedWindow = GetFocusedMatrixWindow();
        if (focusedWindow == null || focusedWindow.ShaderIndex < 1)
            return;

        var shaderIndex = focusedWindow.ShaderIndex;

        // Read current config, modify, write back
        var config = _shaderService.ReadConfig(shaderIndex);
        var newSpeed = Math.Clamp(config.Speed + delta, MinSpeed, MaxSpeed);
        var updatedConfig = config with { Speed = newSpeed };

        _shaderService.WriteConfig(shaderIndex, updatedConfig);

        // Also update state for persistence
        var state = _configService.LoadState();
        if (state.ShaderConfigs.ContainsKey(shaderIndex))
        {
            state.ShaderConfigs[shaderIndex] = updatedConfig;
            _configService.SaveState(state);
        }
    }

    /// <summary>
    /// Toggles the far (background) layer on the focused Matrix window's shader.
    /// Uses ConfigService and ShaderService.
    /// </summary>
    private void ToggleFar()
    {
        try
        {
            ToggleLayer(c => c with { Layer1 = !c.Layer1 });
        }
        catch
        {
            // Fail silently
        }
    }

    /// <summary>
    /// Toggles the mid layer on the focused Matrix window's shader.
    /// Uses ConfigService and ShaderService.
    /// </summary>
    private void ToggleMid()
    {
        try
        {
            ToggleLayer(c => c with { Layer2 = !c.Layer2 });
        }
        catch
        {
            // Fail silently
        }
    }

    /// <summary>
    /// Toggles the near (foreground) layer on the focused Matrix window's shader.
    /// Uses ConfigService and ShaderService.
    /// </summary>
    private void ToggleNear()
    {
        try
        {
            ToggleLayer(c => c with { Layer3 = !c.Layer3 });
        }
        catch
        {
            // Fail silently
        }
    }

    /// <summary>
    /// Toggles a layer using the provided update function.
    /// </summary>
    private void ToggleLayer(Func<ShaderConfig, ShaderConfig> updateFunc)
    {
        var focusedWindow = GetFocusedMatrixWindow();
        if (focusedWindow == null || focusedWindow.ShaderIndex < 1)
            return;

        var shaderIndex = focusedWindow.ShaderIndex;

        // Read current config, apply toggle, write back
        var config = _shaderService.ReadConfig(shaderIndex);
        var updatedConfig = updateFunc(config);

        _shaderService.WriteConfig(shaderIndex, updatedConfig);

        // Also update state for persistence
        var state = _configService.LoadState();
        if (state.ShaderConfigs.ContainsKey(shaderIndex))
        {
            state.ShaderConfigs[shaderIndex] = updatedConfig;
            _configService.SaveState(state);
        }
    }

    #endregion

    #region Helper Methods

    /// <summary>
    /// Gets the currently focused Matrix window (excluding control panel).
    /// Returns null if no Matrix window is focused.
    /// </summary>
    private WindowInfo? GetFocusedMatrixWindow()
    {
        var foreground = WindowsApi.GetForegroundWindow();
        if (foreground == nint.Zero)
            return null;

        var identity = _identityService.ResolveIdentity(foreground);
        if (identity == null || identity.IsControlPanel)
            return null;

        return identity;
    }

    #endregion
}
