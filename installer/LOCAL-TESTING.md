# Local Testing Setup for CLI One-Liner Install

**IMPORTANT: This file documents how local E2E testing works. DO NOT LOSE THIS.**

## What Gets Served

The HTTP server serves from `installer/output/` which must contain:

1. **install-local-test.ps1** - Copy of `installer/install.ps1` with ONE change:
   - Replace GitHub API/URL section with:
   ```powershell
   # LOCAL TEST: Direct download from local HTTP server
   Write-Host "[2/5] Using local test server..." -ForegroundColor Cyan
   $BaseUrl = "http://172.19.208.1:9090"
   $DownloadUrl = "$BaseUrl/MatrixShader.zip"
   $ZipName = "MatrixShader.zip"
   Write-Host "  Server: $BaseUrl" -ForegroundColor Gray
   ```

2. **MatrixShader.zip** - Created from `installer/publish/` which MUST contain:
   - All 6 EXEs: wakeupneo.exe, bluepill.exe, redpill.exe, matrixlite.exe, matrix-hotkeys.exe, matrix-monitor.exe
   - All DLLs (CRITICAL - AOT builds need these):
     - vcruntime140_cor3.dll
     - D3DCompiler_47_cor3.dll
     - PresentationNative_cor3.dll
     - wpfgfx_cor3.dll
     - PenImc_cor3.dll
   - shaders/ folder with all .hlsl files

## How to Build installer/publish/

The DLLs come from the actual dotnet publish output, NOT from build-installer.ps1 (which disables AOT).

```powershell
# Copy DLLs from any AOT-published project (they're the same for all)
cp MatrixShader/src/MatrixShader.Cli/WakeupNeo/bin/Release/net8.0-windows/win-x64/publish/*.dll installer/publish/
```

## How to Create the ZIP

```powershell
cd installer
Compress-Archive -Path 'publish\*' -DestinationPath 'output\MatrixShader.zip' -Force
```

## How to Run the Test

1. Start HTTP server from installer/output:
   ```powershell
   cd installer/output
   python -m http.server 9090
   ```

2. Launch sandbox:
   ```powershell
   Start-Process MatrixShaderTest.wsb
   ```

3. Sandbox auto-runs: `irm http://172.19.208.1:9090/install-local-test.ps1 | iex`

## The Flow

1. Sandbox downloads install-local-test.ps1 from local server
2. Script downloads MatrixShader.zip from local server
3. Script extracts ZIP to Program Files
4. Script copies shaders to LocalAppData
5. Script adds to PATH
6. Script runs wakeupneo

## Common Errors

- **vcruntime140_cor3.dll not found**: DLLs missing from ZIP. Copy them from actual publish folder.
- **ZIP not found**: MatrixShader.zip doesn't exist in installer/output/
- **Server not running**: Start python HTTP server on port 9090

---
*Last updated: 2026-02-03*
