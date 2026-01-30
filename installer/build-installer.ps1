# build-installer.ps1 - Build Matrix Shader installer
# Requires: Inno Setup 6.x installed and in PATH (or specify path)

param(
    [string]$InnoSetupPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
)

$ErrorActionPreference = "Stop"

Write-Host "Building Matrix Shader installer..." -ForegroundColor Green

# Paths
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$SrcRoot = Join-Path $ProjectRoot "MatrixShader\src"
$InstallerDir = $PSScriptRoot
$PublishDir = Join-Path $InstallerDir "publish"
$OutputDir = Join-Path $InstallerDir "output"

# Clean previous builds
if (Test-Path $PublishDir) { Remove-Item -Recurse -Force $PublishDir }
if (Test-Path $OutputDir) { Remove-Item -Recurse -Force $OutputDir }
New-Item -ItemType Directory -Force -Path $PublishDir | Out-Null
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# Publish CLIs and Monitor
$projects = @(
    "MatrixShader.Cli\Bluepill",
    "MatrixShader.Cli\Redpill",
    "MatrixShader.Cli\WakeupNeo",
    "MatrixShader.Monitor"
)

foreach ($project in $projects) {
    Write-Host "  Publishing $project..." -ForegroundColor Cyan
    $csproj = Join-Path $SrcRoot "$project\*.csproj"
    dotnet publish $csproj -c Release -o $PublishDir --no-self-contained:false
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to publish $project"
    }
}

# Verify executables
@("bluepill.exe", "redpill.exe", "wakeupneo.exe", "matrix-monitor.exe") | ForEach-Object {
    $exe = Join-Path $PublishDir $_
    if (!(Test-Path $exe)) {
        throw "Missing executable: $_"
    }
    Write-Host "    $_" -ForegroundColor Gray
}

# Build installer
Write-Host "  Building installer..." -ForegroundColor Cyan
if (!(Test-Path $InnoSetupPath)) {
    Write-Warning "Inno Setup not found at: $InnoSetupPath"
    Write-Warning "Install Inno Setup or specify path with -InnoSetupPath"
    exit 1
}

$issPath = Join-Path $InstallerDir "MatrixShaderSetup.iss"
& $InnoSetupPath $issPath
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compilation failed"
}

# Done
$installer = Get-ChildItem (Join-Path $OutputDir "*.exe") | Select-Object -First 1
Write-Host "`nInstaller created: $($installer.FullName)" -ForegroundColor Green
Write-Host "Size: $([math]::Round($installer.Length / 1MB, 2)) MB" -ForegroundColor Gray
