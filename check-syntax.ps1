$errors = $null
Write-Host "Checking matrix_control.ps1..."
$ast = [System.Management.Automation.Language.Parser]::ParseFile("$PSScriptRoot\matrix_control.ps1", [ref]$null, [ref]$errors)
if ($errors) {
    Write-Host "Syntax errors found:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host $_.ToString() }
} else {
    Write-Host "matrix_control.ps1: OK" -ForegroundColor Green
}

$errors = $null
Write-Host "Checking WindowLayoutEngine.ps1..."
$ast = [System.Management.Automation.Language.Parser]::ParseFile("$PSScriptRoot\WindowLayoutEngine.ps1", [ref]$null, [ref]$errors)
if ($errors) {
    Write-Host "Syntax errors found:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host $_.ToString() }
} else {
    Write-Host "WindowLayoutEngine.ps1: OK" -ForegroundColor Green
}
