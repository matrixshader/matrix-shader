$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Root = Join-Path $ProjectRoot "MatrixShader\src"
$Dest = Join-Path $PSScriptRoot "publish"

# Clean destination first
if (Test-Path $Dest) { Remove-Item $Dest -Recurse -Force }
New-Item -ItemType Directory -Path $Dest -Force | Out-Null

# Map: project publish dir -> destination
$projects = @(
    @{ Path = "$Root\MatrixShader.Cli\WakeupNeo\bin\Release\net8.0-windows\win-x64\publish" },
    @{ Path = "$Root\MatrixShader.Cli\Bluepill\bin\Release\net8.0-windows\win-x64\publish" },
    @{ Path = "$Root\MatrixShader.Cli\Redpill\bin\Release\net8.0-windows\win-x64\publish" },
    @{ Path = "$Root\MatrixShader.Cli\MatrixLite\bin\Release\net8.0-windows\win-x64\publish" },
    @{ Path = "$Root\MatrixShader.Cli\Matrix\bin\Release\net8.0-windows\win-x64\publish" },
    @{ Path = "$Root\MatrixShader.Hotkeys\bin\Release\net8.0-windows10.0.17763.0\win-x64\publish" },
    @{ Path = "$Root\MatrixShader.Monitor\bin\Release\net8.0-windows\win-x64\publish" },
    @{ Path = "$Root\MatrixShader.Lite\bin\Release\net8.0-windows\win-x64\publish" }
)

foreach ($proj in $projects) {
    $src = $proj.Path
    if (-not (Test-Path $src)) {
        Write-Host "MISSING: $src" -ForegroundColor Red
        continue
    }
    Write-Host "Copying from: $src" -ForegroundColor Cyan
    # Copy all files recursively, overwriting
    Get-ChildItem -Path $src -Recurse | ForEach-Object {
        $rel = $_.FullName.Substring($src.Length + 1)
        $destPath = Join-Path $Dest $rel
        if ($_.PSIsContainer) {
            if (-not (Test-Path $destPath)) { New-Item -ItemType Directory -Path $destPath -Force | Out-Null }
        } else {
            $parentDir = Split-Path $destPath -Parent
            if (-not (Test-Path $parentDir)) { New-Item -ItemType Directory -Path $parentDir -Force | Out-Null }
            Copy-Item $_.FullName $destPath -Force
        }
    }
}

# Now copy shaders
$shadersDir = Join-Path $ProjectRoot "MatrixShader\shaders"
$destShaders = Join-Path $Dest "shaders"
if (-not (Test-Path $destShaders)) { New-Item -ItemType Directory -Path $destShaders -Force | Out-Null }
Get-ChildItem -Path $shadersDir -Filter "*.hlsl" | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $destShaders $_.Name) -Force
    Write-Host "  Shader: $($_.Name)" -ForegroundColor Green
}

# Verify key executables
$exes = @('wakeupneo.exe', 'bluepill.exe', 'redpill.exe', 'matrix.exe', 'matrixlite.exe', 'matrix-hotkeys.exe', 'matrix-monitor.exe')
Write-Host ""
Write-Host "=== Verification ===" -ForegroundColor Yellow
foreach ($exe in $exes) {
    $p = Join-Path $Dest $exe
    if (Test-Path $p) {
        $info = Get-Item $p
        Write-Host "  OK: $exe ($($info.Length) bytes, $($info.LastWriteTime))" -ForegroundColor Green
    } else {
        Write-Host "  MISSING: $exe" -ForegroundColor Red
    }
}

# Check Core DLL
$coreDll = Join-Path $Dest "MatrixShader.Core.dll"
if (Test-Path $coreDll) {
    $info = Get-Item $coreDll
    Write-Host "  OK: MatrixShader.Core.dll ($($info.Length) bytes, $($info.LastWriteTime))" -ForegroundColor Green
}

Write-Host ""
$totalFiles = (Get-ChildItem $Dest -Recurse -File).Count
Write-Host "Total files: $totalFiles" -ForegroundColor Cyan
