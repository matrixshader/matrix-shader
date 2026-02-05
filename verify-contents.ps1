# verify-contents.ps1 - Verify all installer contents
$ErrorActionPreference = 'Stop'
$PublishDir = 'C:\Users\ehome\documents\matrix\installer\publish'

# Verify all 6 executables
$exes = @('wakeupneo.exe', 'bluepill.exe', 'redpill.exe', 'matrixlite.exe', 'matrix-hotkeys.exe', 'matrix-monitor.exe')
Write-Host 'Verifying executables:' -ForegroundColor Cyan
foreach ($exe in $exes) {
    $path = Join-Path $PublishDir $exe
    if (Test-Path $path) {
        $size = [math]::Round((Get-Item $path).Length / 1KB, 0)
        Write-Host "  [OK] $exe ($size KB)" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $exe" -ForegroundColor Red
        exit 1
    }
}

# Verify shaders
$shaderDir = Join-Path $PublishDir 'shaders'
$shaderCount = (Get-ChildItem "$shaderDir\*.hlsl" -ErrorAction SilentlyContinue | Measure-Object).Count
if ($shaderCount -lt 5) {
    Write-Host "  [ERROR] Only $shaderCount shaders found (expected 5+)" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] $shaderCount shader files" -ForegroundColor Green

# Verify installer
$installer = 'C:\Users\ehome\documents\matrix\installer\output\MatrixShaderSetup.exe'
if (Test-Path $installer) {
    $sizeMB = [math]::Round((Get-Item $installer).Length / 1MB, 1)
    Write-Host "`nInstaller verified:" -ForegroundColor Cyan
    Write-Host "  [OK] MatrixShaderSetup.exe ($sizeMB MB)" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Installer not found" -ForegroundColor Red
    exit 1
}

Write-Host "`nAll verifications passed!" -ForegroundColor Green
