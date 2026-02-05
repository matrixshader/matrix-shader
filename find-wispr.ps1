# Find Wispr Flow and open its settings

Write-Host "=== Looking for Wispr Flow ===" -ForegroundColor Cyan

# Check running processes
$procs = Get-Process | Where-Object { $_.ProcessName -match "wispr|flow" }
if ($procs) {
    Write-Host "Running processes:" -ForegroundColor Green
    foreach ($p in $procs) {
        Write-Host "  $($p.ProcessName) (PID: $($p.Id))" -ForegroundColor Yellow
        try {
            $path = $p.MainModule.FileName
            Write-Host "    Path: $path" -ForegroundColor Gray
        } catch {}
    }
}

# Check common install locations
$searchPaths = @(
    "$env:LOCALAPPDATA\Programs",
    "$env:LOCALAPPDATA",
    "$env:APPDATA",
    "C:\Program Files",
    "C:\Program Files (x86)"
)

Write-Host ""
Write-Host "Searching install locations..." -ForegroundColor Cyan

foreach ($basePath in $searchPaths) {
    if (Test-Path $basePath) {
        $found = Get-ChildItem $basePath -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "wispr|flow" }
        foreach ($dir in $found) {
            Write-Host "  Found: $($dir.FullName)" -ForegroundColor Green
            # Look for exe files
            $exes = Get-ChildItem $dir.FullName -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue
            foreach ($exe in $exes) {
                Write-Host "    EXE: $($exe.FullName)" -ForegroundColor Yellow
            }
        }
    }
}

# Check startup folder
Write-Host ""
Write-Host "Checking startup items..." -ForegroundColor Cyan
$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
if (Test-Path $startupPath) {
    $startupItems = Get-ChildItem $startupPath | Where-Object { $_.Name -match "wispr|flow" }
    foreach ($item in $startupItems) {
        Write-Host "  Startup: $($item.FullName)" -ForegroundColor Yellow
    }
}

# Check registry for installed apps
Write-Host ""
Write-Host "Checking installed programs registry..." -ForegroundColor Cyan
$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
)
foreach ($regPath in $regPaths) {
    if (Test-Path $regPath) {
        $apps = Get-ChildItem $regPath -ErrorAction SilentlyContinue |
            Get-ItemProperty -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -match "wispr|flow" }
        foreach ($app in $apps) {
            Write-Host "  Installed: $($app.DisplayName)" -ForegroundColor Green
            if ($app.InstallLocation) {
                Write-Host "    Location: $($app.InstallLocation)" -ForegroundColor Gray
            }
        }
    }
}
