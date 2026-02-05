# Phase 3: Windows API Layer - Research

**Researched:** 2026-01-26
**Domain:** Windows P/Invoke, Window Enumeration, Monitor Detection, Window Positioning
**Confidence:** HIGH

## Summary

Phase 3 provides the low-level Windows API infrastructure for window enumeration, monitor detection, and window positioning. The C# project already has a solid `WindowsApi.cs` foundation (344 lines) with `LibraryImport` source-generated P/Invoke. This phase focuses on **completing** the API layer with DWM border compensation, DPI awareness helpers, and ensuring all APIs are AOT-compatible.

Key findings:
- Existing `WindowsApi.cs` already implements core P/Invoke with modern `LibraryImport` attribute
- Windows 10/11 invisible borders require `DwmGetWindowAttribute(DWMWA_EXTENDED_FRAME_BOUNDS)` for pixel-perfect positioning
- The PowerShell reference uses `System.Windows.Forms.Screen` for monitors - C# can use the same or native `EnumDisplayMonitors`
- Native AOT requires `LibraryImport` (not `DllImport`) for callbacks to work reliably

**Primary recommendation:** Extend `WindowsApi.cs` with DWM functions for border compensation, enhance monitor detection with DPI support, and add helper methods that match PowerShell behavior exactly.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| user32.dll | System | Window enumeration, positioning, monitor info | Windows API - no alternative |
| dwmapi.dll | System | Desktop Window Manager - border bounds | Required for Windows 10/11 invisible borders |
| shcore.dll | System | DPI awareness functions | Per-monitor DPI support (Windows 8.1+) |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| System.Windows.Forms | .NET 8 | `Screen` class for monitor detection | Simpler alternative to raw P/Invoke |
| System.Drawing | .NET 8 | Rectangle structures | Geometry helpers |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Raw P/Invoke | CsWin32 source generator | Adds dependency, reduces control |
| EnumDisplayMonitors | System.Windows.Forms.Screen | Forms is simpler but pulls in Windows Forms assembly |
| Manual delegates | Function pointers + UnmanagedCallersOnly | More complex, not needed for our callback patterns |

**Installation:**
```xml
<!-- Already in project -->
<PackageReference Include="System.Text.Json" />
<!-- No additional packages needed - all Windows APIs are P/Invoke -->
```

## Architecture Patterns

### Recommended Project Structure
```
MatrixShader.Core/
├── Native/
│   └── WindowsApi.cs          # Extended with DWM, DPI functions
├── Models/
│   ├── WindowInfo.cs          # Already exists
│   ├── MonitorInfo.cs         # Already exists
│   ├── WindowRect.cs          # Already exists
│   └── BorderMargins.cs       # NEW: Invisible border offsets
└── Services/
    └── ...                    # Phase 4+ consumes Native/
```

### Pattern 1: LibraryImport for AOT-Compatible P/Invoke
**What:** Use `[LibraryImport]` attribute with `partial` methods instead of `[DllImport]`
**When to use:** All new P/Invoke declarations
**Example:**
```csharp
// Source: Microsoft Learn - P/Invoke Source Generation
// https://learn.microsoft.com/en-us/dotnet/standard/native-interop/pinvoke-source-generation

[LibraryImport("dwmapi.dll")]
public static partial int DwmGetWindowAttribute(
    nint hwnd,
    int dwAttribute,
    out RECT pvAttribute,
    int cbAttribute);
```

### Pattern 2: Delegate-Based EnumWindows Callback
**What:** Use managed delegate for window enumeration callback
**When to use:** EnumWindows, EnumDisplayMonitors
**Example:**
```csharp
// Already implemented in WindowsApi.cs - this pattern works with LibraryImport
public delegate bool EnumWindowsProc(nint hWnd, nint lParam);

[LibraryImport("user32.dll")]
[return: MarshalAs(UnmanagedType.Bool)]
public static partial bool EnumWindows(EnumWindowsProc lpEnumFunc, nint lParam);

// Usage
public static List<nint> GetVisibleWindows()
{
    var windows = new List<nint>();
    EnumWindows((hWnd, _) =>
    {
        if (IsWindowVisible(hWnd))
            windows.Add(hWnd);
        return true;  // Continue enumeration
    }, nint.Zero);
    return windows;
}
```

