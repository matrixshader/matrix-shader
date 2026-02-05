# Run the ACTUAL system detection from matrix_control.ps1
# Extract just the detection parts without running Main

$scriptContent = Get-Content "C:\Users\ehome\Documents\MATRIX\matrix_control.ps1" -Raw

# Find where Main starts and cut it off
$mainIndex = $scriptContent.IndexOf('# Main loop')
if ($mainIndex -gt 0) {
    $scriptContent = $scriptContent.Substring(0, $mainIndex)
}

# Execute the script content to load all functions
Invoke-Expression $scriptContent

# Now run the actual detection
Write-Host "Running Get-MatrixWindowInfo from the ACTUAL system:" -ForegroundColor Cyan
Write-Host ""

$info = Get-MatrixWindowInfo

foreach ($w in $info) {
    Write-Host "Slot $($w.Slot): Handle=$($w.Handle) Shader=$($w.ShaderFile)"
    Write-Host "  Title: '$($w.Title)'"
    Write-Host ""
}

Write-Host "Registry contents:" -ForegroundColor Yellow
if (Test-Path $windowRegistryPath) {
    Get-Content $windowRegistryPath
} else {
    Write-Host "(no registry file)"
}
