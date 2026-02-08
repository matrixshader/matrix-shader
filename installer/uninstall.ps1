# Matrix Shader Uninstall Script
# Usage: irm https://matrixshader.com/uninstall.ps1 | iex
#
# Works with PowerShell 5.1 and 7+
# Removes Matrix Shader from your system

$ErrorActionPreference = 'Stop'

$AppName = 'MatrixShader'

# Detect admin privileges
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Possible install locations
$AdminInstallDir = "$env:ProgramFiles\$AppName"
$UserInstallDir = "$env:LOCALAPPDATA\Programs\$AppName"
$DataDir = "$env:LOCALAPPDATA\$AppName"

Write-Host ""
Write-Host "  Matrix Shader Uninstaller" -ForegroundColor Red
Write-Host "  =========================" -ForegroundColor Red
Write-Host ""

# Check for GUI (Inno Setup) installation first
$InnoUninstallExe = "$AdminInstallDir\unins000.exe"
$HasInnoInstall = Test-Path $InnoUninstallExe

# Detect all install locations
$Installs = @()

if (Test-Path "$AdminInstallDir\wakeupneo.exe") {
    if ($HasInnoInstall) {
        $Installs += @{ Dir = $AdminInstallDir; Scope = 'Machine'; Type = 'GUI installer' }
    } else {
        $Installs += @{ Dir = $AdminInstallDir; Scope = 'Machine'; Type = 'CLI (admin)' }
    }
}
if (Test-Path "$UserInstallDir\wakeupneo.exe") {
    $Installs += @{ Dir = $UserInstallDir; Scope = 'User'; Type = 'CLI (user)' }
}