### Pattern 3: Struct with LayoutKind.Sequential
**What:** Define native structures with explicit memory layout
**When to use:** All structures passed to/from Windows APIs
**Example:**
```csharp
// Already in WindowsApi.cs - this is correct
[StructLayout(LayoutKind.Sequential)]
public struct RECT
{
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct MONITORINFOEX
{
    public int cbSize;
    public RECT rcMonitor;
    public RECT rcWork;
    public uint dwFlags;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
    public string szDevice;
}
```

### Pattern 4: Factory Method for cbSize Initialization
**What:** Create structures with required size field pre-set
**When to use:** Any Windows structure with cbSize member
**Example:**
```csharp
// Already in WindowsApi.cs - good pattern
public static MONITORINFOEX Create()
{
    var mi = new MONITORINFOEX();
    mi.cbSize = Marshal.SizeOf<MONITORINFOEX>();
    return mi;
}
```

### Anti-Patterns to Avoid
- **DllImport for new code:** Use `LibraryImport` for AOT compatibility - DllImport generates IL stubs at runtime
- **StringBuilder in LibraryImport:** Use fixed buffers or `[MarshalAs(UnmanagedType.LPWStr)]` instead
- **Hardcoded border offsets:** Use `DwmGetWindowAttribute` to detect actual borders, not magic numbers
- **Ignoring DPI scaling:** Use `GetDpiForMonitor` or `GetDpiForWindow` when calculating positions

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Window border detection | Hardcoded 7px margins | DwmGetWindowAttribute(DWMWA_EXTENDED_FRAME_BOUNDS) | Borders vary by Windows version, theme, DWM state |
| Monitor working area | Manual taskbar detection | MONITORINFOEX.rcWork | Handles all docked windows, not just taskbar |
| DPI-aware coordinates | DIPs * scaling factor | GetDpiForMonitor + DPI-aware APIs | Windows handles complex multi-DPI scenarios |
| Process name lookup | File path parsing | Process.GetProcessById().ProcessName | Handles access rights, dead processes correctly |

**Key insight:** Windows 10/11 have "invisible borders" - 7px on left/right/bottom - that GetWindowRect includes but aren't visible. Use DwmGetWindowAttribute with DWMWA_EXTENDED_FRAME_BOUNDS to get actual visible bounds.

## Common Pitfalls

### Pitfall 1: GetWindowRect Returns Invisible Borders
**What goes wrong:** Windows positioned using GetWindowRect values appear to have gaps
**Why it happens:** Windows 10+ includes 7px invisible resize borders in GetWindowRect
**How to avoid:** Use DwmGetWindowAttribute(DWMWA_EXTENDED_FRAME_BOUNDS) to get visible bounds
**Warning signs:** 7-14px gaps between windows that should be touching

### Pitfall 2: DPI Mismatch Between Monitors
**What goes wrong:** Windows positioned correctly on primary monitor appear wrong on secondary
**Why it happens:** Each monitor can have different DPI scaling; coordinates are in device pixels
**How to avoid:** Use GetDpiForMonitor or GetDpiForWindow; calculate per-monitor
**Warning signs:** Windows too big/small on non-100% scaled monitors

### Pitfall 3: EnumDisplayMonitors Callback Crash
**What goes wrong:** Application crashes during monitor enumeration
**Why it happens:** Callback delegate gets garbage collected before enumeration completes
**How to avoid:** Keep delegate reference alive (local variable or field)
**Warning signs:** Access violation in user32.dll

### Pitfall 4: SetWindowPos Brings Window to Top
**What goes wrong:** Repositioned windows jump to foreground, stealing focus
**Why it happens:** Missing SWP_NOZORDER or SWP_NOACTIVATE flags
**How to avoid:** Always use `SWP_NOZORDER | SWP_NOACTIVATE` for repositioning
**Warning signs:** Focus changes when layout is applied

### Pitfall 5: Wrong Monitor for Window
**What goes wrong:** Window is positioned on wrong monitor
**Why it happens:** Working area coordinates are global (virtual screen), not per-monitor
**How to avoid:** Use monitor's rcWork.Left/Top as offset for window positions
**Warning signs:** Windows appear on unexpected monitors

## Code Examples

Verified patterns from official sources and existing codebase:

