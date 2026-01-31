# build-publish.ps1 - Build all 6 executables
$ErrorActionPreference = 'Stop'
Set-Location "C:\Users\ehome\documents\matrix"

$PublishDir = 'installer\publish'
$SrcRoot = 'MatrixShader\src'

# Clean previous stale builds
if (Test-Path $PublishDir) { Remove-Item -Recurse -Force $PublishDir }
New-Item -ItemType Directory -Force -Path $PublishDir | Out-Null

# Publish all 6 projects - use explicit csproj paths
$projects = @(
    @{ Path = 'MatrixShader.Cli\Bluepill\MatrixShader.Cli.Bluepill.csproj'; Name = 'Bluepill' },
    @{ Path = 'MatrixShader.Cli\Redpill\MatrixShader.Cli.Redpill.csproj'; Name = 'Redpill' },
    @{ Path = 'MatrixShader.Cli\WakeupNeo\MatrixShader.Cli.WakeupNeo.csproj'; Name = 'WakeupNeo' },
    @{ Path = 'MatrixShader.Cli\MatrixLite\MatrixShader.Cli.MatrixLite.csproj'; Name = 'MatrixLite' },
    @{ Path = 'MatrixShader.Hotkeys\MatrixShader.Hotkeys.csproj'; Name = 'Hotkeys' },
    @{ Path = 'MatrixShader.Monitor\MatrixShader.Monitor.csproj'; Name = 'Monitor' }
)

foreach ($project in $projects) {
    Write-Host "Publishing $($project.Name)..." -ForegroundColor Cyan
    $csproj = Join-Path $SrcRoot $project.Path
    if (-not (Test-Path $csproj)) { throw "Project not found: $csproj" }
    # Disable AOT compilation and trimming (requires VS native linker) - use standard self-contained build
    dotnet publish $csproj -c Release -o $PublishDir --self-contained true -r win-x64 -p:PublishAot=false -p:PublishTrimmed=false
    if ($LASTEXITCODE -ne 0) { throw "Failed to publish $($project.Name)" }
}

Write-Host "All projects published successfully!" -ForegroundColor Green
