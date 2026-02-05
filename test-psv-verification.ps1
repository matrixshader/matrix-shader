# PSV FORMAL VERIFICATION
# Propose-Solve-Verify methodology for Matrix Terminal Shader refactoring

Set-Location $PSScriptRoot
$ErrorActionPreference = "Continue"

$passed = 0
$failed = 0

function Verify($name, $success, $msg = "") {
    if ($success) {
        Write-Host "  [VERIFIED] $name" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  [VIOLATED] $name" -ForegroundColor Red
        if ($msg) { Write-Host "             $msg" -ForegroundColor Yellow }
        $script:failed++
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " PSV FORMAL VERIFICATION" -ForegroundColor Cyan
Write-Host " Matrix Terminal Shader Refactoring" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

#============================================================
# PHASE 1: SYNTAX VERIFICATION
#============================================================
Write-Host "[PHASE 1] SYNTAX PARSING" -ForegroundColor Yellow
Write-Host "Specification: All scripts must parse without syntax errors" -ForegroundColor DarkGray

$scripts = @(
    'MatrixUtils.ps1',
    'MatrixLogging.ps1',
    'WindowLayoutEngine.ps1',
    'WindowIdentityService.ps1',
    'install.ps1',
    'matrix_control.ps1',
    'matrix_setup.ps1',
    'matrix_hotkeys.ps1',
    'bluepill.ps1'
)

$allSyntaxPass = $true
foreach ($s in $scripts) {
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PWD $s), [ref]$null, [ref]$errs)
    if ($errs.Count -gt 0) {
        Verify $s $false "Syntax errors found"
        $allSyntaxPass = $false
    } else {
        Verify $s $true
    }
}

#============================================================
# PHASE 2: IMPORT CHAIN VERIFICATION
#============================================================
Write-Host ""
Write-Host "[PHASE 2] IMPORT CHAIN" -ForegroundColor Yellow
Write-Host "Specification: All dot-source imports resolve without errors" -ForegroundColor DarkGray
Write-Host "Precondition: All source files exist at `$PSScriptRoot" -ForegroundColor DarkGray

try {
    . .\MatrixUtils.ps1
    . .\MatrixLogging.ps1
    . .\WindowLayoutEngine.ps1
    . .\WindowIdentityService.ps1

    # Postcondition: All required functions available
    $required = @(
        @{Name='Swatch'; Spec='Alias for Get-ColorSwatch'},
        @{Name='Get-ColorSwatch'; Spec='RGB color swatch generator'},
        @{Name='Get-PrimaryScreenDimensions'; Spec='Screen dimension provider'},
        @{Name='Write-MatrixLog'; Spec='Unified logging function'},
        @{Name='Get-AllMatrixWindows'; Spec='Window identity service'},
        @{Name='Invoke-MatrixWindowLayout'; Spec='Window layout engine'},
        @{Name='Get-ExistingWindowHandles'; Spec='Handle enumeration'},
        @{Name='Wait-ForNewMatrixWindow'; Spec='Window launch polling'},
        @{Name='Register-MatrixWindowByHandle'; Spec='Window registration'}
    )

    foreach ($fn in $required) {
        $exists = Get-Command $fn.Name -ErrorAction SilentlyContinue
        Verify "$($fn.Name) ($($fn.Spec))" ($null -ne $exists)
    }
} catch {
    Verify "Import chain" $false $_.Exception.Message
}

#============================================================
# PHASE 3: FUNCTION CONTRACT VERIFICATION
#============================================================
Write-Host ""
Write-Host "[PHASE 3] FUNCTION CONTRACTS" -ForegroundColor Yellow
Write-Host "Specification: Functions meet their declared contracts" -ForegroundColor DarkGray

# Contract 1: Get-ColorSwatch
Write-Host "  Contract: Get-ColorSwatch(R,G,B,Width) -> ANSI string" -ForegroundColor DarkGray
Write-Host "  Precond: 0 <= R,G,B (clamped); Width >= 0" -ForegroundColor DarkGray
Write-Host "  Postcond: Returns valid ANSI escape sequence" -ForegroundColor DarkGray

$test1 = Swatch 0 0 0 2
Verify "Black (0,0,0) produces [48;2;0;0;0m" ($test1 -match '\[48;2;0;0;0m')

$test2 = Swatch 1 1 1 2
Verify "White (1,1,1) produces [48;2;255;255;255m" ($test2 -match '\[48;2;255;255;255m')

$test3 = Swatch -1 2 0.5 2
Verify "Clamps out-of-range values" ($test3 -match '\[48;2;0;255;128m')

