# MATRIX CLI INSTALLER
# Run once to set up the Matrix terminal system

$ErrorActionPreference = "Stop"

$matrixDir = "$env:USERPROFILE\Documents\Matrix"
$shadersDir = "$matrixDir\shaders"
$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

Write-Host ""
Write-Host " MATRIX CLI INSTALLER" -ForegroundColor Green
Write-Host " ========================================" -ForegroundColor DarkGray
Write-Host ""

# --- Step 1: Create directories ---
try {
    if (-not (Test-Path $matrixDir)) {
        New-Item -ItemType Directory -Path $matrixDir -Force | Out-Null
        Write-Host " [OK] Created Matrix directory" -ForegroundColor Cyan
    }
    if (-not (Test-Path $shadersDir)) {
        New-Item -ItemType Directory -Path $shadersDir -Force | Out-Null
        Write-Host " [OK] Created shaders directory" -ForegroundColor Cyan
    } else {
        Write-Host " [OK] Shaders directory exists" -ForegroundColor Cyan
    }
} catch {
    Write-Host " [ERROR] Failed to create directories: $_" -ForegroundColor Red
    exit 1
}

# --- Step 2: Copy shaders from package (only if not already present) ---
$packageShadersDir = Join-Path $PSScriptRoot "shaders"
if (Test-Path $packageShadersDir) {
    try {
        $shaderFiles = Get-ChildItem -Path $packageShadersDir -Filter "*.hlsl"
        $copiedCount = 0
        $skippedCount = 0
        foreach ($shader in $shaderFiles) {
            $dest = Join-Path $shadersDir $shader.Name
            if (-not (Test-Path $dest)) {
                Copy-Item -Path $shader.FullName -Destination $dest -Force
                $copiedCount++
            } else {
                $skippedCount++
            }
        }
        if ($copiedCount -gt 0) {
            Write-Host " [OK] Copied $copiedCount new shader files" -ForegroundColor Cyan
        }
        if ($skippedCount -gt 0) {
            Write-Host " [OK] Preserved $skippedCount existing shader files" -ForegroundColor Cyan
        }
    } catch {
        Write-Host " [WARN] Could not copy shaders: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host " [WARN] Package shaders not found at: $packageShadersDir" -ForegroundColor Yellow
}

# --- Step 3: Create default state files ---
$stateFile = "$matrixDir\matrix_state.json"
if (-not (Test-Path $stateFile)) {
    try {
        $defaultState = @{
            lastSlots = @(1)
            lastSaved = (Get-Date).ToString("o")
        }
        $defaultState | ConvertTo-Json | Out-File -FilePath $stateFile -Encoding UTF8
        Write-Host " [OK] Created default state file" -ForegroundColor Cyan
    } catch {
        Write-Host " [WARN] Could not create state file: $_" -ForegroundColor Yellow
    }
}

$identityFile = "$matrixDir\identity-registry.json"
if (-not (Test-Path $identityFile)) {
    try {
        @{} | ConvertTo-Json | Out-File -FilePath $identityFile -Encoding UTF8
        Write-Host " [OK] Created identity registry" -ForegroundColor Cyan
    } catch {
        Write-Host " [WARN] Could not create identity registry: $_" -ForegroundColor Yellow
    }
}

$windowFile = "$matrixDir\window-registry.json"
if (-not (Test-Path $windowFile)) {
    try {
        @{} | ConvertTo-Json | Out-File -FilePath $windowFile -Encoding UTF8
        Write-Host " [OK] Created window registry" -ForegroundColor Cyan
    } catch {
        Write-Host " [WARN] Could not create window registry: $_" -ForegroundColor Yellow
    }
}

# --- Step 4: Add to PATH ---
try {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$matrixDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$matrixDir", "User")
        Write-Host " [OK] Added Matrix to PATH" -ForegroundColor Cyan
        Write-Host "      (Restart terminal for PATH to take effect)" -ForegroundColor DarkGray
    } else {
        Write-Host " [OK] Matrix already in PATH" -ForegroundColor Cyan
    }
} catch {
    Write-Host " [WARN] Could not modify PATH: $_" -ForegroundColor Yellow
    Write-Host "        You may need to add $matrixDir to PATH manually" -ForegroundColor DarkGray
}

