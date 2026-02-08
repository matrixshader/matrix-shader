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
        HotkeyAction.SwapLeft => RotateLeft,
        HotkeyAction.SwapRight => RotateRight,
        HotkeyAction.CycleLayout => CycleLayout,
        HotkeyAction.ToggleTransparency => ToggleTransparency,
        HotkeyAction.OpacityDown => OpacityDown,
        HotkeyAction.OpacityUp => OpacityUp,
        // CycleShader removed - corrupts shader parameters, per user decision
        HotkeyAction.SpeedUp => SpeedUp,
        HotkeyAction.SpeedDown => SpeedDown,
        HotkeyAction.ToggleFar => ToggleFar,
        HotkeyAction.ToggleMid => ToggleMid,
        HotkeyAction.ToggleNear => ToggleNear,
        _ => () => { } // Unknown action - do nothing
    };

    #region Window Actions (RotateLeft, RotateRight, CycleLayout)

    /// <summary>
    /// Rotates the focused Matrix window to the left position.
    /// Windows cycle: 1->4->3->2->1 (moving left wraps around)
    /// Fullscreen windows are excluded from rotation.
    /// </summary>
    private void RotateLeft()
    {
        try
        {
            // Pause Glitch so it doesn't fight with manual rotation
            MatrixWindowMonitor.PauseGlitch();

            // Get tiled windows (exclude fullscreen)
            var windows = _identityService.FindMatrixWindows()
                .Where(w => !w.IsControlPanel && !WindowsApi.IsZoomed(w.Handle))
                .OrderBy(w => w.Position.Left)
                .ToList();

            if (windows.Count < 2)
                return;

            var foreground = WindowsApi.GetForegroundWindow();
            var currentIdx = windows.FindIndex(w => w.Handle == foreground);

            if (currentIdx < 0)
                return; // Focused window not in Matrix windows

            // Calculate target position (one to the left, wrap to end)
            var targetIdx = (currentIdx - 1 + windows.Count) % windows.Count;

            // Get target position
            var targetPos = windows[targetIdx].Position;

            // Shift all windows between target and current to the right
            // This creates the rotation effect
            var currentPos = windows[currentIdx].Position;

            // Move focused window to target position
            WindowsApi.PositionWindowExact(windows[currentIdx].Handle, targetPos);

            // Shift windows between target and current
            for (int i = targetIdx; i != currentIdx; i = (i + 1) % windows.Count)
            {
                var nextIdx = (i + 1) % windows.Count;
                if (nextIdx == currentIdx)
                {
                    // Last window in chain moves to original current position
                    WindowsApi.PositionWindowExact(windows[i].Handle, currentPos);
                    break;
                }
                WindowsApi.PositionWindowExact(windows[i].Handle, windows[nextIdx].Position);
            }
        }
        catch (Exception ex)
        {
            DiagnosticLogger.ProductionError("HOTKEYS", $"RotateLeft failed: {ex.Message}");
        }
    }

    /// <summary>
    /// Rotates the focused Matrix window to the right position.
    /// Windows cycle: 1->2->3->4->1 (moving right wraps around)
    /// Fullscreen windows are excluded from rotation.
    /// </summary>
    private void RotateRight()
    {
        try
        {
            // Pause Glitch so it doesn't fight with manual rotation
            MatrixWindowMonitor.PauseGlitch();

            // Get tiled windows (exclude fullscreen)
            var windows = _identityService.FindMatrixWindows()
                .Where(w => !w.IsControlPanel && !WindowsApi.IsZoomed(w.Handle))
                .OrderBy(w => w.Position.Left)
                .ToList();

            if (windows.Count < 2)
                return;

            var foreground = WindowsApi.GetForegroundWindow();
            var currentIdx = windows.FindIndex(w => w.Handle == foreground);

            if (currentIdx < 0)
                return;

            // Calculate target position (one to the right, wrap to start)
            var targetIdx = (currentIdx + 1) % windows.Count;

            var targetPos = windows[targetIdx].Position;
            var currentPos = windows[currentIdx].Position;

            // Move focused window to target position
            WindowsApi.PositionWindowExact(windows[currentIdx].Handle, targetPos);

            // Shift windows between current and target to the left
            for (int i = targetIdx; i != currentIdx; i = (i - 1 + windows.Count) % windows.Count)
            {
                var prevIdx = (i - 1 + windows.Count) % windows.Count;
                if (prevIdx == currentIdx)
                {
                    WindowsApi.PositionWindowExact(windows[i].Handle, currentPos);
                    break;
                }
                WindowsApi.PositionWindowExact(windows[prevIdx].Handle, windows[i].Position);
            }
        }
        catch (Exception ex)
        {
            DiagnosticLogger.ProductionError("HOTKEYS", $"RotateRight failed: {ex.Message}");
        }
    }

    /// <summary>
    /// Cycles through layout modes (Pillars -> Quads -> Overlap -> Auto).
    /// Uses ConfigService for state and LayoutService to apply.
    /// </summary>
    private void CycleLayout()
    {
        try
        {
            // Pause Glitch so it doesn't fight with layout change
            MatrixWindowMonitor.PauseGlitch();

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
        catch (Exception ex)
        {
            DiagnosticLogger.ProductionError("HOTKEYS", $"CycleLayout failed: {ex.Message}");
        }
    }

    #endregion

    #region Terminal Settings Actions (ToggleTransparency, OpacityUp/Down)

    /// <summary>
    /// Toggles transparency on the focused Matrix window's profile.
    /// Switches between opaque (100%) and transparent (85%).
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

            // Toggle between opaque (100) and transparent (85)
            // Keep UseAcrylic = false to avoid frosted glass effect
            var currentOpacity = profile.Opacity;
            var newOpacity = currentOpacity >= 100 ? 85 : 100;
            var updatedProfile = profile with { Opacity = newOpacity, UseAcrylic = false };
            _terminalSettingsService.UpsertProfile(settings, updatedProfile);
            _terminalSettingsService.SaveSettings(settings);

            DiagnosticLogger.Debug("HOTKEYS", $"Toggled transparency: {currentOpacity}% -> {newOpacity}%");
        }
        catch (Exception ex)
        {
            DiagnosticLogger.ProductionError("HOTKEYS", $"ToggleTransparency failed: {ex.Message}");
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
        catch (Exception ex)
        {
            DiagnosticLogger.ProductionError("HOTKEYS", $"OpacityDown failed: {ex.Message}");
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
        catch (Exception ex)
        {
            DiagnosticLogger.ProductionError("HOTKEYS", $"OpacityUp failed: {ex.Message}");
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

    // CycleShader and GetNextShaderIndex REMOVED
    // Reason: Shader cycling corrupts shader colors/parameters. Shaders only differ by color anyway.
    // Decision: User requested removal (BUG-SHADER04, BUG-SHADER05)

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
        catch (Exception ex)
        {
            DiagnosticLogger.ProductionError("HOTKEYS", $"SpeedUp failed: {ex.Message}");
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
        catch (Exception ex)
        {
            DiagnosticLogger.ProductionError("HOTKEYS", $"SpeedDown failed: {ex.Message}");
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
        catch (Exception ex)
        {
            DiagnosticLogger.ProductionError("HOTKEYS", $"ToggleFar failed: {ex.Message}");
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
        catch (Exception ex)
        {
            DiagnosticLogger.ProductionError("HOTKEYS", $"ToggleMid failed: {ex.Message}");
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
        catch (Exception ex)
        {
            DiagnosticLogger.ProductionError("HOTKEYS", $"ToggleNear failed: {ex.Message}");
        }
    }

    /// <summary>
    /// Toggles a layer using the provided update function.
    /// </summary>
    private void ToggleLayer(Func<ShaderConfig, ShaderConfig> updateFunc)
    {
        var focusedWindow = GetFocusedMatrixWindow();
        DiagnosticLogger.Debug("HOTKEYS", $"ToggleLayer called for window shader index: {focusedWindow?.ShaderIndex ?? -1}");

        if (focusedWindow == null || focusedWindow.ShaderIndex < 1)
        {
            DiagnosticLogger.Debug("HOTKEYS", "ToggleLayer: No valid focused window found, returning");
            return;
        }

        var shaderIndex = focusedWindow.ShaderIndex;

        // Read current config, apply toggle, write back
        var config = _shaderService.ReadConfig(shaderIndex);
        var updatedConfig = updateFunc(config);

        DiagnosticLogger.Debug("HOTKEYS", $"ToggleLayer: Writing config for shader {shaderIndex}, Layer1={updatedConfig.Layer1}, Layer2={updatedConfig.Layer2}, Layer3={updatedConfig.Layer3}");
        _shaderService.WriteConfig(shaderIndex, updatedConfig);

        // Also update state for persistence
        var state = _configService.LoadState();
        if (state.ShaderConfigs.ContainsKey(shaderIndex))
        {
            state.ShaderConfigs[shaderIndex] = updatedConfig;
            _configService.SaveState(state);
            DiagnosticLogger.Debug("HOTKEYS", $"ToggleLayer: State saved for shader {shaderIndex}");
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
