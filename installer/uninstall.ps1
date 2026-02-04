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

# Detect where it's installed
$InstallDir = $null
$PathScope = $null

if (Test-Path $AdminInstallDir) {
    if (-not $IsAdmin) {
        Write-Host "ERROR: Matrix Shader is installed in Program Files." -ForegroundColor Red
        Write-Host "       Run this script as Administrator to uninstall." -ForegroundColor Red
        Write-Host ""
        Write-Host "  Right-click PowerShell > Run as Administrator" -ForegroundColor Yellow
        Write-Host "  Then run: irm https://matrixshader.com/uninstall.ps1 | iex" -ForegroundColor Yellow
        exit 1
    }
    $InstallDir = $AdminInstallDir
    $PathScope = 'Machine'
    Write-Host "  Found installation: $InstallDir (admin)" -ForegroundColor Gray
}
elseif (Test-Path $UserInstallDir) {
    $InstallDir = $UserInstallDir
    $PathScope = 'User'
    Write-Host "  Found installation: $InstallDir (user)" -ForegroundColor Gray
}
else {
    Write-Host "  Matrix Shader not found in standard locations:" -ForegroundColor Yellow
    Write-Host "    - $AdminInstallDir"
    Write-Host "    - $UserInstallDir"
    Write-Host ""

    # Check if it's still in PATH somewhere
    $InPath = $env:Path -split ';' | Where-Object { $_ -like '*MatrixShader*' }
    if ($InPath) {
        Write-Host "  Found in PATH: $($InPath -join ', ')" -ForegroundColor Yellow
        Write-Host "  You may need to remove this manually." -ForegroundColor Yellow
    }

    # Check for user data
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

# Confirm uninstall
Write-Host ""
$Confirm = Read-Host "Uninstall Matrix Shader from $InstallDir? (y/N)"
if ($Confirm -ne 'y' -and $Confirm -ne 'Y') {
    Write-Host "  Cancelled." -ForegroundColor Gray
    exit 0
}

Write-Host ""

# Step 1: Remove from PATH
Write-Host "[1/3] Removing from PATH..." -ForegroundColor Cyan
try {
    $CurrentPath = [Environment]::GetEnvironmentVariable('Path', $PathScope)
    $PathEntries = $CurrentPath -split ';' | Where-Object { $_.Trim() -ne '' }

    # Remove any MatrixShader entries (case-insensitive)
    $NewEntries = $PathEntries | Where-Object { $_.ToLower() -ne $InstallDir.ToLower() }

    if ($NewEntries.Count -lt $PathEntries.Count) {
        $NewPath = $NewEntries -join ';'
        [Environment]::SetEnvironmentVariable('Path', $NewPath, $PathScope)
        Write-Host "  Removed from $PathScope PATH" -ForegroundColor Gray
    } else {
        Write-Host "  Not found in PATH" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  WARNING: Could not update PATH" -ForegroundColor Yellow
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step 2: Remove executables
Write-Host "[2/3] Removing executables..." -ForegroundColor Cyan
try {
    if (Test-Path $InstallDir) {
        Remove-Item $InstallDir -Recurse -Force
        Write-Host "  Removed: $InstallDir" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  ERROR: Could not remove $InstallDir" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Try closing any Matrix Shader windows first." -ForegroundColor Yellow
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
