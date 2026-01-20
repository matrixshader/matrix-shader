# Position windows using the NEW UI Automation detection

# Load just the functions we need, stop before runtime code
$scriptContent = Get-Content "C:\Users\ehome\Documents\MATRIX\matrix_control.ps1" -Raw

# Find where runtime code starts (Clean-WindowRegistry call) and cut it off
$mainIndex = $scriptContent.IndexOf('# Clean stale window registry')
if ($mainIndex -gt 0) {
    $scriptContent = $scriptContent.Substring(0, $mainIndex)
}

# Execute the script content to load all functions
Invoke-Expression $scriptContent

Write-Host "Detecting windows with UI Automation..." -ForegroundColor Cyan
$info = Get-MatrixWindowInfo

Write-Host ""
Write-Host "Detection results (sorted by slot):" -ForegroundColor Yellow
foreach ($w in $info) {
    Write-Host "  Slot $($w.Slot): Handle=$($w.Handle) ShaderFile=$($w.ShaderFile)"
    Write-Host "           Title: '$($w.Title)'"
}

Write-Host ""
Write-Host "Positioning windows (Slot 1=left, Slot 2=middle, etc.)..." -ForegroundColor Cyan
Position-MatrixWindows

Write-Host ""
Write-Host "Verifying positions..." -ForegroundColor Cyan
$info2 = Get-MatrixWindowInfo
foreach ($w in $info2) {
    $rect = New-Object WindowAPI+RECT
    [WindowAPI]::GetWindowRect($w.Handle, [ref]$rect) | Out-Null
    Write-Host "  Slot $($w.Slot) now at X=$($rect.Left)"
}

Write-Host ""
Write-Host "DONE!" -ForegroundColor Green
