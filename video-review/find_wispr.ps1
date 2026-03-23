$processes = Get-Process
foreach ($p in $processes) {
    if ($p.ProcessName -match 'wispr|flow') {
        Write-Host ("Name: " + $p.ProcessName + " | Path: " + $p.Path)
    }
}

# Search common install locations
$paths = @(
    "$env:LOCALAPPDATA",
    "$env:APPDATA",
    "$env:LOCALAPPDATA\Programs",
    "C:\Program Files",
    "C:\Program Files (x86)"
)
foreach ($base in $paths) {
    $found = Get-ChildItem $base -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'wispr|flow' }
    foreach ($f in $found) {
        Write-Host ("Found dir: " + $f.FullName)
    }
}
