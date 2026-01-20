# test-debug-quads.ps1
# Debug Test 4 failure

. "$PSScriptRoot\WindowLayoutEngine.ps1"

$mockScreen = @{
    Index = 0
    Left = 0
    Top = 0
    Width = 1920
    Height = 1040
    IsPrimary = $true
}

Write-Host "Testing Get-QuadsLayout with 1 window..." -ForegroundColor Cyan
Write-Host "Screen: $($mockScreen | ConvertTo-Json -Compress)" -ForegroundColor Gray

$layout = Get-QuadsLayout -WindowCount 1 -Screens @($mockScreen) -GapSize 60 -Verbose

Write-Host "`nResult count: $($layout.Count)" -ForegroundColor Yellow
Write-Host "Result type: $($layout.GetType().FullName)" -ForegroundColor Yellow

if ($layout.Count -gt 0) {
    for ($i = 0; $i -lt $layout.Count; $i++) {
        $item = $layout[$i]
        Write-Host "`nItem ${i} type:" $item.GetType().FullName -ForegroundColor Magenta
        $json = $item | ConvertTo-Json -Compress
        Write-Host "Item ${i}: $json" -ForegroundColor Magenta
    }
}
