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
    private readonly Dictionary<string, int> _overflowCounters = new();
    private readonly Dictionary<string, int> _underflowCounters = new();
    private readonly Dictionary<string, int> _baseOpacity = new();

    // OSD overlay for opacity toast (set after message loop thread creation)
    private OsdOverlay? _osdOverlay;

    /// <summary>
    /// Sets the OSD overlay for displaying opacity toast messages.
    /// Must be called after OsdOverlay is created on the message loop thread.
    /// </summary>
    public void SetOsd(OsdOverlay osd) => _osdOverlay = osd;

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
                .Where(w => !w.IsControlPanel && !w.IsConstruct && !WindowsApi.IsZoomed(w.Handle))
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
                .Where(w => !w.IsControlPanel && !w.IsConstruct && !WindowsApi.IsZoomed(w.Handle))
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
                .Where(w => !w.IsControlPanel && !w.IsConstruct)
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

            // Determine uniform target opacity for Off and Full states.
            // Custom state uses per-window values (see below).
            int? uniformTarget = nextState switch
            {
                TransparencyState.Off => 100,
                TransparencyState.Full => 0,
                _ => null // Custom: per-window
            };

            // Apply to ALL Matrix windows
            // NOTE: Overflow/underflow counters are intentionally NOT reset here.
            // User decision: counters are preserved across toggle cycles.
            // Use surgical upsert to avoid corrupting non-Matrix profiles.
            var allSettings = _terminalSettingsService.LoadSettings();
            var profilesToUpsert = new List<TerminalProfile>();
            string logLabel = "?";

            foreach (var window in matrixWindows)
            {
                if (string.IsNullOrEmpty(window.ProfileName)) continue;

                var profile = _terminalSettingsService.GetProfile(allSettings, window.ProfileName);
                if (profile == null) continue;

                int perWindowOpacity;
                if (nextState == TransparencyState.Custom)
                {
                    // Per-window Custom restoration: each window returns to its own
                    // last-known custom opacity (mix+offset preserved)
                    perWindowOpacity = _customOpacity.TryGetValue(window.ProfileName, out var c) ? c : DefaultCustomOpacity;
                }
                else
                {
                    perWindowOpacity = uniformTarget!.Value;
                }

                var updatedProfile = profile with { Opacity = perWindowOpacity, UseAcrylic = false };
                profilesToUpsert.Add(updatedProfile);

                // Track state per profile
                _transparencyStates[window.ProfileName] = nextState;

                // Update base opacity so AdjustOpacity knows what we set
                _baseOpacity[window.ProfileName] = perWindowOpacity;

                if (nextState == TransparencyState.Custom && !_customOpacity.ContainsKey(window.ProfileName))
                    _customOpacity[window.ProfileName] = DefaultCustomOpacity;
            }
            if (profilesToUpsert.Count > 0)
                _terminalSettingsService.UpsertProfilesSurgical(profilesToUpsert);

            logLabel = nextState switch
            {
                TransparencyState.Off => "OFF (100%)",
                TransparencyState.Custom => "CUSTOM (per-window)",
                TransparencyState.Full => "FULL (0%)",
                _ => "?"
            };
            DiagnosticLogger.Debug("HOTKEYS", $"Transparency cycled to {logLabel} on {matrixWindows.Count} windows");

            // Show OSD toast for toggle state — Custom shows the actual per-window value
            var toastText = nextState switch
            {
                TransparencyState.Off => "100%",
                TransparencyState.Full => "0%",
                TransparencyState.Custom => $"{(_customOpacity.TryGetValue(firstProfile, out var cv) ? cv : DefaultCustomOpacity)}%",
                _ => null
            };
            if (toastText != null)
            {
                try
                {
                    var state = _configService.LoadState();
                    if (state.OsdToastEnabled)
                        _osdOverlay?.ShowToast(toastText);
                }
                catch { }
            }
        }
        catch (Exception ex)
        {
            DiagnosticLogger.ProductionError("HOTKEYS", $"ToggleTransparency failed: {ex.Message}");
        }
    }

    /// <summary>
    /// Decreases opacity of ALL Matrix windows' profiles by 5%.
    /// Uses TerminalSettingsService to modify terminal settings.
    /// </summary>
    private void OpacityDown()
    {
        try
        {
            _ = AdjustOpacity(-OpacityDelta);
        }
        catch (Exception ex)
        {
            DiagnosticLogger.ProductionError("HOTKEYS", $"OpacityDown failed: {ex.Message}");
        }
    }

    /// <summary>
    /// Increases opacity of ALL Matrix windows' profiles by 5%.
    /// Uses TerminalSettingsService to modify terminal settings.
    /// </summary>
    private void OpacityUp()
    {
        try
        {
            _ = AdjustOpacity(OpacityDelta);
        }
        catch (Exception ex)
        {
            DiagnosticLogger.ProductionError("HOTKEYS", $"OpacityUp failed: {ex.Message}");
        }
    }

    /// <summary>
    /// Adjusts opacity on ALL Matrix windows by the specified delta, with per-window
    /// overflow/underflow counters that preserve per-window opacity mixes.
    /// Returns the representative opacity percentage for OSD display, or null if all
    /// windows were capped in the push direction (no change, no save).
    /// </summary>
    private int? AdjustOpacity(int delta)
    {
        var matrixWindows = GetMatrixWindowsCached();
        if (matrixWindows.Count == 0)
            return null;

        DiagnosticLogger.Debug("HOTKEYS", $"AdjustOpacity({delta}): iterating {matrixWindows.Count} windows");

        bool allCapped = true;
        int? representativeOpacity = null;

        // Read current settings for opacity detection, but use surgical upsert for writes
        var allSettings = _terminalSettingsService.LoadSettings();
        var profilesToUpsert = new List<TerminalProfile>();

        foreach (var window in matrixWindows)
        {
            if (string.IsNullOrEmpty(window.ProfileName)) continue;

            var profile = _terminalSettingsService.GetProfile(allSettings, window.ProfileName);
            if (profile == null) continue;

            var profileName = window.ProfileName;
            int currentOpacity = profile.Opacity;

            // Detect Redpill base change: if current opacity differs from what we
            // last wrote, an external process (Redpill) changed it. Reset counters.
            if (_baseOpacity.TryGetValue(profileName, out var trackedBase) && trackedBase != currentOpacity)
            {
                DiagnosticLogger.Debug("HOTKEYS", $"AdjustOpacity: base change detected for {profileName}: tracked={trackedBase}, actual={currentOpacity} (Redpill?). Resetting counters.");
                _overflowCounters[profileName] = 0;
                _underflowCounters[profileName] = 0;
                _baseOpacity[profileName] = currentOpacity;
            }

            if (!_overflowCounters.TryGetValue(profileName, out var overflow))
                overflow = 0;
            if (!_underflowCounters.TryGetValue(profileName, out var underflow))
                underflow = 0;

            int newOpacity = currentOpacity;

            if (delta > 0) // Increasing opacity (K key)
            {
                if (underflow > 0)
                {
                    // Drain underflow by 1 keypress (not by OpacityDelta)
                    _underflowCounters[profileName] = underflow - 1;
                    // Opacity stays the same (draining virtual debt)
                    allCapped = false;
                }
                else if (currentOpacity < MaxOpacity)
                {
                    newOpacity = Math.Min(currentOpacity + OpacityDelta, MaxOpacity);
                    allCapped = false;
                }
                else
                {
                    // At ceiling, increment overflow by 1 keypress
                    _overflowCounters[profileName] = overflow + 1;
                    // allCapped stays true if ALL windows reach here
                }
            }
            else // Decreasing opacity (J key)
            {
                if (overflow > 0)
                {
                    // Drain overflow by 1 keypress (not by OpacityDelta)
                    _overflowCounters[profileName] = overflow - 1;
                    // Opacity stays the same (draining virtual debt)
                    allCapped = false;
                }
                else if (currentOpacity > MinOpacity)
                {
                    newOpacity = Math.Max(currentOpacity + delta, MinOpacity); // delta is negative
                    allCapped = false;
                }
                else
                {
                    // At floor, increment underflow by 1 keypress
                    _underflowCounters[profileName] = underflow + 1;
                    // allCapped stays true if ALL windows reach here
                }
            }

            if (newOpacity != currentOpacity)
            {
                var updatedProfile = profile with { Opacity = newOpacity };
                profilesToUpsert.Add(updatedProfile);
            }

            // Track what we set as the base for Redpill change detection
            _baseOpacity[profileName] = newOpacity;

            // Update custom opacity and transparency state for toggle cycle
            _customOpacity[profileName] = newOpacity;
            _transparencyStates[profileName] = TransparencyState.Custom;

            // Capture representative opacity from first non-capped window
            if (representativeOpacity == null && (newOpacity != currentOpacity || (delta > 0 && underflow > 0) || (delta < 0 && overflow > 0)))
                representativeOpacity = newOpacity;
        }

        // TRANS-04: If ALL windows were capped in the push direction,
        // skip save entirely (no flicker, no error, no unnecessary file write)
        if (allCapped)
        {
            DiagnosticLogger.Debug("HOTKEYS", "AdjustOpacity: all windows capped, skipping save");
            return null;
        }

        // Surgical upsert: only touches Matrix profiles, preserves non-Matrix profiles byte-for-byte
        if (profilesToUpsert.Count > 0)
            _terminalSettingsService.UpsertProfilesSurgical(profilesToUpsert);

        // If no representative was captured (e.g., all were draining counters),
        // fall back to first window's current opacity
        if (representativeOpacity == null)
        {
            representativeOpacity = matrixWindows[0].ProfileName is { } fpn
                ? _baseOpacity.TryGetValue(fpn, out var bo) ? bo : (int?)null
                : null;
        }

        DiagnosticLogger.Debug("HOTKEYS", $"AdjustOpacity: representative opacity = {representativeOpacity}%");

        // Show OSD toast if enabled (gated by OsdToastEnabled setting)
        if (representativeOpacity != null)
        {
            try
            {
                var state = _configService.LoadState();
                if (state.OsdToastEnabled)
                {
                    _osdOverlay?.ShowToast($"{representativeOpacity}%");
                }
            }
            catch
            {
                // Fail silently -- OSD is non-critical
            }
        }

        return representativeOpacity;
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
        if (identity == null || identity.IsControlPanel || identity.IsConstruct)
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
