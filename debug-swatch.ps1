. "$PSScriptRoot\MatrixUtils.ps1"
$swatch = Swatch 0.0 0.5 1.0 2
Write-Host "Actual swatch: [$swatch]"
$g = [int](0.5 * 255)
Write-Host "Expected G value: $g"
Write-Host "Match 127: $($swatch -match '127')"
Write-Host "Match 128: $($swatch -match '128')"
