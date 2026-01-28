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

    private int _currentSlot;
    private ShaderConfig _currentConfig;
    private bool _dirty;

    public TabManager(
        IShaderService shaderService,
        IIdentityService identityService,
        IConfigService configService)
    {
        _shaderService = shaderService;
        _identityService = identityService;
        _configService = configService;

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
        _dirty = true;

        // Write to shader file immediately for hot-reload
        if (_shaderService.ShaderExists(_currentSlot))
        {
            _shaderService.WriteConfig(_currentSlot, _currentConfig);
        }
    }

    /// <summary>
    /// Saves current shader to file.
    /// </summary>
    public void SaveCurrentShader()
    {
        if (_shaderService.ShaderExists(_currentSlot))
        {
            _shaderService.WriteConfig(_currentSlot, _currentConfig);
        }
        _dirty = false;
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
