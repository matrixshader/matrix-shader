$scriptContent = Get-Content "C:\Users\ehome\Documents\MATRIX\matrix_control.ps1" -Raw
$mainIndex = $scriptContent.IndexOf('# Clean stale window registry')
if ($mainIndex -gt 0) { $scriptContent = $scriptContent.Substring(0, $mainIndex) }
Invoke-Expression $scriptContent

Write-Host "Existing slots: $(Get-ExistingSlots)" -ForegroundColor Cyan
Write-Host "Open slots: $(Get-OpenMatrixSlots)" -ForegroundColor Green