### DWM Border Compensation (NEW - to implement)
```csharp
// Source: Microsoft Learn - DWMWINDOWATTRIBUTE
// https://learn.microsoft.com/en-us/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute

private const int DWMWA_EXTENDED_FRAME_BOUNDS = 9;

[LibraryImport("dwmapi.dll")]
public static partial int DwmGetWindowAttribute(
    nint hwnd,
    int dwAttribute,
    out RECT pvAttribute,
    int cbAttribute);

/// <summary>
/// Gets the visible bounds of a window, excluding invisible borders.
/// Falls back to GetWindowRect if DWM is unavailable.
/// </summary>
public static WindowRect GetVisibleWindowBounds(nint hWnd)
{
    RECT visibleBounds;
    int hr = DwmGetWindowAttribute(
        hWnd,
        DWMWA_EXTENDED_FRAME_BOUNDS,
        out visibleBounds,
        Marshal.SizeOf<RECT>());

    if (hr == 0)  // S_OK
    {
        return visibleBounds.ToWindowRect();
    }

    // Fallback for DWM-disabled scenarios
    if (GetWindowRect(hWnd, out RECT rect))
    {
        return rect.ToWindowRect();
    }

    return WindowRect.Empty;
}

/// <summary>
/// Calculates the invisible border margins for a window.
/// </summary>
public static BorderMargins GetBorderMargins(nint hWnd)
{
    if (!GetWindowRect(hWnd, out RECT windowRect))
        return BorderMargins.Zero;

    RECT extendedRect;
    if (DwmGetWindowAttribute(hWnd, DWMWA_EXTENDED_FRAME_BOUNDS,
        out extendedRect, Marshal.SizeOf<RECT>()) != 0)
        return BorderMargins.Zero;

    return new BorderMargins
    {
        Left = extendedRect.Left - windowRect.Left,
        Top = extendedRect.Top - windowRect.Top,
        Right = windowRect.Right - extendedRect.Right,
        Bottom = windowRect.Bottom - extendedRect.Bottom
    };
}
```

### Monitor Detection with Working Area (existing + enhancement)
```csharp
// Source: Existing WindowsApi.cs + PowerShell WindowLayoutEngine.ps1

/// <summary>
/// Gets information about all connected monitors, sorted by primary first then left-to-right.
/// Matches PowerShell Get-ScreenTopology behavior.
/// </summary>
public static List<MonitorInfo> GetMonitors()
{
    var monitors = new List<MonitorInfo>();
    int index = 0;

    EnumDisplayMonitors(nint.Zero, nint.Zero,
        (nint hMonitor, nint hdcMonitor, ref RECT lprcMonitor, nint dwData) =>
    {
        var mi = MONITORINFOEX.Create();
        if (GetMonitorInfo(hMonitor, ref mi))
        {
            monitors.Add(new MonitorInfo
            {
                Handle = hMonitor,
                Index = index++,
                Bounds = mi.rcMonitor.ToWindowRect(),
                WorkArea = mi.rcWork.ToWindowRect(),  // Excludes taskbar
                IsPrimary = (mi.dwFlags & MONITORINFOF_PRIMARY) != 0,
                DeviceName = mi.szDevice
            });
        }
        return true;
    }, nint.Zero);

    // Sort: Primary first, then left-to-right (matches PowerShell)
    return monitors
        .OrderByDescending(m => m.IsPrimary)
        .ThenBy(m => m.WorkArea.Left)
        .Select((m, i) => m with { Index = i })
        .ToList();
}
```

### Window Positioning with Border Compensation (NEW - to implement)
```csharp
// Source: Context decisions - pixel-perfect positioning required

/// <summary>
/// Positions a window to exact pixel coordinates, compensating for invisible borders.
/// Preserves z-order (doesn't bring to top).
/// </summary>
public static bool PositionWindowExact(nint hWnd, WindowRect targetVisible)
{
    // Get current border margins
    var margins = GetBorderMargins(hWnd);

    // Expand target rect to account for invisible borders
    // The window rect needs to be larger than visible rect by the border amounts
    var windowRect = new WindowRect
    {
        Left = targetVisible.Left - margins.Left,
        Top = targetVisible.Top - margins.Top,
        Width = targetVisible.Width + margins.Left + margins.Right,
        Height = targetVisible.Height + margins.Top + margins.Bottom
    };

    return SetWindowPos(
        hWnd,
        nint.Zero,           // Don't change z-order
        windowRect.Left,
        windowRect.Top,
        windowRect.Width,
        windowRect.Height,
        SWP_NOZORDER | SWP_NOACTIVATE | SWP_SHOWWINDOW);
}
```