if ($Installs.Count -eq 0) {
    Write-Host "  Matrix Shader not found in standard locations:" -ForegroundColor Yellow
    Write-Host "    - $AdminInstallDir"
    Write-Host "    - $UserInstallDir"
    Write-Host ""

    $InPath = $env:Path -split ';' | Where-Object { $_ -like '*MatrixShader*' }
    if ($InPath) {
        Write-Host "  Found in PATH: $($InPath -join ', ')" -ForegroundColor Yellow
        Write-Host "  You may need to remove this manually." -ForegroundColor Yellow
    }

    if (Test-Path $DataDir) {
        Write-Host ""
        Write-Host "  User data found: $DataDir" -ForegroundColor Yellow
        $RemoveData = Read-Host "  Remove user data (shaders, settings)? (y/N)"
        if ($RemoveData -eq 'y' -or $RemoveData -eq 'Y') {
            Remove-Item $DataDir -Recurse -Force
            Write-Host "  User data removed." -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "  Nothing to uninstall." -ForegroundColor Gray
    exit 0
}

# Show what was found
foreach ($inst in $Installs) {
    Write-Host "  Found: $($inst.Dir) ($($inst.Type))" -ForegroundColor Gray
}

# Admin check - need admin for Program Files
$NeedsAdmin = $Installs | Where-Object { $_.Scope -eq 'Machine' }
if ($NeedsAdmin -and -not $IsAdmin) {
    Write-Host ""
    Write-Host "ERROR: Matrix Shader is installed in Program Files." -ForegroundColor Red
    Write-Host "       Run this script as Administrator to uninstall." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Right-click PowerShell > Run as Administrator" -ForegroundColor Yellow
    Write-Host "  Then run: irm https://matrixshader.com/uninstall.ps1 | iex" -ForegroundColor Yellow
    exit 1
}

# Confirm uninstall
Write-Host ""
$Confirm = Read-Host "Uninstall Matrix Shader? (y/N)"
if ($Confirm -ne 'y' -and $Confirm -ne 'Y') {
    Write-Host "  Cancelled." -ForegroundColor Gray
    exit 0
}

Write-Host ""

# Step 1: Remove from PATH (both scopes)
Write-Host "[1/3] Removing from PATH..." -ForegroundColor Cyan
foreach ($scope in @('Machine', 'User')) {
    try {
        $CurrentPath = [Environment]::GetEnvironmentVariable('Path', $scope)
        if (-not $CurrentPath) { continue }
        $PathEntries = $CurrentPath -split ';' | Where-Object { $_.Trim() -ne '' }
        $NewEntries = $PathEntries | Where-Object { $_.ToLower() -notlike '*matrixshader*' }

        if ($NewEntries.Count -lt $PathEntries.Count) {
            $NewPath = $NewEntries -join ';'
            [Environment]::SetEnvironmentVariable('Path', $NewPath, $scope)
            Write-Host "  Removed from $scope PATH" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  WARNING: Could not update $scope PATH" -ForegroundColor Yellow
    }
}

# Step 2: Remove all installs
Write-Host "[2/3] Removing executables..." -ForegroundColor Cyan

# If GUI (Inno Setup) install exists, use its uninstaller
if ($HasInnoInstall) {
    Write-Host "  Running GUI uninstaller..." -ForegroundColor Gray
    try {
        Start-Process -FilePath $InnoUninstallExe -ArgumentList '/SILENT' -Wait -ErrorAction Stop
        Write-Host "  GUI version removed." -ForegroundColor Gray
    } catch {
        Write-Host "  WARNING: GUI uninstaller failed, removing manually..." -ForegroundColor Yellow
        if (Test-Path $AdminInstallDir) {
            Remove-Item $AdminInstallDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Remove all install directories
foreach ($inst in $Installs) {
    try {
        if (Test-Path $inst.Dir) {
            Remove-Item $inst.Dir -Recurse -Force
            Write-Host "  Removed: $($inst.Dir)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  ERROR: Could not remove $($inst.Dir)" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Try closing any Matrix Shader windows first." -ForegroundColor Yellow
    }
}

# Step 2.5: Restore original Windows Terminal settings
Write-Host "[2.5/3] Restoring Windows Terminal settings..." -ForegroundColor Cyan

$WTSettings = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)

$RestoredAny = $false
foreach ($SettingsPath in $WTSettings) {
    $OriginalBackup = "$SettingsPath.matrix-original"
    if (Test-Path $OriginalBackup) {
        try {
            Copy-Item $OriginalBackup $SettingsPath -Force
            Remove-Item $OriginalBackup -Force
            Write-Host "  Restored original settings: $([IO.Path]::GetDirectoryName($SettingsPath))" -ForegroundColor Gray
            $RestoredAny = $true
        }
        catch {
            Write-Host "  WARNING: Could not restore $SettingsPath" -ForegroundColor Yellow
            Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

if (-not $RestoredAny) {
    Write-Host "  No original backup found (may be clean install)" -ForegroundColor Gray
}

# Step 3: Handle user data
Write-Host "[3/3] User data..." -ForegroundColor Cyan
if (Test-Path $DataDir) {
    Write-Host "  Found user data: $DataDir" -ForegroundColor Gray
    Write-Host "  This includes:" -ForegroundColor Gray
    Write-Host "    - Custom shaders" -ForegroundColor Gray
    Write-Host "    - Session settings" -ForegroundColor Gray
    Write-Host "    - Window Terminal profiles (in WT settings)" -ForegroundColor Gray
    Write-Host ""
    $RemoveData = Read-Host "  Remove user data? (y/N)"
    if ($RemoveData -eq 'y' -or $RemoveData -eq 'Y') {
        try {
            Remove-Item $DataDir -Recurse -Force
            Write-Host "  User data removed." -ForegroundColor Green
        }
        catch {
            Write-Host "  WARNING: Could not remove user data" -ForegroundColor Yellow
            Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  User data preserved." -ForegroundColor Gray
    }
} else {
    Write-Host "  No user data found." -ForegroundColor Gray
}

# Done
Write-Host ""
Write-Host "  Matrix Shader uninstalled." -ForegroundColor Green
Write-Host ""
Write-Host "  Note: Windows Terminal settings have been restored to their original state." -ForegroundColor Yellow
Write-Host "  If you manually customized any Matrix profiles, those changes were also reverted." -ForegroundColor Yellow
Write-Host ""
