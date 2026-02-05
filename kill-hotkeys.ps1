# Kill all hotkey processes
Write-Host "Killing all hotkey processes..." -ForegroundColor Cyan

$killed = 0
Get-Process powershell -ErrorAction SilentlyContinue | ForEach-Object {
    $procId = $_.Id
    try {
        $cmd = (Get-WmiObject Win32_Process -Filter "ProcessId=$procId").CommandLine
        if ($cmd -like "*hotkey*") {
            Write-Host "  Killing PID $procId" -ForegroundColor Yellow
            Stop-Process -Id $procId -Force
            $killed++
        }
    } catch {}
}

Write-Host "Killed $killed hotkey process(es)" -ForegroundColor Green
