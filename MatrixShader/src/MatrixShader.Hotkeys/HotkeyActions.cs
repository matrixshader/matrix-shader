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
    private const float SpeedDelta = 0.5f;
    private const float MinSpeed = 0.1f;
    private const float MaxSpeed = 5.0f;

    // Opacity adjustment constants
    private const int OpacityDelta = 5;
    private const int MinOpacity = 0;
    private const int MaxOpacity = 100;
    private const int DefaultCustomOpacity = 85;

    // Transparency cycle: Off (100%) → Custom (slider value) → Full (0%)
    private enum TransparencyState { Off, Custom, Full }
    private readonly Dictionary<string, TransparencyState> _transparencyStates = new();
    private readonly Dictionary<string, int> _customOpacity = new();

    // Cache FindMatrixWindows result — identity resolution is expensive
    private IReadOnlyList<WindowInfo>? _cachedMatrixWindows;
    private DateTime _cacheExpiry = DateTime.MinValue;
    private static readonly TimeSpan CacheTtl = TimeSpan.FromSeconds(3);

    private IReadOnlyList<WindowInfo> GetMatrixWindowsCached()
    {
        if (_cachedMatrixWindows != null && DateTime.UtcNow < _cacheExpiry)
            return _cachedMatrixWindows;

        _cachedMatrixWindows = _identityService.FindMatrixWindows();
        _cacheExpiry = DateTime.UtcNow + CacheTtl;
        return _cachedMatrixWindows;
    }

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
        HotkeyAction.ShowHelp => ShowHelpOverlay,
        HotkeyAction.ManualReload => ManualReload,
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
            MatrixWindowMonitor.UpdateTruth(windows[currentIdx].Handle, targetPos);

            // Shift windows between target and current
            for (int i = targetIdx; i != currentIdx; i = (i + 1) % windows.Count)
            {
                var nextIdx = (i + 1) % windows.Count;
                if (nextIdx == currentIdx)
                {
                    // Last window in chain moves to original current position
                    WindowsApi.PositionWindowExact(windows[i].Handle, currentPos);
                    MatrixWindowMonitor.UpdateTruth(windows[i].Handle, currentPos);
                    break;
                }
                WindowsApi.PositionWindowExact(windows[i].Handle, windows[nextIdx].Position);
                MatrixWindowMonitor.UpdateTruth(windows[i].Handle, windows[nextIdx].Position);
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
            MatrixWindowMonitor.UpdateTruth(windows[currentIdx].Handle, targetPos);

            // Shift windows between current and target to the left
            for (int i = targetIdx; i != currentIdx; i = (i - 1 + windows.Count) % windows.Count)
            {
                var prevIdx = (i - 1 + windows.Count) % windows.Count;
                if (prevIdx == currentIdx)
                {
                    WindowsApi.PositionWindowExact(windows[i].Handle, currentPos);
                    MatrixWindowMonitor.UpdateTruth(windows[i].Handle, currentPos);
                    break;
                }
                WindowsApi.PositionWindowExact(windows[prevIdx].Handle, windows[i].Position);
                MatrixWindowMonitor.UpdateTruth(windows[prevIdx].Handle, windows[i].Position);
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
    /// Cycles transparency on ALL Matrix windows through 3 states:
    /// Off (100%) → Custom (slider %) → Full transparent (0%).
    /// </summary>
    private void ToggleTransparency()
    {
        try
        {
            var matrixWindows = GetMatrixWindowsCached();
            if (matrixWindows.Count == 0)
                return;

            // Use first window's profile to determine current state
            var firstProfile = matrixWindows[0].ProfileName;
            if (string.IsNullOrEmpty(firstProfile))
                return;

            // Determine current state from first window
            if (!_transparencyStates.TryGetValue(firstProfile, out var currentState))
            {
                // First use — read from terminal to figure out where we are
                var settings = _terminalSettingsService.LoadSettings();
                var profile = _terminalSettingsService.GetProfile(settings, firstProfile);
                if (profile == null) return;

                if (profile.Opacity >= 100)
                    currentState = TransparencyState.Off;
                else if (profile.Opacity <= 0)
                    currentState = TransparencyState.Full;
                else
                {
                    currentState = TransparencyState.Custom;
                    _customOpacity[firstProfile] = profile.Opacity;
                }
            }

            // Advance to next state
            var nextState = currentState switch
            {
                TransparencyState.Off => TransparencyState.Custom,
                TransparencyState.Custom => TransparencyState.Full,
                TransparencyState.Full => TransparencyState.Off,
                _ => TransparencyState.Off
            };

            // Determine target opacity
            int targetOpacity = nextState switch
            {
                TransparencyState.Off => 100,
                TransparencyState.Custom => _customOpacity.TryGetValue(firstProfile, out var c) ? c : DefaultCustomOpacity,
                TransparencyState.Full => 0,
                _ => 100
            };

            // Apply to ALL Matrix windows
            var allSettings = _terminalSettingsService.LoadSettings();
            foreach (var window in matrixWindows)
            {
                if (string.IsNullOrEmpty(window.ProfileName)) continue;

                var profile = _terminalSettingsService.GetProfile(allSettings, window.ProfileName);
                if (profile == null) continue;

                var updatedProfile = profile with { Opacity = targetOpacity, UseAcrylic = false };
                _terminalSettingsService.UpsertProfile(allSettings, updatedProfile);

                // Track state per profile
                _transparencyStates[window.ProfileName] = nextState;
                if (nextState == TransparencyState.Custom && !_customOpacity.ContainsKey(window.ProfileName))
                    _customOpacity[window.ProfileName] = DefaultCustomOpacity;
            }
            _terminalSettingsService.SaveSettings(allSettings);

            var label = nextState switch
            {
                TransparencyState.Off => "OFF (100%)",
                TransparencyState.Custom => $"CUSTOM ({targetOpacity}%)",
                TransparencyState.Full => "FULL (0%)",
                _ => "?"
            };
            DiagnosticLogger.Debug("HOTKEYS", $"Transparency cycled to {label} on {matrixWindows.Count} windows");
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
    /// Adjusts opacity by the specified delta. Also remembers the value as the custom opacity
    /// so the transparency toggle cycle (Off → Custom → Full) uses whatever the user set.
    /// </summary>
    private void AdjustOpacity(int delta)
    {
        var focusedWindow = GetFocusedMatrixWindow();
        DiagnosticLogger.Debug("HOTKEYS", $"AdjustOpacity({delta}): focused = {(focusedWindow == null ? "null" : $"shader={focusedWindow.ShaderIndex}, profile={focusedWindow.ProfileName}")}");
        if (focusedWindow == null || string.IsNullOrEmpty(focusedWindow.ProfileName))
            return;

        var settings = _terminalSettingsService.LoadSettings();
        var profile = _terminalSettingsService.GetProfile(settings, focusedWindow.ProfileName);

        if (profile == null)
        {
            DiagnosticLogger.Debug("HOTKEYS", $"AdjustOpacity: profile '{focusedWindow.ProfileName}' not found");
            return;
        }

        // Clamp opacity to valid range
        var newOpacity = Math.Clamp(profile.Opacity + delta, MinOpacity, MaxOpacity);
        var updatedProfile = profile with { Opacity = newOpacity };

        _terminalSettingsService.UpsertProfile(settings, updatedProfile);
        _terminalSettingsService.SaveSettings(settings);

        // Remember as custom opacity for the toggle cycle
        _customOpacity[focusedWindow.ProfileName] = newOpacity;
        _transparencyStates[focusedWindow.ProfileName] = TransparencyState.Custom;

        DiagnosticLogger.Debug("HOTKEYS", $"AdjustOpacity: {profile.Opacity}% -> {newOpacity}% for {focusedWindow.ProfileName}");
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
        DiagnosticLogger.Debug("HOTKEYS", $"AdjustSpeed({delta}): focused window = {(focusedWindow == null ? "null" : $"shader={focusedWindow.ShaderIndex}, profile={focusedWindow.ProfileName}")}");
        if (focusedWindow == null || focusedWindow.ShaderIndex < 1)
            return;

        var shaderIndex = focusedWindow.ShaderIndex;

        // Read current config, modify, write back
        var config = _shaderService.ReadConfig(shaderIndex);
        var newSpeed = Math.Clamp(config.Speed + delta, MinSpeed, MaxSpeed);
        var updatedConfig = config with { Speed = newSpeed };

        _shaderService.WriteConfig(shaderIndex, updatedConfig);
        _terminalSettingsService.ForceShaderReload();

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
        _terminalSettingsService.ForceShaderReload();

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

    #region Help Overlay

    /// <summary>
    /// Shows the hotkey help overlay in a new console window.
    /// </summary>
    private void ShowHelpOverlay()
    {
        try
        {
            HotkeyHelpOverlay.SpawnOverlay();
        }
        catch (Exception ex)
        {
            DiagnosticLogger.ProductionError("HOTKEYS", $"ShowHelp failed: {ex.Message}");
        }
    }

    #endregion

    #region Manual Reload

    /// <summary>
    /// Forces Windows Terminal to reload all shaders by re-saving settings.json.
    /// Backup for when WT's shader file watcher doesn't detect changes.
    /// </summary>
    private void ManualReload()
    {
        try
        {
            _terminalSettingsService.ForceShaderReload();
            DiagnosticLogger.Debug("HOTKEYS", "Manual shader reload triggered");
        }
        catch (Exception ex)
        {
            DiagnosticLogger.ProductionError("HOTKEYS", $"ManualReload failed: {ex.Message}");
        }
    }

    #endregion

    #region Helper Methods

    /// <summary>
    /// Gets the currently focused Matrix window (excluding control panel).
    /// Returns null if no Matrix window is focused.
    /// </summary>
    // Cache resolved identities per window handle to avoid repeated identity resolution
    private nint _cachedFocusedHandle;
    private WindowInfo? _cachedFocusedIdentity;
    private DateTime _focusedCacheExpiry = DateTime.MinValue;

    private WindowInfo? GetFocusedMatrixWindow()
    {
        var foreground = WindowsApi.GetForegroundWindow();
        if (foreground == nint.Zero)
            return null;

        // Reuse cached identity if same handle and cache is fresh
        if (foreground == _cachedFocusedHandle && DateTime.UtcNow < _focusedCacheExpiry && _cachedFocusedIdentity != null)
            return _cachedFocusedIdentity;

        var identity = _identityService.ResolveIdentity(foreground);
        if (identity == null || identity.IsControlPanel)
        {
            _cachedFocusedHandle = nint.Zero;
            _cachedFocusedIdentity = null;
            return null;
        }

        _cachedFocusedHandle = foreground;
        _cachedFocusedIdentity = identity;
        _focusedCacheExpiry = DateTime.UtcNow + CacheTtl;
        return identity;
    }

    #endregion
}
