$scripts = @(
    "$PSScriptRoot\MatrixUtils.ps1",
    "$PSScriptRoot\install.ps1",
    "$PSScriptRoot\matrix_control.ps1",
    "$PSScriptRoot\matrix_setup.ps1",
    "$PSScriptRoot\matrix_hotkeys.ps1",
    "$PSScriptRoot\bluepill.ps1"
)

$failed = 0
foreach ($script in $scripts) {
    $name = Split-Path $script -Leaf
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$null, [ref]$errors)
    if ($errors.Count -gt 0) {
        Write-Host "FAIL: $name" -ForegroundColor Red
        foreach ($err in $errors) {
            Write-Host "  Line $($err.Extent.StartLineNumber): $($err.Message)" -ForegroundColor Yellow
        }
        $failed++
    } else {
        Write-Host "PASS: $name" -ForegroundColor Green
    }
}

if ($failed -eq 0) {
    Write-Host "`nAll syntax tests passed!" -ForegroundColor Green
} else {
    Write-Host "`n$failed script(s) failed syntax check" -ForegroundColor Red
}
