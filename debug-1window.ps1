. "$PSScriptRoot\WindowLayoutEngine.ps1"

$screens = @(@{
    Index = 0
    Left = 0
    Top = 0
    Width = 1920
    Height = 1040
    IsPrimary = $true
})

Write-Host "Testing 1 window on Pillars layout..."
$result = Get-PillarsLayout -WindowCount 1 -Screens $screens -MaxPillarsPerScreen 4 -GapSize 60
Write-Host "Result type: $($result.GetType().Name)"
Write-Host "Result count: $($result.Count)"
Write-Host "Result is array: $($result -is [array])"

if ($result -is [array]) {
    Write-Host "Array elements:"
    for ($i = 0; $i -lt $result.Count; $i++) {
        Write-Host "  [$i]: $($result[$i])"
    }
}

Write-Host "`nForEach output:"
$result | ForEach-Object {
    Write-Host "  Item type: $($_.GetType().Name)"
    Write-Host "  X=$($_.X) Y=$($_.Y) W=$($_.Width) H=$($_.Height) ScreenIndex=$($_.ScreenIndex)"
}
