# Set gap size and create initial config
. "$PSScriptRoot\WindowLayoutEngine.ps1"

$config = Get-MatrixLayoutConfig
Write-Host "Current config:" -ForegroundColor Cyan
$config | Format-List

# Increase gap size to 100 pixels (more visible spacing between windows)
$config.GapSize = 100
$config.Mode = 'Pillars'

Set-MatrixLayoutConfig -Config $config

Write-Host ""
Write-Host "Updated config:" -ForegroundColor Green
$newConfig = Get-MatrixLayoutConfig
$newConfig | Format-List
