# launch-sandbox.ps1 - Generate and launch Windows Sandbox for E2E testing
# Works from any machine — resolves paths dynamically

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot
$InstallerDir = Split-Path -Parent $ScriptDir
$PublishDir = Join-Path $InstallerDir "publish"

if (-not (Test-Path $PublishDir)) {
    Write-Error "Publish directory not found: $PublishDir`nRun build-installer.ps1 first."
    exit 1
}

$wsb = @"
<Configuration>
  <VGpu>Enable</VGpu>
  <Networking>Enable</Networking>
  <MemoryInMB>4096</MemoryInMB>

  <MappedFolders>
    <MappedFolder>
      <HostFolder>$PublishDir</HostFolder>
      <SandboxFolder>C:\MatrixShader</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
    <MappedFolder>
      <HostFolder>$ScriptDir</HostFolder>
      <SandboxFolder>C:\Test</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
  </MappedFolders>

  <LogonCommand>
    <Command>powershell.exe -ExecutionPolicy Bypass -File C:\Test\validate.ps1</Command>
  </LogonCommand>
</Configuration>
"@

$TempWsb = Join-Path $env:TEMP "MatrixShaderTest.wsb"
$wsb | Out-File -FilePath $TempWsb -Encoding utf8

Write-Host "Launching Windows Sandbox..." -ForegroundColor Green
Write-Host "  Publish: $PublishDir" -ForegroundColor Cyan
Write-Host "  Test:    $ScriptDir" -ForegroundColor Cyan

Start-Process $TempWsb
