# build-installer.ps1 - Build Matrix Shader installer
# Requires: Inno Setup 6.x installed and in PATH (or specify path)

param(
    [string]$InnoSetupPath
)

# Auto-detect Inno Setup if not specified
if (-not $InnoSetupPath) {
    $candidates = @(
        (Get-Command "ISCC.exe" -ErrorAction SilentlyContinue)?.Source,
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe",
        "C:\ProgramData\chocolatey\bin\ISCC.exe"
    ) | Where-Object { $_ -and (Test-Path $_) }
    $InnoSetupPath = $candidates | Select-Object -First 1
    if (-not $InnoSetupPath) {
        Write-Error "Inno Setup not found. Install it or pass -InnoSetupPath"
        exit 1
    }
}

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

# Publish CLIs, Lite, Hotkeys, and Monitor
# Using explicit csproj paths (wildcards don't work reliably on Windows)
$projects = @(
    @{ Name = "Bluepill"; Path = "MatrixShader.Cli\Bluepill\MatrixShader.Cli.Bluepill.csproj" },
    @{ Name = "Redpill"; Path = "MatrixShader.Cli\Redpill\MatrixShader.Cli.Redpill.csproj" },
    @{ Name = "WakeupNeo"; Path = "MatrixShader.Cli\WakeupNeo\MatrixShader.Cli.WakeupNeo.csproj" },
    @{ Name = "MatrixLite"; Path = "MatrixShader.Cli\MatrixLite\MatrixShader.Cli.MatrixLite.csproj" },
    @{ Name = "Hotkeys"; Path = "MatrixShader.Hotkeys\MatrixShader.Hotkeys.csproj" },
    @{ Name = "Monitor"; Path = "MatrixShader.Monitor\MatrixShader.Monitor.csproj" }
)

foreach ($project in $projects) {
    Write-Host "  Publishing $($project.Name)..." -ForegroundColor Cyan
    $csproj = Join-Path $SrcRoot $project.Path
    # Self-contained: includes .NET runtime for widest compatibility
    # Users don't need to install .NET separately
    # Note: /p:PublishAot=false disables Native AOT (requires Visual Studio C++ tools)
    #       /p:PublishTrimmed=false disables trimming (avoids IL2104 warnings-as-errors)
    #       This uses standard self-contained publish instead
    dotnet publish $csproj -c Release -o $PublishDir --self-contained true -r win-x64 /p:PublishAot=false /p:PublishTrimmed=false
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to publish $($project.Name)"
    }
}

# Verify executables
@("bluepill.exe", "redpill.exe", "wakeupneo.exe", "matrixlite.exe", "matrix-hotkeys.exe", "matrix-monitor.exe") | ForEach-Object {
    $exe = Join-Path $PublishDir $_
    if (!(Test-Path $exe)) {
        throw "Missing executable: $_"
    }
    Write-Host "    $_" -ForegroundColor Gray
}

# Copy shaders from C# project (NOT PowerShell root)
Write-Host "  Copying shaders..." -ForegroundColor Cyan
$ShadersSource = Join-Path $ProjectRoot "MatrixShader\shaders"
$ShadersDest = Join-Path $PublishDir "shaders"
if (!(Test-Path $ShadersSource)) {
    throw "Shaders not found at: $ShadersSource"
}
New-Item -ItemType Directory -Force -Path $ShadersDest | Out-Null
Copy-Item -Path "$ShadersSource\*.hlsl" -Destination $ShadersDest -Force
$shaderCount = (Get-ChildItem "$ShadersDest\*.hlsl").Count
Write-Host "    $shaderCount shaders copied" -ForegroundColor Gray

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
