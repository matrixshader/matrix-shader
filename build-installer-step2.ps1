# build-installer-step2.ps1 - Copy shaders and compile installer
$ErrorActionPreference = 'Stop'
Set-Location "C:\Users\ehome\documents\matrix"

$PublishDir = "installer\publish"
$OutputDir = "installer\output"
$ShadersSource = "MatrixShader\shaders"
$ShadersDest = Join-Path $PublishDir "shaders"

# Copy shaders from C# project to publish folder
Write-Host "Copying shaders..." -ForegroundColor Cyan
if (-not (Test-Path $ShadersSource)) {
    throw "Shaders not found at: $ShadersSource"
}
New-Item -ItemType Directory -Force -Path $ShadersDest | Out-Null
Copy-Item -Path "$ShadersSource\*.hlsl" -Destination $ShadersDest -Force
$shaderCount = (Get-ChildItem "$ShadersDest\*.hlsl").Count
Write-Host "  $shaderCount shaders copied" -ForegroundColor Gray

# Clean previous output
if (Test-Path $OutputDir) { Remove-Item -Recurse -Force $OutputDir }
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# Compile installer with Inno Setup
Write-Host "Compiling installer..." -ForegroundColor Cyan
$InnoSetupPath = "C:\Users\ehome\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $InnoSetupPath)) {
    throw "Inno Setup not found at: $InnoSetupPath"
}

& $InnoSetupPath "installer\MatrixShaderSetup.iss"
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compilation failed"
}

# Verify output
$installer = Get-ChildItem (Join-Path $OutputDir "*.exe") | Select-Object -First 1
if (-not $installer) {
    throw "No installer created in $OutputDir"
}
Write-Host "`nInstaller created: $($installer.FullName)" -ForegroundColor Green
Write-Host "Size: $([math]::Round($installer.Length / 1MB, 2)) MB" -ForegroundColor Gray
