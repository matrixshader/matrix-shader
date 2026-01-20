# WindowIdentityService.ps1
# Unified window identity resolution for Matrix Terminal windows
# Implements 4-layer identity hierarchy: Launch Tracking -> Command Line -> Title -> UI Automation
#
# Performance target: 120ms for 6 windows (vs current 3000ms with UIAutomation)
# - Launch tracking: <1ms per window (instant lookup)
# - Command line: ~20ms per window (WMI batch query)
# - Title matching: ~5ms per window (EnumWindows)
# - UI Automation: 100-300ms per window (only if all else fails)

# --- MODULE-LEVEL STATE ---
$script:LaunchRegistry = @{}           # Runtime registry: @{ PID = @{ ProfileName, LaunchTime, CorrelationId } }
$script:IdentityServiceVerbose = $false
$script:IdentityLogFile = "$env:USERPROFILE\Documents\Matrix\identity_debug.log"
$script:IdentityRegistryPath = "$env:USERPROFILE\Documents\Matrix\identity-registry.json"

# --- UNIFIED P/INVOKE API CLASS ---
# Consolidates all Windows API calls needed for identity resolution
Add-Type -ErrorAction SilentlyContinue -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Diagnostics;

public class MatrixWindowAPI {
    // --- Window Enumeration ---
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);

    // --- Window Properties ---
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    // --- Constants ---
    public const int SW_RESTORE = 9;
    public const uint SWP_NOZORDER = 0x0004;
    public const uint SWP_NOACTIVATE = 0x0010;
    public const uint SWP_SHOWWINDOW = 0x0040;
    public const int GWL_STYLE = -16;
    public const int WS_VISIBLE = 0x10000000;

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left, Top, Right, Bottom;
    }

    // --- Static Storage for EnumWindows callback ---
    private static List<WindowInfo> foundWindows;

    public struct WindowInfo {
        public IntPtr Handle;
        public string Title;
        public uint ProcessId;
    }

    /// <summary>
    /// Find all visible Windows Terminal windows.
    /// Returns list of WindowInfo with Handle, Title, ProcessId.
    /// </summary>
    public static List<WindowInfo> FindAllTerminalWindows() {
        foundWindows = new List<WindowInfo>();
        EnumWindows((hWnd, lParam) => {
            if (IsWindowVisible(hWnd)) {
                uint processId;
                GetWindowThreadProcessId(hWnd, out processId);
                try {
                    var process = Process.GetProcessById((int)processId);
                    if (process.ProcessName.Equals("WindowsTerminal", StringComparison.OrdinalIgnoreCase)) {
                        var sb = new StringBuilder(256);
                        GetWindowText(hWnd, sb, 256);
                        var title = sb.ToString();
                        if (!string.IsNullOrEmpty(title)) {
                            foundWindows.Add(new WindowInfo {
                                Handle = hWnd,
                                Title = title,
                                ProcessId = processId
                            });
                        }
                    }
                } catch { }
            }
            return true;
        }, IntPtr.Zero);
        return foundWindows;
    }

    /// <summary>
    /// Fast title-pattern search without process lookup.
    /// Uses regex matching on window titles.
    /// </summary>
    public static List<WindowInfo> FindWindowsByTitlePattern(string pattern) {
        foundWindows = new List<WindowInfo>();
        EnumWindows((hWnd, lParam) => {
            if (IsWindowVisible(hWnd)) {
                var sb = new StringBuilder(256);
                GetWindowText(hWnd, sb, 256);
                var title = sb.ToString();
                if (!string.IsNullOrEmpty(title) &&
                    System.Text.RegularExpressions.Regex.IsMatch(title, pattern,
                        System.Text.RegularExpressions.RegexOptions.IgnoreCase)) {
                    uint processId;
                    GetWindowThreadProcessId(hWnd, out processId);
                    foundWindows.Add(new WindowInfo {
                        Handle = hWnd,
                        Title = title,
                        ProcessId = processId
                    });
                }
            }
            return true;
        }, IntPtr.Zero);
        return foundWindows;
    }

    /// <summary>
    /// Get window title for a specific handle.
    /// </summary>
    public static string GetWindowTitle(IntPtr hWnd) {
        if (hWnd == IntPtr.Zero) return null;
        var sb = new StringBuilder(256);
        GetWindowText(hWnd, sb, 256);
        return sb.ToString();
    }

    /// <summary>
    /// Get process ID for a window handle.
    /// </summary>
    public static uint GetProcessId(IntPtr hWnd) {
        uint processId;
        GetWindowThreadProcessId(hWnd, out processId);
        return processId;
    }
}
"@

# --- LOGGING SYSTEM (US-009 Pattern) ---

<#
.SYNOPSIS
    Write a log message for identity service debugging.

.DESCRIPTION
    Writes timestamped messages to console and log file.
    Controlled by $script:IdentityServiceVerbose and $env:MATRIX_DEBUG.

.PARAMETER Message
    The message to log

.PARAMETER Level
    Log level: DEBUG, INFO, WARN, ERROR (default: INFO)

.PARAMETER Force
    If set, writes message even when verbose mode is disabled

.EXAMPLE
    Write-IdentityLog "Resolving identity for handle 12345" -Level "DEBUG"