# --- Step 5: Configure Windows Terminal profiles ---
Write-Host ""
Write-Host " Configuring Windows Terminal profiles..." -ForegroundColor Cyan

# Check if Windows Terminal settings exist
if (-not (Test-Path $wtSettingsPath)) {
    Write-Host " [ERROR] Windows Terminal settings not found at:" -ForegroundColor Red
    Write-Host "         $wtSettingsPath" -ForegroundColor DarkGray
    Write-Host "         Please install Windows Terminal first." -ForegroundColor Yellow
    exit 1
}

# Create backup before modifying
$backupPath = "$wtSettingsPath.matrix-backup"
try {
    Copy-Item -Path $wtSettingsPath -Destination $backupPath -Force
    Write-Host " [OK] Created settings backup" -ForegroundColor DarkGray
} catch {
    Write-Host " [WARN] Could not create backup: $_" -ForegroundColor Yellow
}

# Read and parse settings with error handling
$wt = $null
try {
    $content = Get-Content $wtSettingsPath -Raw -ErrorAction Stop
    $wt = $content | ConvertFrom-Json -ErrorAction Stop
} catch [System.IO.IOException] {
    Write-Host " [ERROR] Cannot read settings.json (file may be locked)" -ForegroundColor Red
    Write-Host "         Close Windows Terminal and try again" -ForegroundColor Yellow
    exit 1
} catch {
    Write-Host " [ERROR] Settings.json is malformed or corrupted" -ForegroundColor Red
    Write-Host "         Error: $_" -ForegroundColor DarkGray
    if (Test-Path $backupPath) {
        Write-Host "         Backup preserved at: $backupPath" -ForegroundColor Yellow
    }
    exit 1
}

