@echo off
REM ============================================================
REM Matrix Shader Demo Orchestrator v2
REM ============================================================

echo.
echo   DEMO ORCHESTRATOR
echo   =================

REM 1. Kill any old ffmpeg
taskkill /F /IM ffmpeg.exe >nul 2>&1
timeout /t 2 /nobreak >nul

REM 2. Start ffmpeg recording FIRST
echo   [1] Starting recording...
start "" /MIN "%LOCALAPPDATA%\Microsoft\WinGet\Links\ffmpeg.exe" -y -f gdigrab -framerate 30 -video_size 1920x1080 -t 600 -i desktop -c:v libx264 -preset ultrafast -crf 23 -pix_fmt yuv420p "%USERPROFILE%\Videos\MatrixShader-Demo.mp4"
timeout /t 3 /nobreak >nul

REM 3. Uninstall Windows Terminal for real
echo   [2] Uninstalling Windows Terminal...
powershell.exe -NoProfile -Command "Get-AppxPackage Microsoft.WindowsTerminal | Remove-AppxPackage"
echo   [2] Waiting for WT to die...
timeout /t 8 /nobreak >nul

REM 4. Open plain PowerShell (conhost) with installer
echo   [3] Opening installer...
start "MatrixInstall" powershell.exe -NoProfile -NoExit -ExecutionPolicy Bypass -Command "Write-Host 'Installing Matrix Shader...' -ForegroundColor Green; irm https://matrixshader.com/install.ps1 | iex"

REM 5. Restart Claude Code after install has time to start
echo   [4] Restarting Claude Code in 15s...
timeout /t 15 /nobreak >nul
start "Claude" cmd.exe /k "cd /d C:\Users\ehome\Documents\MATRIX && claude --dangerously-skip-permissions --continue"

echo   Done. This window can be closed.