#>
function Write-IdentityLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO',

        [switch]$Force
    )

    # Check if logging is enabled (verbose flag or MATRIX_DEBUG env var)
    $isEnabled = $script:IdentityServiceVerbose -or ($env:MATRIX_DEBUG -eq "1")

    # Skip if not enabled (unless Force or it's a warning/error)
    if (-not $isEnabled -and -not $Force -and $Level -notin @('WARN', 'ERROR')) {
        return
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp] [IDENTITY] [$Level] $Message"

    # Console output with color coding
    $color = switch ($Level) {
        'DEBUG' { 'DarkGray' }
        'INFO'  { 'Gray' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
    }

    if ($isEnabled -or $Force -or $Level -in @('WARN', 'ERROR')) {
        Write-Host $logEntry -ForegroundColor $color
    }

    # File logging (only when enabled)
    if ($isEnabled) {
        try {
            $logDir = Split-Path $script:IdentityLogFile -Parent
            if (-not (Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            Add-Content -Path $script:IdentityLogFile -Value $logEntry -ErrorAction SilentlyContinue
        }
        catch {
            # Silently fail file logging
        }
    }
}

<#
.SYNOPSIS
    Enable verbose identity logging.

.PARAMETER ClearLog
    If set, clears the existing log file
#>
function Enable-IdentityVerboseLogging {
    param([switch]$ClearLog)

    $script:IdentityServiceVerbose = $true
    Write-IdentityLog "Verbose logging ENABLED" -Level "INFO" -Force

    if ($ClearLog -and (Test-Path $script:IdentityLogFile)) {
        Remove-Item $script:IdentityLogFile -Force -ErrorAction SilentlyContinue
        Write-IdentityLog "Log file cleared" -Level "INFO" -Force
    }
}

<#
.SYNOPSIS
    Disable verbose identity logging.
#>
function Disable-IdentityVerboseLogging {
    Write-IdentityLog "Verbose logging DISABLED" -Level "INFO" -Force
    $script:IdentityServiceVerbose = $false
}

# --- LAYER 1: LAUNCH TRACKING ---

<#
.SYNOPSIS
    Register a Matrix window launch for instant identity tracking.

.DESCRIPTION
    Called immediately when launching a new Matrix window. Stores PID and
    profile name for instant identity resolution later.

    This is Priority 1 in the identity hierarchy - instant and 100% reliable
    for windows we spawned ourselves.

.PARAMETER ProfileName
    The Windows Terminal profile name (e.g., "Matrix-1", "Matrix-3")

.PARAMETER ProcessInfo
    The process object returned from Start-Process (must have Id property)

.PARAMETER CorrelationId
    Optional unique ID to correlate launch with window appearance

.EXAMPLE
    $proc = Start-Process wt -ArgumentList "-p `"Matrix-1`"" -PassThru
    Register-MatrixWindowLaunch -ProfileName "Matrix-1" -ProcessInfo $proc
#>
function Register-MatrixWindowLaunch {
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [object]$ProcessInfo,

        [string]$CorrelationId = $null
    )

    if (-not $CorrelationId) {
        $CorrelationId = [Guid]::NewGuid().ToString("N").Substring(0, 8)
    }

    $processId = $ProcessInfo.Id

    # Store in runtime registry
    $script:LaunchRegistry[$processId.ToString()] = @{
        ProfileName = $ProfileName
        LaunchTime = (Get-Date)
        CorrelationId = $CorrelationId
        ProcessId = $processId
    }

    Write-IdentityLog "Registered launch: PID=$processId, Profile=$ProfileName, Correlation=$CorrelationId" -Level "INFO"

    # Also persist to disk for cross-session recovery
    Save-IdentityRegistry
}

<#
.SYNOPSIS
    Register a Matrix window by its window handle (for launch tracking).

.DESCRIPTION
    Called after detecting a new window handle post-launch. This is the
    reliable way to track windows since wt.exe is just a launcher that exits.

.PARAMETER ProfileName
    The Windows Terminal profile name (e.g., "Matrix-1", "Matrix-3")

.PARAMETER WindowHandle
    The window handle (IntPtr) of the newly created window

.PARAMETER CorrelationId
    Optional unique ID to correlate launch with window appearance

.EXAMPLE
    Register-MatrixWindowByHandle -ProfileName "Matrix-1" -WindowHandle $newHwnd
#>
function Register-MatrixWindowByHandle {
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [IntPtr]$WindowHandle,

        [string]$CorrelationId = $null
    )

    if (-not $CorrelationId) {
        $CorrelationId = [Guid]::NewGuid().ToString("N").Substring(0, 8)
    }

    # Get the process ID from the window handle
    $processId = [MatrixWindowAPI]::GetProcessId($WindowHandle)

    # Store in runtime registry using handle as key (more reliable than PID for wt.exe launches)
    $handleKey = $WindowHandle.ToString()
    $script:LaunchRegistry[$handleKey] = @{
        ProfileName = $ProfileName
        LaunchTime = (Get-Date)
        CorrelationId = $CorrelationId
        WindowHandle = $WindowHandle
        ProcessId = $processId
    }

    Write-IdentityLog "Registered window: Handle=$WindowHandle, PID=$processId, Profile=$ProfileName, Correlation=$CorrelationId" -Level "INFO"

    # Also persist to disk for cross-session recovery
    Save-IdentityRegistry
}

<#
.SYNOPSIS
    Wait for a new Matrix window to appear after launching a profile.

.DESCRIPTION
    Compares window handles before and after launch to detect the new window.
    Uses polling with timeout to find the new handle.

.PARAMETER ProfileName
    The profile name being launched (used for title matching fallback)

.PARAMETER ExistingHandles
    Array of IntPtr handles that existed BEFORE the launch

.PARAMETER TimeoutMs
    Maximum time to wait in milliseconds (default: 5000)

.PARAMETER PollIntervalMs
    Polling interval in milliseconds (default: 100)

.OUTPUTS
    IntPtr - The handle of the new window, or [IntPtr]::Zero if timeout

.EXAMPLE
    $beforeHandles = Get-ExistingWindowHandles
    Start-Process wt -ArgumentList "-p Matrix-1"
    $newHandle = Wait-ForNewMatrixWindow -ProfileName "Matrix-1" -ExistingHandles $beforeHandles
#>
function Wait-ForNewMatrixWindow {
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [IntPtr[]]$ExistingHandles,

        [int]$TimeoutMs = 5000,

        [int]$PollIntervalMs = 100
    )

    $startTime = Get-Date

    while (((Get-Date) - $startTime).TotalMilliseconds -lt $TimeoutMs) {
        Start-Sleep -Milliseconds $PollIntervalMs

        # Get current windows
        $currentWindows = [MatrixWindowAPI]::FindAllTerminalWindows()

        foreach ($win in $currentWindows) {
            $handle = $win.Handle

            # Skip if this handle existed before launch
            if ($handle -in $ExistingHandles) {
                continue
            }

            # New window found!
            $title = $win.Title
            Write-IdentityLog "New window detected: Handle=$handle, Title='$title'" -Level "DEBUG"
            return $handle
        }
    }

    Write-IdentityLog "Timeout waiting for new window: $ProfileName" -Level "WARN"
    return [IntPtr]::Zero
}

<#
.SYNOPSIS
    Get handles of all existing Windows Terminal windows.

.OUTPUTS
    IntPtr[] - Array of window handles
#>
function Get-ExistingWindowHandles {
    $windows = [MatrixWindowAPI]::FindAllTerminalWindows()
    return @($windows | ForEach-Object { $_.Handle })
}

<#
.SYNOPSIS
    Look up a window's identity from the launch registry by handle.

.DESCRIPTION
    Attempts to resolve window identity using the launch tracking registry,
    looking up by window handle instead of process ID.

.PARAMETER WindowHandle
    The window handle (IntPtr)

.OUTPUTS
    Hashtable with ProfileName, ShaderFile, IdentitySource, Confidence
    or $null if not found
#>
function Get-LaunchRegistryIdentityByHandle {
    param(
        [Parameter(Mandatory)]
        [IntPtr]$WindowHandle
    )

    $handleKey = $WindowHandle.ToString()

    # Check runtime registry
    if ($script:LaunchRegistry.ContainsKey($handleKey)) {
        $entry = $script:LaunchRegistry[$handleKey]

        # Validate the window still exists
        if (Test-WindowHandleValid -Handle $WindowHandle) {
            $slotNum = if ($entry.ProfileName -match "Matrix-(\d+)") { [int]$Matches[1] } else { $null }
            $shaderFile = if ($slotNum) { "Matrix-$slotNum.hlsl" } else { $null }

            Write-IdentityLog "Launch registry (handle) hit: Handle=$WindowHandle -> $($entry.ProfileName)" -Level "DEBUG"

            return @{
                ProfileName = $entry.ProfileName
                ShaderFile = $shaderFile
                Slot = $slotNum
                IdentitySource = "LaunchTracking"
                Confidence = 1.0
                LaunchTime = $entry.LaunchTime
                CorrelationId = $entry.CorrelationId
            }
        }
        else {
            # Window no longer exists - clean up stale entry
            Write-IdentityLog "Removing stale launch entry: Handle=$WindowHandle (window gone)" -Level "DEBUG"
            $script:LaunchRegistry.Remove($handleKey)
        }
    }

    return $null
}

<#
.SYNOPSIS
    Look up a window's identity from the launch registry.

.DESCRIPTION
    Attempts to resolve window identity using the launch tracking registry.
    Returns $null if no match found (fall through to next layer).

.PARAMETER ProcessId
    The process ID of the window

.OUTPUTS
    Hashtable with ProfileName, ShaderFile, IdentitySource, Confidence
    or $null if not found

.EXAMPLE
    $identity = Get-LaunchRegistryIdentity -ProcessId 12345
#>
function Get-LaunchRegistryIdentity {
    param(
        [Parameter(Mandatory)]
        [uint32]$ProcessId
    )

    $pidKey = $ProcessId.ToString()

    # Check runtime registry first (fastest)
    if ($script:LaunchRegistry.ContainsKey($pidKey)) {
        $entry = $script:LaunchRegistry[$pidKey]

        # Validate the process is still running
        try {
            $proc = Get-Process -Id $ProcessId -ErrorAction Stop

            # Extract slot number from profile name
            $slotNum = if ($entry.ProfileName -match "Matrix-(\d+)") { [int]$Matches[1] } else { $null }
            $shaderFile = if ($slotNum) { "Matrix-$slotNum.hlsl" } else { $null }

            Write-IdentityLog "Launch registry hit: PID=$ProcessId -> $($entry.ProfileName)" -Level "DEBUG"

            return @{
                ProfileName = $entry.ProfileName
                ShaderFile = $shaderFile
                Slot = $slotNum
                IdentitySource = "LaunchTracking"
                Confidence = 1.0
                LaunchTime = $entry.LaunchTime
                CorrelationId = $entry.CorrelationId
            }
        }
        catch {
            # Process no longer exists - clean up stale entry
            Write-IdentityLog "Removing stale launch entry: PID=$ProcessId (process gone)" -Level "DEBUG"
            $script:LaunchRegistry.Remove($pidKey)
        }
    }

    # Check persisted registry as fallback
    $persisted = Load-IdentityRegistry
    if ($persisted -and $persisted.ContainsKey($pidKey)) {
        $entry = $persisted[$pidKey]

        # Validate process still exists
        try {
            $proc = Get-Process -Id $ProcessId -ErrorAction Stop

            $slotNum = if ($entry.ProfileName -match "Matrix-(\d+)") { [int]$Matches[1] } else { $null }
            $shaderFile = if ($slotNum) { "Matrix-$slotNum.hlsl" } else { $null }

            Write-IdentityLog "Persisted registry hit: PID=$ProcessId -> $($entry.ProfileName)" -Level "DEBUG"

            # Promote to runtime registry for faster future lookups
            $script:LaunchRegistry[$pidKey] = $entry

            return @{
                ProfileName = $entry.ProfileName
                ShaderFile = $shaderFile
                Slot = $slotNum
                IdentitySource = "LaunchTracking"
                Confidence = 0.95  # Slightly lower - recovered from disk
                LaunchTime = $entry.LaunchTime
            }
        }
        catch {
            Write-IdentityLog "Persisted entry stale: PID=$ProcessId" -Level "DEBUG"
        }
    }

    return $null
}

# --- LAYER 2: COMMAND LINE PARSING ---

<#
.SYNOPSIS
    Resolve window identity by parsing wt.exe command line arguments.

.DESCRIPTION
    Uses WMI to get the command line of Windows Terminal processes,
    then parses for -p "ProfileName" arguments.

    This is Priority 2 - fast (~20ms per window in batch) and 95% reliable.

.PARAMETER ProcessIds
    Array of process IDs to query (batched for performance)

.OUTPUTS
    Hashtable keyed by PID string, values are identity info

.EXAMPLE
    $identities = Get-CommandLineIdentities -ProcessIds @(1234, 5678, 9012)
#>
function Get-CommandLineIdentities {
    param(
        [Parameter(Mandatory)]
        [array]$ProcessIds
    )

    $results = @{}

    if ($ProcessIds.Count -eq 0) {
        return $results
    }

    Write-IdentityLog "Querying command lines for $($ProcessIds.Count) processes" -Level "DEBUG"

    try {
        # Build WMI query for all PIDs at once (batch optimization)
        $pidFilter = ($ProcessIds | ForEach-Object { "ProcessId=$_" }) -join " OR "
        $query = "SELECT ProcessId, CommandLine FROM Win32_Process WHERE ($pidFilter)"

        $processes = Get-CimInstance -Query $query -ErrorAction Stop

        foreach ($proc in $processes) {
            $procId = $proc.ProcessId
            $cmdLine = $proc.CommandLine

            if (-not $cmdLine) {
                continue
            }

            Write-IdentityLog "  PID $procId cmdline: $cmdLine" -Level "DEBUG"

            # Parse for profile argument: -p "Matrix-N" or --profile "Matrix-N"
            # Also handles: wt.exe -p Matrix-1 (without quotes)
            $profileMatch = $null

            # Pattern 1: -p "Matrix-N" or --profile "Matrix-N"
            if ($cmdLine -match '(?:-p|--profile)\s+"([^"]+)"') {
                $profileMatch = $Matches[1]
            }
            # Pattern 2: -p Matrix-N (no quotes)
            elseif ($cmdLine -match '(?:-p|--profile)\s+(\S+)') {
                $profileMatch = $Matches[1]
            }

            if ($profileMatch -and $profileMatch -match "Matrix-(\d+)") {
                $slotNum = [int]$Matches[1]

                $results[$procId.ToString()] = @{
                    ProfileName = $profileMatch
                    ShaderFile = "Matrix-$slotNum.hlsl"
                    Slot = $slotNum
                    IdentitySource = "CommandLine"
                    Confidence = 0.95
                    CommandLine = $cmdLine
                }

                Write-IdentityLog "  Command line match: PID=$procId -> $profileMatch (Slot $slotNum)" -Level "DEBUG"
            }
            # Check for Redpill profile
            elseif ($profileMatch -and $profileMatch -match "(?i)redpill") {
                $results[$procId.ToString()] = @{
                    ProfileName = $profileMatch
                    ShaderFile = "Redpill-Neo.hlsl"
                    Slot = 0
                    IdentitySource = "CommandLine"
                    Confidence = 0.95
                    CommandLine = $cmdLine
                    IsRedpill = $true
                }

                Write-IdentityLog "  Command line match: PID=$procId -> Redpill" -Level "DEBUG"
            }
        }
    }
    catch {
        Write-IdentityLog "WMI query failed: $_" -Level "WARN"
    }

    Write-IdentityLog "Command line resolution: $($results.Count) matches from $($ProcessIds.Count) PIDs" -Level "DEBUG"
    return $results
}

# --- LAYER 3: TITLE MATCHING ---

<#
.SYNOPSIS
    Resolve window identity from window title.

.DESCRIPTION
    Parses window title for "Matrix-N" pattern.
    This is Priority 3 - fast (~5ms) but only 70% reliable
    (titles can change based on active tab/shell).

.PARAMETER WindowHandle
    The window handle (IntPtr)

.PARAMETER WindowTitle
    The current window title string

.OUTPUTS
    Hashtable with ProfileName, ShaderFile, IdentitySource, Confidence
    or $null if no match

.EXAMPLE
    $identity = Get-TitleIdentity -WindowHandle $hwnd -WindowTitle "Matrix-1"
#>
function Get-TitleIdentity {
    param(
        [Parameter(Mandatory)]
        [IntPtr]$WindowHandle,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$WindowTitle
    )

    if ([string]::IsNullOrWhiteSpace($WindowTitle)) {
        return $null
    }

    # Pattern 1: Matrix-N in title
    if ($WindowTitle -match "Matrix-(\d+)") {
        $slotNum = [int]$Matches[1]

        Write-IdentityLog "Title match: '$WindowTitle' -> Matrix-$slotNum" -Level "DEBUG"

        return @{
            ProfileName = "Matrix-$slotNum"
            ShaderFile = "Matrix-$slotNum.hlsl"
            Slot = $slotNum
            IdentitySource = "TitleMatch"
            Confidence = 0.70
        }
    }

    # Pattern 2: Redpill or RED PILL in title
    if ($WindowTitle -match "(?i)(redpill|red\s*pill)") {
        Write-IdentityLog "Title match: '$WindowTitle' -> Redpill" -Level "DEBUG"

        return @{
            ProfileName = "Redpill"
            ShaderFile = "Redpill-Neo.hlsl"
            Slot = 0
            IdentitySource = "TitleMatch"
            Confidence = 0.70
            IsRedpill = $true
        }
    }

    return $null
}

# --- LAYER 4: UI AUTOMATION (SLOW FALLBACK) ---

<#
.SYNOPSIS
    Resolve window identity using UI Automation tree walking.

.DESCRIPTION
    Walks the UI Automation tree to find profile information.
    This is Priority 4 - slow (100-300ms) but 90% reliable.
    Only used as last resort when other methods fail.

.PARAMETER WindowHandle
    The window handle (IntPtr)

.OUTPUTS
    Hashtable with ProfileName, ShaderFile, IdentitySource, Confidence
    or $null if not found

.EXAMPLE
    $identity = Get-UIAutomationIdentity -WindowHandle $hwnd
#>
function Get-UIAutomationIdentity {
    param(
        [Parameter(Mandatory)]
        [IntPtr]$WindowHandle
    )

    Write-IdentityLog "UI Automation fallback for handle $WindowHandle" -Level "DEBUG"

    try {
        # Load UI Automation assembly
        Add-Type -AssemblyName UIAutomationClient -ErrorAction Stop
        Add-Type -AssemblyName UIAutomationTypes -ErrorAction Stop

        # Get automation element for window
        $element = [System.Windows.Automation.AutomationElement]::FromHandle($WindowHandle)

        if (-not $element) {
            Write-IdentityLog "  Could not get AutomationElement" -Level "DEBUG"
            return $null
        }

        # Try to find the profile name in the UI tree
        # Windows Terminal shows profile name in tab title and/or name property
        $name = $element.Current.Name

        Write-IdentityLog "  AutomationElement.Name: '$name'" -Level "DEBUG"

        # Check if name contains Matrix profile
        if ($name -match "Matrix-(\d+)") {
            $slotNum = [int]$Matches[1]

            return @{
                ProfileName = "Matrix-$slotNum"
                ShaderFile = "Matrix-$slotNum.hlsl"
                Slot = $slotNum
                IdentitySource = "UIAutomation"
                Confidence = 0.90
            }
        }

        # Check for Redpill
        if ($name -match "(?i)(redpill|red\s*pill)") {
            return @{
                ProfileName = "Redpill"
                ShaderFile = "Redpill-Neo.hlsl"
                Slot = 0
                IdentitySource = "UIAutomation"
                Confidence = 0.90
                IsRedpill = $true
            }
        }

        # PRIORITY 1: Look for TermControl elements - these have the PROFILE NAME in their Name property
        # This is the most reliable UI Automation method
        $classCondition = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ClassNameProperty,
            "TermControl"
        )

        $termControls = $element.FindAll([System.Windows.Automation.TreeScope]::Descendants, $classCondition)

        foreach ($tc in $termControls) {
            $tcName = $tc.Current.Name
            Write-IdentityLog "  Found TermControl: Name='$tcName'" -Level "DEBUG"

            if ($tcName -match "Matrix-(\d+)") {
                $slotNum = [int]$Matches[1]

                return @{
                    ProfileName = "Matrix-$slotNum"
                    ShaderFile = "Matrix-$slotNum.hlsl"
                    Slot = $slotNum
                    IdentitySource = "UIAutomation-TermControl"
                    Confidence = 0.95
                }
            }

            if ($tcName -match "(?i)(redpill|red\s*pill)") {
                return @{
                    ProfileName = "Redpill"
                    ShaderFile = "Redpill-Neo.hlsl"
                    Slot = 0
                    IdentitySource = "UIAutomation-TermControl"
                    Confidence = 0.95
                    IsRedpill = $true
                }
            }
        }

        # PRIORITY 2: Fall back to tab elements if TermControl not found
        $tabCondition = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::TabItem
        )

        $tabs = $element.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tabCondition)

        foreach ($tab in $tabs) {
            $tabName = $tab.Current.Name
            Write-IdentityLog "  Found tab: '$tabName'" -Level "DEBUG"

            if ($tabName -match "Matrix-(\d+)") {
                $slotNum = [int]$Matches[1]

                return @{
                    ProfileName = "Matrix-$slotNum"
                    ShaderFile = "Matrix-$slotNum.hlsl"
                    Slot = $slotNum
                    IdentitySource = "UIAutomation-Tab"
                    Confidence = 0.85
                }
            }
        }
    }
    catch {
        Write-IdentityLog "  UI Automation error: $_" -Level "DEBUG"
    }

    return $null
}

# --- HANDLE VALIDATION ---

<#
.SYNOPSIS
    Test if a window handle is still valid and visible.

.DESCRIPTION
    Validates that a window handle points to an existing, visible window.
    Use this before attempting to interact with a window.

.PARAMETER Handle
    The window handle (IntPtr) to validate

.OUTPUTS
    $true if handle is valid and window is visible, $false otherwise

.EXAMPLE
    if (Test-WindowHandleValid -Handle $hwnd) {
        # Safe to interact with window
    }
#>
function Test-WindowHandleValid {
    param(
        [Parameter(Mandatory)]
        [IntPtr]$Handle
    )

    if ($Handle -eq [IntPtr]::Zero) {
        return $false
    }

    try {
        # Check if window handle exists
        if (-not [MatrixWindowAPI]::IsWindow($Handle)) {
            return $false
        }

        # Check if window is visible
        if (-not [MatrixWindowAPI]::IsWindowVisible($Handle)) {
            return $false
        }

        return $true
    }
    catch {
        return $false
    }
}

# --- MAIN IDENTITY RESOLUTION ---

<#
.SYNOPSIS
    Resolve the identity of a single Matrix window.

.DESCRIPTION
    Uses the 4-layer identity hierarchy to determine which Matrix profile
    a window belongs to:
    1. Launch Tracking (instant, 100% reliable for spawned windows)
    2. Command Line Parsing (fast, 95% reliable)
    3. Title Matching (fast, 70% reliable)
    4. UI Automation (slow fallback, 90% reliable)

.PARAMETER WindowHandle
    The window handle (IntPtr)

.PARAMETER WindowTitle
    Optional: pre-fetched window title (saves API call)

.PARAMETER ProcessId
    Optional: pre-fetched process ID (saves API call)

.PARAMETER CommandLineCache
    Optional: pre-fetched command line cache from batch query

.OUTPUTS
    Hashtable: @{ ProfileName, ShaderFile, Slot, IdentitySource, Confidence, ... }
    or $null if identity cannot be resolved

.EXAMPLE
    $identity = Resolve-WindowIdentity -WindowHandle $hwnd
    Write-Host "Window is $($identity.ProfileName) (via $($identity.IdentitySource))"
#>
function Resolve-WindowIdentity {
    param(
        [Parameter(Mandatory)]
        [IntPtr]$WindowHandle,

        [string]$WindowTitle = $null,

        [uint32]$ProcessId = 0,

        [hashtable]$CommandLineCache = $null
    )

    # Validate handle first
    if (-not (Test-WindowHandleValid -Handle $WindowHandle)) {
        Write-IdentityLog "Invalid handle: $WindowHandle" -Level "DEBUG"
        return $null
    }

    # Get process ID if not provided
    if ($ProcessId -eq 0) {
        $ProcessId = [MatrixWindowAPI]::GetProcessId($WindowHandle)
    }

    # Get window title if not provided
    if ([string]::IsNullOrEmpty($WindowTitle)) {
        $WindowTitle = [MatrixWindowAPI]::GetWindowTitle($WindowHandle)
    }

    Write-IdentityLog "Resolving identity: Handle=$WindowHandle, PID=$ProcessId, Title='$WindowTitle'" -Level "DEBUG"

    # LAYER 1: Launch Tracking - Try handle-based lookup first (most reliable)
    $identity = Get-LaunchRegistryIdentityByHandle -WindowHandle $WindowHandle
    if ($identity) {
        Write-IdentityLog "  -> Layer 1 (Launch Tracking by Handle): $($identity.ProfileName)" -Level "DEBUG"
        return $identity
    }

    # LAYER 1: Launch Tracking - Fall back to PID-based lookup
    $identity = Get-LaunchRegistryIdentity -ProcessId $ProcessId
    if ($identity) {
        Write-IdentityLog "  -> Layer 1 (Launch Tracking by PID): $($identity.ProfileName)" -Level "DEBUG"
        return $identity
    }

    # LAYER 2: Command Line Parsing
    if ($CommandLineCache -and $CommandLineCache.ContainsKey($ProcessId.ToString())) {
        $identity = $CommandLineCache[$ProcessId.ToString()]
        Write-IdentityLog "  -> Layer 2 (Command Line Cache): $($identity.ProfileName)" -Level "DEBUG"
        return $identity
    }
    else {
        # Single process query (not as efficient as batch)
        $cmdLineResults = Get-CommandLineIdentities -ProcessIds @($ProcessId)
        if ($cmdLineResults.ContainsKey($ProcessId.ToString())) {
            $identity = $cmdLineResults[$ProcessId.ToString()]
            Write-IdentityLog "  -> Layer 2 (Command Line): $($identity.ProfileName)" -Level "DEBUG"
            return $identity
        }
    }

    # LAYER 3: Title Matching
    $identity = Get-TitleIdentity -WindowHandle $WindowHandle -WindowTitle $WindowTitle
    if ($identity) {
        Write-IdentityLog "  -> Layer 3 (Title Match): $($identity.ProfileName)" -Level "DEBUG"
        return $identity
    }

    # LAYER 4: UI Automation (slow fallback)
    $identity = Get-UIAutomationIdentity -WindowHandle $WindowHandle
    if ($identity) {
        Write-IdentityLog "  -> Layer 4 (UI Automation): $($identity.ProfileName)" -Level "DEBUG"
        return $identity
    }

    Write-IdentityLog "  -> No identity resolved for Handle=$WindowHandle" -Level "WARN"
    return $null
}

# --- MAIN ENTRY POINT ---

<#
.SYNOPSIS
    Get all Matrix windows with resolved identities.

.DESCRIPTION
    Main entry point for the identity service. Finds all Windows Terminal
    windows and resolves their identities using the 4-layer hierarchy.

    Optimized for batch processing - queries command lines in bulk for
    performance.

.PARAMETER IncludeRedpill
    If set, includes the Redpill control panel window in results

.PARAMETER ValidateHandles
    If set, performs extra validation on window handles (default: true)

.OUTPUTS
    Array of hashtables, each containing:
    @{
        Handle        = [IntPtr]  # Window handle
        ProfileName   = [string]  # e.g., "Matrix-1"
        ShaderFile    = [string]  # e.g., "Matrix-1.hlsl"
        Slot          = [int]     # e.g., 1 (or $null for Redpill)
        ProcessId     = [uint32]  # Process ID
        Title         = [string]  # Current window title
        IdentitySource = [string] # How identity was resolved
        Confidence    = [float]   # 0.0-1.0 confidence score
    }

.EXAMPLE
    $windows = Get-AllMatrixWindows
    $windows | ForEach-Object {
        Write-Host "$($_.ProfileName): Handle=$($_.Handle) via $($_.IdentitySource)"
    }

.EXAMPLE
    # Get only Matrix windows (exclude Redpill)
    $matrixOnly = Get-AllMatrixWindows | Where-Object { -not $_.IsRedpill }
#>
function Get-AllMatrixWindows {
    param(
        [switch]$IncludeRedpill = $true,
        [switch]$ValidateHandles = $true
    )

    $startTime = Get-Date
    Write-IdentityLog "Get-AllMatrixWindows starting..." -Level "INFO"

    # Step 1: Find all Windows Terminal windows
    $allTerminalWindows = [MatrixWindowAPI]::FindAllTerminalWindows()
    Write-IdentityLog "Found $($allTerminalWindows.Count) terminal windows" -Level "DEBUG"

    if ($allTerminalWindows.Count -eq 0) {
        Write-IdentityLog "No terminal windows found" -Level "INFO"
        return @()
    }

    # Step 2: Batch query command lines for all PIDs (Layer 2 optimization)
    $pids = @($allTerminalWindows | ForEach-Object { $_.ProcessId } | Select-Object -Unique)
    $commandLineCache = Get-CommandLineIdentities -ProcessIds $pids

    # Step 3: Resolve identity for each window
    $results = @()
    foreach ($win in $allTerminalWindows) {
        $identity = Resolve-WindowIdentity `
            -WindowHandle $win.Handle `
            -WindowTitle $win.Title `
            -ProcessId $win.ProcessId `
            -CommandLineCache $commandLineCache

        if ($identity) {
            # Skip Redpill if not requested
            if (-not $IncludeRedpill -and $identity.IsRedpill) {
                Write-IdentityLog "  Skipping Redpill window (excluded)" -Level "DEBUG"
                continue
            }

            $results += @{
                Handle = $win.Handle
                ProfileName = $identity.ProfileName
                ShaderFile = $identity.ShaderFile
                Slot = $identity.Slot
                ProcessId = $win.ProcessId
                Title = $win.Title
                IdentitySource = $identity.IdentitySource
                Confidence = $identity.Confidence
                IsRedpill = [bool]$identity.IsRedpill
            }
        }
        else {
            Write-IdentityLog "  Unidentified window: Handle=$($win.Handle), Title='$($win.Title)'" -Level "DEBUG"
        }
    }

    # Step 4: Sort by slot number for consistent ordering
    $sorted = $results | Sort-Object { if ($_.Slot) { $_.Slot } else { 999 } }

    $elapsed = ((Get-Date) - $startTime).TotalMilliseconds
    Write-IdentityLog "Get-AllMatrixWindows complete: $($sorted.Count) windows in ${elapsed}ms" -Level "INFO"

    # Log identity breakdown
    $bySource = $sorted | Group-Object IdentitySource
    foreach ($group in $bySource) {
        Write-IdentityLog "  $($group.Name): $($group.Count) windows" -Level "DEBUG"
    }

    return $sorted
}

# --- REGISTRY PERSISTENCE ---

<#
.SYNOPSIS
    Save the identity registry to disk.

.DESCRIPTION
    Persists the launch registry to JSON file for cross-session recovery.
    Uses atomic write pattern (US-001).
#>
function Save-IdentityRegistry {
    try {
        $registryDir = Split-Path $script:IdentityRegistryPath -Parent
        if (-not (Test-Path $registryDir)) {
            New-Item -Path $registryDir -ItemType Directory -Force | Out-Null
        }

        $data = @{
            version = "1.0"
            savedAt = (Get-Date).ToString("o")
            entries = $script:LaunchRegistry
        }

        $json = $data | ConvertTo-Json -Depth 5

        # Atomic write: temp file + move
        $tempFile = [System.IO.Path]::GetTempFileName()
        $json | Out-File -FilePath $tempFile -Encoding UTF8
        Move-Item -Path $tempFile -Destination $script:IdentityRegistryPath -Force

        Write-IdentityLog "Identity registry saved ($($script:LaunchRegistry.Count) entries)" -Level "DEBUG"
    }
    catch {
        Write-IdentityLog "Failed to save identity registry: $_" -Level "WARN"
        # Clean up temp file if it exists (US-001 pattern)
        if ($tempFile -and (Test-Path $tempFile)) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

<#
.SYNOPSIS
    Load the identity registry from disk.

.DESCRIPTION
    Loads persisted launch registry for cross-session recovery.
    Uses error handling pattern (US-002).

.OUTPUTS
    Hashtable of registry entries or $null on failure
#>
function Load-IdentityRegistry {
    try {
        if (-not (Test-Path $script:IdentityRegistryPath)) {
            return $null
        }

        $json = Get-Content $script:IdentityRegistryPath -Raw -ErrorAction Stop
        $data = $json | ConvertFrom-Json -ErrorAction Stop

        # Convert PSCustomObject to hashtable
        $entries = @{}
        if ($data.entries) {
            $data.entries.PSObject.Properties | ForEach-Object {
                $entries[$_.Name] = @{
                    ProfileName = $_.Value.ProfileName
                    LaunchTime = $_.Value.LaunchTime
                    CorrelationId = $_.Value.CorrelationId
                    ProcessId = $_.Value.ProcessId
                }
            }
        }

        Write-IdentityLog "Identity registry loaded ($($entries.Count) entries)" -Level "DEBUG"
        return $entries
    }
    catch {
        Write-IdentityLog "Failed to load identity registry: $_" -Level "WARN"
        return $null
    }
}

# --- CLEANUP ---

<#
.SYNOPSIS
    Clean stale entries from the identity registry.

.DESCRIPTION
    Removes entries for processes that no longer exist.
    Should be called periodically to prevent registry bloat.

.PARAMETER MaxAgeHours
    Remove entries older than this many hours (default: 24)

.OUTPUTS
    Number of entries removed

.EXAMPLE
    $removed = Clean-WindowIdentityRegistry -MaxAgeHours 12
    Write-Host "Cleaned $removed stale entries"
#>
function Clean-WindowIdentityRegistry {
    param(
        [int]$MaxAgeHours = 24
    )

    $removedCount = 0
    $cutoffTime = (Get-Date).AddHours(-$MaxAgeHours)
    $keysToRemove = @()

    Write-IdentityLog "Cleaning identity registry (max age: $MaxAgeHours hours)" -Level "INFO"

    # Check runtime registry
    foreach ($pidKey in @($script:LaunchRegistry.Keys)) {
        $entry = $script:LaunchRegistry[$pidKey]
        $procId = [int]$pidKey
        $shouldRemove = $false

        # Check if process still exists
        try {
            $proc = Get-Process -Id $procId -ErrorAction Stop
        }
        catch {
            Write-IdentityLog "  Marking stale (process gone): PID=$procId" -Level "DEBUG"
            $shouldRemove = $true
        }

        # Check age
        if (-not $shouldRemove -and $entry.LaunchTime) {
            $launchTime = [DateTime]$entry.LaunchTime
            if ($launchTime -lt $cutoffTime) {
                Write-IdentityLog "  Marking stale (too old): PID=$procId, LaunchTime=$($entry.LaunchTime)" -Level "DEBUG"
                $shouldRemove = $true
            }
        }

        if ($shouldRemove) {
            $keysToRemove += $pidKey
        }
    }

    # Remove stale entries
    foreach ($key in $keysToRemove) {
        $script:LaunchRegistry.Remove($key)
        $removedCount++
    }

    # Save cleaned registry
    if ($removedCount -gt 0) {
        Save-IdentityRegistry
        Write-IdentityLog "Removed $removedCount stale entries from identity registry" -Level "INFO"
    }
    else {
        Write-IdentityLog "No stale entries found" -Level "DEBUG"
    }

    return $removedCount
}

<#
.SYNOPSIS
    Clear the entire identity registry.

.DESCRIPTION
    Removes all entries from both runtime and persisted registry.
    Use when debugging or when registry becomes corrupted.
#>
function Clear-WindowIdentityRegistry {
    Write-IdentityLog "Clearing identity registry..." -Level "INFO"

    $script:LaunchRegistry = @{}

    if (Test-Path $script:IdentityRegistryPath) {
        Remove-Item $script:IdentityRegistryPath -Force -ErrorAction SilentlyContinue
    }

    Write-IdentityLog "Identity registry cleared" -Level "INFO"
}

# --- INITIALIZATION ---

# Load persisted registry on module load
$persisted = Load-IdentityRegistry
if ($persisted) {
    $script:LaunchRegistry = $persisted
}

Write-IdentityLog "WindowIdentityService loaded ($($script:LaunchRegistry.Count) cached entries)" -Level "DEBUG"

# Export module functions (only when loaded as module)
# When dot-sourced as script, all functions are automatically available
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function @(
        'Register-MatrixWindowLaunch',
        'Get-AllMatrixWindows',
        'Resolve-WindowIdentity',
        'Test-WindowHandleValid',
        'Clean-WindowIdentityRegistry',
        'Clear-WindowIdentityRegistry',
        'Write-IdentityLog',
        'Enable-IdentityVerboseLogging',
        'Disable-IdentityVerboseLogging'
    )
}