$test4 = Swatch 0 1 0 4
Verify "Width=4 produces 4 spaces" ($test4 -match '    ')

# Contract 2: Get-PrimaryScreenDimensions
Write-Host ""
Write-Host "  Contract: Get-PrimaryScreenDimensions() -> {Width,Height,Left,Top}" -ForegroundColor DarkGray
Write-Host "  Postcond: Returns hashtable with positive dimensions" -ForegroundColor DarkGray

$dims = Get-PrimaryScreenDimensions
Verify "Width > 0" ($dims.Width -gt 0)
Verify "Height > 0" ($dims.Height -gt 0)
Verify "Contains Left" ($null -ne $dims.Left)
Verify "Contains Top" ($null -ne $dims.Top)

#============================================================
# PHASE 4: DEAD CODE ELIMINATION VERIFICATION
#============================================================
Write-Host ""
Write-Host "[PHASE 4] DEAD CODE ELIMINATION" -ForegroundColor Yellow
Write-Host "Specification: No references to removed classes/functions" -ForegroundColor DarkGray

$mainScripts = @('bluepill.ps1', 'matrix_setup.ps1', 'matrix_control.ps1', 'matrix_hotkeys.ps1', 'install.ps1')
$deadRefs = @(
    @{Pattern='BluepillAPI'; Desc='Removed P/Invoke class'},
    @{Pattern='WindowPositioning'; Desc='Removed P/Invoke class'},
    @{Pattern='SHOW_TERMINAL_CONTENT'; Desc='Non-existent shader define'},
    @{Pattern='BASE_OPACITY'; Desc='Non-existent shader define'},
    @{Pattern='function Get-MatrixWindows[^I]'; Desc='Deprecated function'}
)

foreach ($ref in $deadRefs) {
    $found = $false
    foreach ($script in $mainScripts) {
        $content = Get-Content $script -Raw
        if ($content -match $ref.Pattern) {
            $found = $true
            Verify "No '$($ref.Pattern)' in $script" $false $ref.Desc
        }
    }
    if (-not $found) {
        Verify "No '$($ref.Pattern)' ($($ref.Desc))" $true
    }
}

#============================================================
# PHASE 5: SAFETY PROPERTY VERIFICATION
#============================================================
Write-Host ""
Write-Host "[PHASE 5] SAFETY PROPERTIES" -ForegroundColor Yellow
Write-Host "Specification: Atomic writes, error handling, temp cleanup" -ForegroundColor DarkGray

# Atomic write pattern
$filesWithWrites = @('install.ps1', 'matrix_setup.ps1', 'matrix_hotkeys.ps1', 'matrix_control.ps1')
foreach ($file in $filesWithWrites) {
    $content = Get-Content $file -Raw
    if ($content -match 'Out-File.*settings\.json' -or $content -match 'WriteAllText.*settings\.json') {
        # Direct write to settings.json - bad
        Verify "$file uses atomic write" ($content -match 'GetTempFileName.*Move-Item|Move-Item.*-Force')
    } else {
        # Check for temp file pattern
        $usesTemp = $content -match 'GetTempFileName'
        $usesMove = $content -match 'Move-Item.*-Force'
        if ($content -match 'ConvertTo-Json') {
            Verify "$file atomic write pattern" ($usesTemp -and $usesMove)
        }
    }
}

# Temp file cleanup in catch blocks
foreach ($file in $filesWithWrites) {
    $content = Get-Content $file -Raw
    if ($content -match 'catch') {
        Verify "$file cleans temp on error" ($content -match 'Remove-Item.*tempFile')
    }
}

#============================================================
# SUMMARY
#============================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " VERIFICATION RESULT" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Verified: $passed" -ForegroundColor Green
Write-Host "Violated: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($failed -eq 0) {
    Write-Host "ALL SPECIFICATIONS VERIFIED" -ForegroundColor Green
    Write-Host ""
    Write-Host "Proof Map:" -ForegroundColor Cyan
    Write-Host "  - Syntax correctness: PowerShell Parser verification" -ForegroundColor DarkGray
    Write-Host "  - Import chain: Runtime dot-source verification" -ForegroundColor DarkGray
    Write-Host "  - Function contracts: Input/output boundary tests" -ForegroundColor DarkGray
    Write-Host "  - Dead code: Regex pattern scanning" -ForegroundColor DarkGray
    Write-Host "  - Safety: Atomic write pattern matching" -ForegroundColor DarkGray
    Write-Host ""
    exit 0
} else {
    Write-Host "VERIFICATION FAILED - $failed violation(s)" -ForegroundColor Red
    exit 1
}
