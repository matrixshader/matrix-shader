Write-Host "=== MATRIX SHADER TEST ===" -ForegroundColor Green
Write-Host ""

# Step 1: Install Node.js
Write-Host "Step 1: Installing Node.js..." -ForegroundColor Yellow
winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements

# Step 2: Refresh PATH
Write-Host ""
Write-Host "Step 2: Refreshing PATH..." -ForegroundColor Yellow
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')

# Step 3: Install matrix-shader
Write-Host ""
Write-Host "Step 3: Installing matrix-shader..." -ForegroundColor Yellow
npm install -g $HOME\Desktop\Matrix\matrix-shader-2.0.0.tgz

# Done
Write-Host ""
Write-Host "=== READY! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Now try:" -ForegroundColor Cyan
Write-Host "  wakeupneo" -ForegroundColor White
Write-Host ""
