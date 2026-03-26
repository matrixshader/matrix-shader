$ErrorActionPreference = 'Stop'
$src = Join-Path $PSScriptRoot 'publish'
$installDir = "$env:LOCALAPPDATA\Programs\MatrixShader"
$shadersDir = "$env:LOCALAPPDATA\MatrixShader\shaders"

# Kill running Matrix processes before deploy (same as install.ps1)
$MatrixProcesses = @('matrix-hotkeys', 'matrix-monitor', 'redpill', 'bluepill', 'wakeupneo', 'matrixlite', 'construct')
$Killed = @()
foreach ($proc in $MatrixProcesses) {
    $running = Get-Process -Name $proc -ErrorAction SilentlyContinue
    if ($running) {
        $running | Stop-Process -Force -ErrorAction SilentlyContinue
        $Killed += $proc
    }
}
if ($Killed.Count -gt 0) {
    Write-Host "  Stopped: $($Killed -join ', ')" -ForegroundColor Yellow
    Start-Sleep -Seconds 1
}

# Create dirs if needed
if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
if (-not (Test-Path $shadersDir)) { New-Item -ItemType Directory -Path $shadersDir -Force | Out-Null }

# Copy all files from publish to install dir (except shaders subfolder)
Get-ChildItem -Path $src -File | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $installDir $_.Name) -Force
}

# Copy subdirectories (except shaders) recursively
Get-ChildItem -Path $src -Directory | Where-Object { $_.Name -ne 'shaders' } | ForEach-Object {
    $destSub = Join-Path $installDir $_.Name
    Copy-Item $_.FullName $destSub -Recurse -Force
}

# Copy non-Matrix shaders only (Redpill-Neo, WhiteRoom, etc.)
# Matrix-N.hlsl files are user-customized at runtime — never overwrite them on deploy
$srcShaders = Join-Path $src 'shaders'
if (Test-Path $srcShaders) {
    Get-ChildItem -Path $srcShaders -Filter '*.hlsl' | Where-Object { $_.Name -notmatch '^Matrix-\d+\.hlsl$' } | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $shadersDir $_.Name) -Force
    }
}

# Verify
Write-Host ""
Write-Host "=== Local Deploy Verification ===" -ForegroundColor Yellow
Write-Host "Install dir: $installDir"
Write-Host "Shaders dir: $shadersDir"
Write-Host ""

$exes = @('wakeupneo.exe','bluepill.exe','redpill.exe','construct.exe','matrixlite.exe','matrix-hotkeys.exe','matrix-monitor.exe')
foreach ($exe in $exes) {
    $p = Join-Path $installDir $exe
    if (Test-Path $p) {
        $info = Get-Item $p
        Write-Host "  OK: $exe ($($info.Length) bytes, $($info.LastWriteTime))" -ForegroundColor Green
    } else {
        Write-Host "  MISSING: $exe" -ForegroundColor Red
    }
}

$shaderCount = (Get-ChildItem $shadersDir -Filter '*.hlsl').Count
Write-Host ""
Write-Host "Shaders deployed: $shaderCount" -ForegroundColor Cyan

# Check Core DLL
$coreDll = Join-Path $installDir 'MatrixShader.Core.dll'
if (Test-Path $coreDll) {
    $info = Get-Item $coreDll
    Write-Host "  OK: MatrixShader.Core.dll ($($info.Length) bytes, $($info.LastWriteTime))" -ForegroundColor Green
}

# Restart background processes if Matrix windows are open
$matrixWindows = Get-Process -Name 'WindowsTerminal' -ErrorAction SilentlyContinue
if ($matrixWindows -and $Killed.Count -gt 0) {
    Write-Host ""
    Write-Host "=== Restarting Background Processes ===" -ForegroundColor Yellow

    # Start monitor only — its watchdog starts hotkeys automatically.
    # Starting both directly causes a race where two hotkeys instances spawn.
    $monitorExe = Join-Path $installDir 'matrix-monitor.exe'

    if (Test-Path $monitorExe) {
        Start-Process $monitorExe -WindowStyle Hidden
        Write-Host "  Started: matrix-monitor.exe (watchdog will start hotkeys)" -ForegroundColor Green
    }
} elseif ($Killed.Count -gt 0) {
    Write-Host ""
    Write-Host "  No Matrix windows open - skipping background process restart" -ForegroundColor DarkGray
}
