$ErrorActionPreference = 'Stop'
$Root = Join-Path $PSScriptRoot "..\MatrixShader\src"
Set-Location $Root

$projects = @(
    'MatrixShader.Cli\WakeupNeo\MatrixShader.Cli.WakeupNeo.csproj',
    'MatrixShader.Cli\Bluepill\MatrixShader.Cli.Bluepill.csproj',
    'MatrixShader.Cli\Redpill\MatrixShader.Cli.Redpill.csproj',
    'MatrixShader.Cli\MatrixLite\MatrixShader.Cli.MatrixLite.csproj',
    'MatrixShader.Hotkeys\MatrixShader.Hotkeys.csproj',
    'MatrixShader.Monitor\MatrixShader.Monitor.csproj',
    'MatrixShader.Lite\MatrixShader.Lite.csproj'
)

foreach ($p in $projects) {
    Write-Host "=== Publishing $p ===" -ForegroundColor Cyan
    dotnet publish $p -c Release -r win-x64 --self-contained /p:PublishAot=false /p:PublishTrimmed=false
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $p" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "All projects published successfully!" -ForegroundColor Green
