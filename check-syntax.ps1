# Check syntax of core PowerShell files
$files = @(
    "matrix_control.ps1",
    "matrix_setup.ps1",
    "matrix_hotkeys.ps1",
    "WindowLayoutEngine.ps1",
    "WindowIdentityService.ps1"
)

Write-Host "=== Syntax Check ===" -ForegroundColor Cyan
$allOk = $true
foreach ($file in $files) {
    $path = Join-Path $PSScriptRoot $file
    if (-not (Test-Path $path)) {
        Write-Host "$file : NOT FOUND" -ForegroundColor Red
        continue
    }

    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors)

    if ($errors.Count -eq 0) {
        Write-Host "$file : OK" -ForegroundColor Green
    } else {
        Write-Host "$file : $($errors.Count) ERRORS" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host "  - $($_.Message)" -ForegroundColor Yellow }
        $allOk = $false
    }
}

if ($allOk) {
    Write-Host ""
    Write-Host "All files passed syntax check!" -ForegroundColor Cyan
}
