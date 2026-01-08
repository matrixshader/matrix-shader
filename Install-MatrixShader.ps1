# ======================================================
# MATRIX SHADER INSTALLER
# Installs the Matrix rain effect for Windows Terminal
# ======================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host " ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host " ║         MATRIX SHADER INSTALLER                          ║" -ForegroundColor Green
Write-Host " ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# --- PATHS ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceShader = Join-Path $ScriptDir "Matrix.hlsl"
$SourceController = Join-Path $ScriptDir "matrix_tool.ps1"
$DestShader = "$env:USERPROFILE\Documents\Matrix.hlsl"
$DestController = "$env:USERPROFILE\Documents\matrix_tool.ps1"

# Windows Terminal settings paths (try both locations)
$WTSettingsStore = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$WTSettingsPreview = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
$WTSettingsUnpackaged = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"

# --- STEP 1: Check source files exist ---
Write-Host " [1/4] Checking source files..." -ForegroundColor Cyan

if (-not (Test-Path $SourceShader)) {
    Write-Host "   ERROR: Matrix.hlsl not found in script directory!" -ForegroundColor Red
    Write-Host "   Expected: $SourceShader" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $SourceController)) {
    Write-Host "   ERROR: matrix_tool.ps1 not found in script directory!" -ForegroundColor Red
    Write-Host "   Expected: $SourceController" -ForegroundColor Red
    exit 1
}

Write-Host "   Found Matrix.hlsl" -ForegroundColor Green
Write-Host "   Found matrix_tool.ps1" -ForegroundColor Green

# --- STEP 2: Copy files ---
Write-Host ""
Write-Host " [2/4] Copying files to Documents..." -ForegroundColor Cyan

try {
    Copy-Item -Path $SourceShader -Destination $DestShader -Force
    Write-Host "   Copied Matrix.hlsl -> $DestShader" -ForegroundColor Green

    Copy-Item -Path $SourceController -Destination $DestController -Force
    Write-Host "   Copied matrix_tool.ps1 -> $DestController" -ForegroundColor Green
} catch {
    Write-Host "   ERROR: Failed to copy files - $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# --- STEP 3: Find Windows Terminal settings ---
Write-Host ""
Write-Host " [3/4] Locating Windows Terminal settings..." -ForegroundColor Cyan

$WTSettings = $null
if (Test-Path $WTSettingsStore) {
    $WTSettings = $WTSettingsStore
    Write-Host "   Found: Windows Terminal (Store)" -ForegroundColor Green
} elseif (Test-Path $WTSettingsPreview) {
    $WTSettings = $WTSettingsPreview
    Write-Host "   Found: Windows Terminal Preview" -ForegroundColor Green
} elseif (Test-Path $WTSettingsUnpackaged) {
    $WTSettings = $WTSettingsUnpackaged
    Write-Host "   Found: Windows Terminal (Unpackaged)" -ForegroundColor Green
} else {
    Write-Host "   WARNING: Could not find Windows Terminal settings.json" -ForegroundColor Yellow
    Write-Host "   You'll need to manually add the shader path to your profile." -ForegroundColor Yellow
}

# --- STEP 4: Update settings.json ---
Write-Host ""
Write-Host " [4/4] Configuring Windows Terminal..." -ForegroundColor Cyan

if ($WTSettings) {
    # Backup existing settings
    $BackupPath = "$WTSettings.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item -Path $WTSettings -Destination $BackupPath -Force
    Write-Host "   Backed up settings to: $BackupPath" -ForegroundColor Gray

    # Read and parse settings
    $settingsContent = Get-Content $WTSettings -Raw

    # Check if shader is already configured
    if ($settingsContent -match "experimental\.pixelShaderPath") {
        Write-Host "   Shader path already configured in settings.json" -ForegroundColor Yellow
        Write-Host "   Verify it points to: $DestShader" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "   To enable the shader, add this to your Windows Terminal profile:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   `"experimental.pixelShaderPath`": `"$($DestShader -replace '\\', '\\\\')`"" -ForegroundColor White
        Write-Host ""
        Write-Host "   Open Settings (Ctrl+,) -> Open JSON file -> Add to your profile" -ForegroundColor Gray
    }
} else {
    Write-Host "   Skipped (Windows Terminal not found)" -ForegroundColor Yellow
}

# --- DONE ---
Write-Host ""
Write-Host " ══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host " INSTALLATION COMPLETE!" -ForegroundColor Green
Write-Host " ══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host " Files installed to:" -ForegroundColor Cyan
Write-Host "   $DestShader"
Write-Host "   $DestController"
Write-Host ""
Write-Host " TO START THE MATRIX EFFECT:" -ForegroundColor Cyan
Write-Host ""
Write-Host "   1. Open Windows Terminal Settings (Ctrl+,)" -ForegroundColor White
Write-Host "   2. Click 'Open JSON file' at bottom left" -ForegroundColor White
Write-Host "   3. Find your profile and add:" -ForegroundColor White
Write-Host ""
Write-Host "      `"experimental.pixelShaderPath`": `"C:\\Users\\$env:USERNAME\\Documents\\Matrix.hlsl`"" -ForegroundColor Yellow
Write-Host ""
Write-Host "   4. Save and restart Windows Terminal" -ForegroundColor White
Write-Host "   5. Run the controller:" -ForegroundColor White
Write-Host ""
Write-Host "      cd ~\Documents" -ForegroundColor Yellow
Write-Host "      .\matrix_tool.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host " Press H for help, 1-6 for color presets, Q to quit" -ForegroundColor Gray
Write-Host ""
