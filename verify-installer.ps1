# verify-installer.ps1 - Verify installer exists and is reasonable size
$InstallerPath = "C:\Users\ehome\documents\matrix\installer\output\MatrixShaderSetup.exe"

if (-not (Test-Path $InstallerPath)) {
    Write-Host "ERROR: Installer not found at $InstallerPath" -ForegroundColor Red
    exit 1
}

$sizeMB = [math]::Round((Get-Item $InstallerPath).Length / 1MB, 1)
$timestamp = (Get-Item $InstallerPath).LastWriteTime

if ($sizeMB -lt 50) {
    Write-Host "WARNING: Installer is only $sizeMB MB (expected >50MB for self-contained builds)" -ForegroundColor Yellow
} else {
    Write-Host "Installer size OK: $sizeMB MB" -ForegroundColor Green
}

Write-Host "Installer path: $InstallerPath" -ForegroundColor Gray
Write-Host "Installer timestamp: $timestamp" -ForegroundColor Gray