### Window Enumeration (existing pattern)
```csharp
// Source: Existing WindowsApi.cs - already correctly implemented

/// <summary>
/// Enumerates all visible top-level windows.
/// </summary>
public static List<nint> GetVisibleWindows()
{
    var windows = new List<nint>();
    EnumWindows((hWnd, _) =>
    {
        if (IsWindowVisible(hWnd) && !IsIconic(hWnd))
        {
            windows.Add(hWnd);
        }
        return true;
    }, nint.Zero);
    return windows;
}

/// <summary>
/// Enumerates ALL top-level windows including minimized (for Matrix window tracking).
/// Context decision: Include minimized windows in enumeration.
/// </summary>
public static List<nint> GetAllWindows()
{
    var windows = new List<nint>();
    EnumWindows((hWnd, _) =>
    {
        if (IsWindowVisible(hWnd))  // Note: IsWindowVisible returns true for minimized
        {
            windows.Add(hWnd);
        }
        return true;
    }, nint.Zero);
    return windows;
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| DllImport | LibraryImport | .NET 7 (2022) | AOT-compatible, source-generated marshalling |
| System DPI | Per-Monitor V2 DPI | Windows 10 1703 | Better multi-monitor support |
| GetWindowRect only | DwmGetWindowAttribute | Windows Vista | Accurate visible bounds |
| Manual border offsets | DWMWA_EXTENDED_FRAME_BOUNDS | Windows 10 | Handles version/theme variations |

**Deprecated/outdated:**
- `DllImport` for new code: Use `LibraryImport` for AOT compatibility
- `SetProcessDPIAware()`: Use Per-Monitor V2 via manifest or `SetProcessDpiAwarenessContext`
- Hardcoded 7px borders: Windows 11 can have different borders; use DWM detection

## Open Questions

Things that couldn't be fully resolved:

1. **DPI handling approach**
   - What we know: PowerShell uses System.Windows.Forms.Screen.WorkingArea which is DPI-aware
   - What's unclear: Whether C# EnumDisplayMonitors returns raw or scaled coordinates
   - Recommendation: Match PowerShell behavior - test with multi-DPI setup, add GetDpiForMonitor if needed

2. **DWM availability**
   - What we know: DWM is always enabled on Windows 10+, but can fail on remote desktop
   - What's unclear: Behavior when DWM composition is off (rare edge case)
   - Recommendation: Fallback to GetWindowRect with 7px default margins if DwmGetWindowAttribute fails

3. **Virtual desktop support**
   - What we know: PowerShell doesn't explicitly handle virtual desktops
   - What's unclear: Whether EnumWindows returns windows from all virtual desktops
   - Recommendation: Follow PowerShell behavior (enumerate visible windows, let Phase 4 filter)

## Sources

### Primary (HIGH confidence)
- [Microsoft Learn: P/Invoke Source Generation](https://learn.microsoft.com/en-us/dotnet/standard/native-interop/pinvoke-source-generation) - LibraryImport usage
- [Microsoft Learn: Native AOT Interop](https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/interop) - AOT P/Invoke requirements
- [Microsoft Learn: DWMWINDOWATTRIBUTE](https://learn.microsoft.com/en-us/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute) - DWM API constants
- [Microsoft Learn: EnumDisplayMonitors](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-enumdisplaymonitors) - Monitor enumeration
- [Microsoft Learn: SetWindowPos](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowpos) - Window positioning
- Existing `WindowsApi.cs` (344 lines) - Reference implementation
- Existing `WindowLayoutEngine.ps1` (1046 lines) - PowerShell reference

### Secondary (MEDIUM confidence)
- [Cyotek: Getting Window Rectangle Without Drop Shadow](https://www.cyotek.com/blog/getting-a-window-rectangle-without-the-drop-shadow) - Border compensation pattern
- [pinvoke.net: SetWindowPos](https://pinvoke.net/default.aspx/user32.SetWindowPos) - Flag definitions
- [developers.de: Enumerating Monitors in C#](https://developers.de/2023/03/08/enumerating-monitors-on-windows-in-c/) - Monitor enumeration pattern

### Tertiary (LOW confidence)
- Community discussions about Windows 11 border changes - unverified, may need testing

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Windows APIs are well-documented, existing code uses correct patterns
- Architecture: HIGH - Existing WindowsApi.cs provides proven patterns to extend
- Pitfalls: HIGH - Border/DPI issues are widely documented with known solutions

**Research date:** 2026-01-26
**Valid until:** 90 days (stable Windows APIs, unlikely to change)