# Check if Matrix profiles already exist
$existingMatrix = @($wt.profiles.list | Where-Object { $_.name -like "Matrix-*" })
if ($existingMatrix.Count -gt 0) {
    Write-Host " [OK] Matrix profiles already configured ($($existingMatrix.Count) found)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " ========================================" -ForegroundColor DarkGray
    Write-Host " INSTALLATION COMPLETE" -ForegroundColor Green
    Write-Host ""
    Write-Host " Commands: wakeupneo, bluepill, redpill" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# No existing profiles - create them
$matrixProfiles = @()
for ($i = 1; $i -le 8; $i++) {
    $guid = "{$([guid]::NewGuid().ToString())}"
    $matrixProfiles += @{
        name = "Matrix-$i"
        guid = $guid
        commandline = "powershell.exe -NoExit -Command `"Write-Host ' Matrix Terminal $i' -ForegroundColor Green`""
        hidden = $true
        opacity = 95
        "experimental.pixelShaderPath" = "$shadersDir\Matrix-$i.hlsl"
    }
}

# Add Redpill profile for control panel
$redpillGuid = "{$([guid]::NewGuid().ToString())}"
$matrixProfiles += @{
    name = "Redpill"
    guid = $redpillGuid
    commandline = "powershell.exe -NoExit -ExecutionPolicy Bypass -File `"$matrixDir\matrix_control.ps1`""
    hidden = $true
    opacity = 95
    "experimental.pixelShaderPath" = "$shadersDir\Redpill-Neo.hlsl"
}

# Prepend Matrix profiles to list
$wt.profiles.list = @($matrixProfiles) + @($wt.profiles.list)

# Write back using atomic write pattern (US-001)
try {
    $tempFile = [System.IO.Path]::GetTempFileName()
    $wt | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempFile -Encoding UTF8
    Move-Item -Path $tempFile -Destination $wtSettingsPath -Force
    Write-Host " [OK] Created 8 Matrix profiles + Redpill control panel" -ForegroundColor Cyan
} catch {
    Write-Host " [ERROR] Failed to save settings: $_" -ForegroundColor Red
    # Attempt rollback
    if (Test-Path $backupPath) {
        try {
            Copy-Item -Path $backupPath -Destination $wtSettingsPath -Force
            Write-Host " [OK] Rolled back to backup" -ForegroundColor Yellow
        } catch {
            Write-Host " [ERROR] Rollback failed! Backup at: $backupPath" -ForegroundColor Red
        }
    }
    # Clean up temp file
    if ($tempFile -and (Test-Path $tempFile)) {
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    }
    exit 1
}

# Clean up backup on success (optional - keep for safety)
# Remove-Item -Path $backupPath -Force -ErrorAction SilentlyContinue

# --- Step 6: Detect monitors and ask user preference ---
Write-Host ""
Write-Host " Detecting monitors..." -ForegroundColor Cyan

# Detect monitor count using .NET
Add-Type -AssemblyName System.Windows.Forms
$detectedMonitors = [System.Windows.Forms.Screen]::AllScreens.Count

$monitorChoice = 1

if ($detectedMonitors -eq 1) {
    # Only 1 monitor - no need to ask
    Write-Host " [OK] 1 monitor detected" -ForegroundColor Cyan
} else {
    # Multiple monitors - ask user
    Write-Host ""
    Write-Host " $detectedMonitors monitors detected. How many do you want to use?" -ForegroundColor White
    Write-Host ""

    # Show options 1 through detected count
    for ($i = 1; $i -le $detectedMonitors; $i++) {
        Write-Host "   [$i] $i monitor$(if ($i -gt 1) { 's' })" -ForegroundColor Yellow
    }
    Write-Host ""

    # Get user choice
    $validChoice = $false
    while (-not $validChoice) {
        $input = Read-Host " Enter choice (1-$detectedMonitors)"
        if ($input -match '^\d+$') {
            $num = [int]$input
            if ($num -ge 1 -and $num -le $detectedMonitors) {
                $monitorChoice = $num
                $validChoice = $true
            }
        }
        if (-not $validChoice) {
            Write-Host " Please enter a number between 1 and $detectedMonitors" -ForegroundColor Red
        }
    }
}

# Save monitor preference to state file
try {
    $stateFile = "$matrixDir\matrix_state.json"
    if (Test-Path $stateFile) {
        $state = Get-Content $stateFile -Raw | ConvertFrom-Json
    } else {
        $state = @{}
    }

    # Ensure layout section exists
    if (-not $state.layout) {
        $state | Add-Member -NotePropertyName 'layout' -NotePropertyValue @{} -Force
    }

    # Set monitor count
    $state.layout.monitorCount = $monitorChoice
    $state.layout.gapSize = 30
    $state.layout.maxPillarsPerScreen = 4
    $state.layout.glitchEnabled = $true
    $state.layout.mode = 'Pillars'
    $state.layout.preferredScreen = 0

    $state | ConvertTo-Json -Depth 5 | Out-File -FilePath $stateFile -Encoding UTF8
    Write-Host " [OK] Saved: Using $monitorChoice monitor(s)" -ForegroundColor Cyan
} catch {
    Write-Host " [WARN] Could not save monitor preference: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host " ========================================" -ForegroundColor DarkGray
Write-Host " INSTALLATION COMPLETE" -ForegroundColor Green
Write-Host ""
Write-Host " Commands available (after restarting terminal):" -ForegroundColor White
Write-Host "   wakeupneo  - Setup wizard (pick colors, launch windows)" -ForegroundColor Yellow
Write-Host "   redpill    - Control panel (live adjustments)" -ForegroundColor Yellow
Write-Host "   bluepill   - Quick launch with last settings" -ForegroundColor Yellow
Write-Host ""
Write-Host " To uninstall, remove Matrix profiles from Windows Terminal settings" -ForegroundColor DarkGray
Write-Host " Backup saved at: $backupPath" -ForegroundColor DarkGray
Write-Host ""
