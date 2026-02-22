using MatrixShader.Core.Models;
using MatrixShader.Core.Services;

namespace MatrixShader.Cli.Redpill;

/// <summary>
/// Manages tab state, dirty tracking, and auto-save for the control panel.
/// Tab cycles through OPEN windows only, matching PowerShell behavior.
/// </summary>
public class TabManager
{
    private readonly IShaderService _shaderService;
    private readonly IIdentityService _identityService;
    private readonly IConfigService _configService;
    private readonly ITerminalSettingsService _terminalSettingsService;

    private int _currentSlot;
    private ShaderConfig _currentConfig;
    private bool _dirty;

    public TabManager(
        IShaderService shaderService,
        IIdentityService identityService,
        IConfigService configService,
        ITerminalSettingsService terminalSettingsService)
    {
        _shaderService = shaderService;
        _identityService = identityService;
        _configService = configService;
        _terminalSettingsService = terminalSettingsService;

        // Initialize from state or first open window
        var state = _configService.LoadState();
        var openWindows = _identityService.FindMatrixWindows();

        if (openWindows.Count > 0)
        {
            // Use first open window slot
            _currentSlot = openWindows[0].ShaderIndex;
        }
        else if (state.ActiveTab > 0)
        {
            _currentSlot = state.ActiveTab;
        }
        else
        {
            _currentSlot = 1; // Fallback
        }

        _currentConfig = _shaderService.ShaderExists(_currentSlot)
            ? _shaderService.ReadConfig(_currentSlot)
            : new ShaderConfig();
        _dirty = false;

        // Sync ALL open window tab colors from actual shader configs at startup
        SyncAllTabColors(openWindows);
    }

    /// <summary>Current active slot (1-8)</summary>
    public int CurrentSlot => _currentSlot;

    /// <summary>Current shader configuration</summary>
    public ShaderConfig CurrentConfig => _currentConfig;

    /// <summary>Whether current config has unsaved changes</summary>
    public bool IsDirty => _dirty;

    /// <summary>Mark config as having unsaved changes</summary>
    public void MarkDirty() => _dirty = true;

    /// <summary>Mark config as saved (clear dirty)</summary>
    public void MarkClean() => _dirty = false;

    /// <summary>
    /// Gets tabs info for rendering (slot + color from each open window).
    /// </summary>
    public IReadOnlyList<(int slot, float r, float g, float b)> GetTabsForRendering()
    {
        var windows = _identityService.FindMatrixWindows();
        var tabs = new List<(int slot, float r, float g, float b)>();

        foreach (var win in windows)
        {
            var cfg = _shaderService.ShaderExists(win.ShaderIndex)
                ? _shaderService.ReadConfig(win.ShaderIndex)
                : new ShaderConfig();
            tabs.Add((win.ShaderIndex, cfg.R, cfg.G, cfg.B));
        }

        return tabs;
    }

    /// <summary>
    /// Switches to next open tab. Auto-saves current if dirty.
    /// Cycles through OPEN windows only, not all 8 slots.
    /// </summary>
    /// <returns>True if switched, false if no open windows</returns>
    public bool SwitchToNextTab()
    {
        // Auto-save before switching
        if (_dirty)
        {
            SaveCurrentShader();
        }

        var openWindows = _identityService.FindMatrixWindows();
        if (openWindows.Count == 0)
        {
            return false;
        }

        // Find current index in open windows
        var currentIndex = -1;
        for (int i = 0; i < openWindows.Count; i++)
        {
            if (openWindows[i].ShaderIndex == _currentSlot)
            {
                currentIndex = i;
                break;
            }
        }

        // If current slot not in open windows, go to first
        if (currentIndex < 0)
        {
            currentIndex = 0;
        }
        else
        {
            // Cycle to next
            currentIndex = (currentIndex + 1) % openWindows.Count;
        }

        _currentSlot = openWindows[currentIndex].ShaderIndex;
        _currentConfig = _shaderService.ShaderExists(_currentSlot)
            ? _shaderService.ReadConfig(_currentSlot)
            : new ShaderConfig();
        _dirty = false;

        return true;
    }

    /// <summary>
    /// Updates current config and writes to shader file immediately.
    /// </summary>
    public void UpdateConfig(ShaderConfig newConfig)
    {
        _currentConfig = newConfig.Clamp(); // Validate ranges
        _dirty = false; // No need for manual save - auto-applied

        // Write to shader file and force WT to reload it
        if (_shaderService.ShaderExists(_currentSlot))
        {
            _shaderService.WriteConfig(_currentSlot, _currentConfig);
            SyncTabColorToShader(_currentSlot, _currentConfig);
            _terminalSettingsService.ForceShaderReload();
        }
    }

    /// <summary>
    /// Saves current shader to file and syncs tab color.
    /// </summary>
    public void SaveCurrentShader()
    {
        if (_shaderService.ShaderExists(_currentSlot))
        {
            _shaderService.WriteConfig(_currentSlot, _currentConfig);
        }

        // Sync tab color to shader RGB
        SyncTabColorToShader(_currentSlot, _currentConfig);

        _dirty = false;
    }

    /// <summary>
    /// Syncs ALL open window tab colors from their actual shader configs.
    /// Called at startup to ensure tab colors always match shader rain colors.
    /// </summary>
    private void SyncAllTabColors(IReadOnlyList<WindowInfo> windows)
    {
        foreach (var window in windows)
        {
            if (_shaderService.ShaderExists(window.ShaderIndex))
            {
                var cfg = _shaderService.ReadConfig(window.ShaderIndex);
                SyncTabColorToShader(window.ShaderIndex, cfg);
            }
        }
    }

    /// <summary>
    /// Syncs Windows Terminal tab color to match shader RGB values.
    /// </summary>
    private void SyncTabColorToShader(int slot, ShaderConfig config)
    {
        try
        {
            // Convert float RGB (0-1) to hex color (#RRGGBB)
            var r = (int)(config.R * 255);
            var g = (int)(config.G * 255);
            var b = (int)(config.B * 255);
            var hexColor = $"#{r:X2}{g:X2}{b:X2}";

            var settings = _terminalSettingsService.LoadSettings();
            var profileName = $"Matrix-{slot}";
            var profile = _terminalSettingsService.GetProfile(settings, profileName);

            if (profile != null)
            {
                var updatedProfile = profile with { TabColor = hexColor };
                _terminalSettingsService.UpsertProfile(settings, updatedProfile);
                _terminalSettingsService.SaveSettings(settings);
                DiagnosticLogger.Info("TABMANAGER", $"Synced tab color to {hexColor} for {profileName}");
            }
        }
        catch (Exception ex)
        {
            // Silent failure - tab color is nice-to-have
            DiagnosticLogger.Warn("TABMANAGER", $"Failed to sync tab color: {ex.Message}");
        }
    }

    /// <summary>
    /// Saves full state (active tab + all configs) to config service.
    /// </summary>
    public void SaveState()
    {
        var state = _configService.LoadState();
        var configs = new Dictionary<int, ShaderConfig>(state.ShaderConfigs)
        {
            [_currentSlot] = _currentConfig
        };
        state = state with { ActiveTab = _currentSlot, ShaderConfigs = configs };
        _configService.SaveState(state);
        _dirty = false;
    }
}
