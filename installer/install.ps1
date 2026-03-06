# Matrix Shader One-Liner Install Script
# Usage: irm https://matrixshader.com/install.ps1 | iex
#
# Works with PowerShell 5.1 and 7+
# Installs to Program Files (admin) or LocalAppData (non-admin)

$ErrorActionPreference = 'Stop'

# Configuration
$RepoOwner = 'matrixshader'
$RepoName = 'matrix-shader'
$AppName = 'MatrixShader'
$Version = 'latest'

# Detect admin privileges
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Set install paths
if ($IsAdmin) {
    $InstallDir = "$env:ProgramFiles\$AppName"
    $PathScope = 'Machine'
} else {
    $InstallDir = "$env:LOCALAPPDATA\Programs\$AppName"
    $PathScope = 'User'
}
$DataDir = "$env:LOCALAPPDATA\$AppName"
$ShadersDir = "$DataDir\shaders"

Write-Host ""
Write-Host "  Matrix Shader Installer" -ForegroundColor Green
Write-Host "  =======================" -ForegroundColor Green
Write-Host ""

# Check for existing GUI (Inno Setup) installation
$GuiInstallDir = "$env:ProgramFiles\$AppName"
$InnoUninstallExe = "$GuiInstallDir\unins000.exe"
if (Test-Path $InnoUninstallExe) {
    Write-Host "  WARNING: GUI installer version detected at:" -ForegroundColor Yellow
    Write-Host "    $GuiInstallDir" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  The GUI version will be removed first." -ForegroundColor Yellow
    Write-Host ""
    try {
        # Run Inno Setup uninstaller silently
        Start-Process -FilePath $InnoUninstallExe -ArgumentList '/SILENT' -Wait -ErrorAction Stop
        Write-Host "  GUI version removed." -ForegroundColor Green
        Write-Host ""
    } catch {
        Write-Host "  Could not auto-remove GUI version: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Please uninstall via Add/Remove Programs first, then re-run this script." -ForegroundColor Red
        exit 1
    }
}

# Check for existing CLI install in the OTHER location
if ($IsAdmin) {
    $OtherDir = "$env:LOCALAPPDATA\Programs\$AppName"
} else {
    $OtherDir = "$env:ProgramFiles\$AppName"
}
if (Test-Path "$OtherDir\wakeupneo.exe") {
    Write-Host "  Removing previous install at: $OtherDir" -ForegroundColor Yellow
    try {
        # Remove from PATH
        $OtherScope = if ($IsAdmin) { 'User' } else { 'Machine' }
        $OtherPath = [Environment]::GetEnvironmentVariable('Path', $OtherScope)
        if ($OtherPath) {
            $CleanEntries = ($OtherPath -split ';') | Where-Object { $_.Trim().ToLower() -ne $OtherDir.ToLower() -and $_.Trim() -ne '' }
            [Environment]::SetEnvironmentVariable('Path', ($CleanEntries -join ';'), $OtherScope)
        }
        Remove-Item $OtherDir -Recurse -Force
        # Remove old registry entry from other scope
        $OtherRegKey = if ($IsAdmin) { 'HKCU' } else { 'HKLM' }
        $OtherUninstallKey = "${OtherRegKey}:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$AppName"
        if (Test-Path $OtherUninstallKey) {
            Remove-Item $OtherUninstallKey -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Host "  Previous install removed." -ForegroundColor Green
    } catch {
        Write-Host "  WARNING: Could not remove $OtherDir" -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host "  Install location: $InstallDir"
Write-Host "  Data location:    $DataDir"
Write-Host "  Admin mode:       $IsAdmin"
Write-Host ""

# Kill running Matrix processes before install (DLLs are locked while running)
$MatrixProcesses = @('matrix-hotkeys', 'matrix-monitor', 'redpill', 'bluepill', 'wakeupneo', 'matrixlite', 'construct')
$Killed = @()
foreach ($proc in $MatrixProcesses) {
    $running = Get-Process -Name $proc -ErrorAction SilentlyContinue
    if ($running) {
        $running | Stop-Process -Force -ErrorAction SilentlyContinue
        $Killed += $proc
    }
}
if ($Killed.Count -gt 0) {
    Write-Host "  Stopped running processes: $($Killed -join ', ')" -ForegroundColor Yellow
    Start-Sleep -Seconds 1  # Brief pause for file handles to release
}

# Create directories
Write-Host "[1/6] Creating directories..." -ForegroundColor Cyan
if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null }
if (-not (Test-Path $ShadersDir)) { New-Item -ItemType Directory -Path $ShadersDir -Force | Out-Null }

# Get latest release URL from GitHub API
Write-Host "[2/6] Finding latest release..." -ForegroundColor Cyan
try {
    # Find latest Windows release (skip linux-tagged releases)
    $ApiUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/releases"
    $Headers = @{ 'User-Agent' = 'MatrixShader-Installer' }

    # Use different methods for PS 5.1 vs 7+
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $AllReleases = Invoke-RestMethod -Uri $ApiUrl -Headers $Headers

    # Find first release that has a .zip asset (skip linux-only releases)
    $Release = $null
    $ZipAsset = $null
    foreach ($r in $AllReleases) {
        $ZipAsset = $r.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
        if ($ZipAsset) { $Release = $r; break }
    }
    if (-not $ZipAsset) {
        throw "No zip file found in latest release"
    }
    $DownloadUrl = $ZipAsset.browser_download_url
    $ZipName = $ZipAsset.name
    $TagName = $Release.tag_name
    Write-Host "  Found version: $TagName" -ForegroundColor Gray
}
catch {
    Write-Host "  GitHub API error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  Falling back to direct download URL..." -ForegroundColor Yellow
    # Fallback URL for when API is unavailable
    $DownloadUrl = "https://github.com/$RepoOwner/$RepoName/releases/latest/download/MatrixShader.zip"
    $ZipName = "MatrixShader.zip"
    $TagName = "latest"
}

# Download release zip
Write-Host "[3/6] Downloading $ZipName..." -ForegroundColor Cyan
$TempDir = [System.IO.Path]::GetTempPath()
$ZipPath = Join-Path $TempDir $ZipName

try {
    # Progress indicator for download
    $ProgressPreference = 'Continue'

    if ($PSVersionTable.PSVersion.Major -ge 6) {
        # PowerShell 7+ - better progress
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing
    } else {
        # PowerShell 5.1
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($DownloadUrl, $ZipPath)
    }
    Write-Host "  Downloaded to: $ZipPath" -ForegroundColor Gray
}
catch {
    Write-Host "ERROR: Failed to download release" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual install: https://github.com/$RepoOwner/$RepoName/releases" -ForegroundColor Yellow
    exit 1
}

# Extract to install directory
Write-Host "[4/6] Extracting files..." -ForegroundColor Cyan
try {
    $ExtractPath = Join-Path $TempDir "MatrixShader_extract"
    if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force }

    # Extract zip
    if ($PSVersionTable.PSVersion.Major -ge 5) {
        Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force
    } else {
        # Fallback for older PowerShell
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $ExtractPath)
    }

    # Find the root of extracted content (may have nested folder)
    $ExtractedContent = Get-ChildItem $ExtractPath
    if ($ExtractedContent.Count -eq 1 -and $ExtractedContent[0].PSIsContainer) {
        $SourceDir = $ExtractedContent[0].FullName
    } else {
        $SourceDir = $ExtractPath
    }

    # Copy executables and DLLs to install directory
    Write-Host "  Copying executables to $InstallDir..." -ForegroundColor Gray
    $ExeFiles = @('wakeupneo.exe', 'bluepill.exe', 'redpill.exe', 'construct.exe', 'matrixlite.exe', 'matrix-hotkeys.exe', 'matrix-monitor.exe')

    # Copy all files (runtime, DLLs, etc.)
    Get-ChildItem -Path $SourceDir -Recurse | ForEach-Object {
        $RelativePath = $_.FullName.Substring($SourceDir.Length + 1)
        $DestPath = Join-Path $InstallDir $RelativePath

        # Path traversal protection - ensure destination stays within install directory
        $NormalizedDest = [System.IO.Path]::GetFullPath($DestPath)
        if (-not $NormalizedDest.StartsWith($InstallDir)) {
            Write-Host "  Skipping suspicious path: $RelativePath" -ForegroundColor Yellow
            return  # continue in ForEach-Object
        }

        if ($_.PSIsContainer) {
            # Skip shaders directory - handled separately
            if ($RelativePath -notlike 'shaders*') {
                if (-not (Test-Path $DestPath)) { New-Item -ItemType Directory -Path $DestPath -Force | Out-Null }
            }
        } else {
            # Copy file (skip shaders for now)
            if ($RelativePath -notlike 'shaders\*') {
                $ParentDir = Split-Path $DestPath -Parent
                if (-not (Test-Path $ParentDir)) { New-Item -ItemType Directory -Path $ParentDir -Force | Out-Null }
                Copy-Item $_.FullName $DestPath -Force
            }
        }
    }

    # Copy shaders to LocalAppData
    $SourceShaders = Join-Path $SourceDir "shaders"
    if (Test-Path $SourceShaders) {
        Write-Host "  Copying shaders to $ShadersDir..." -ForegroundColor Gray
        Get-ChildItem -Path $SourceShaders -Filter "*.hlsl" | ForEach-Object {
            Copy-Item $_.FullName (Join-Path $ShadersDir $_.Name) -Force
        }
    }

    # Verify key executables
    $MissingExe = $ExeFiles | Where-Object { -not (Test-Path (Join-Path $InstallDir $_)) }
    if ($MissingExe) {
        Write-Host "WARNING: Some executables not found: $($MissingExe -join ', ')" -ForegroundColor Yellow
    }

    # Clean up temp files
    Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Host "ERROR: Failed to extract files" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Add to PATH
Write-Host "[5/6] Updating PATH..." -ForegroundColor Cyan
try {
    if ($PathScope -eq 'Machine') {
        $CurrentPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    } else {
        $CurrentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    }

    # Check if already in PATH (case-insensitive)
    $PathEntries = $CurrentPath -split ';' | ForEach-Object { $_.Trim().ToLower() }
    if ($PathEntries -notcontains $InstallDir.ToLower()) {
        $NewPath = $CurrentPath.TrimEnd(';') + ";$InstallDir"
        [Environment]::SetEnvironmentVariable('Path', $NewPath, $PathScope)
        Write-Host "  Added to $PathScope PATH" -ForegroundColor Gray

        # Update current session
        $env:Path = $env:Path + ";$InstallDir"
    } else {
        Write-Host "  Already in PATH" -ForegroundColor Gray
    }
}
catch {
    Write-Host "WARNING: Could not update PATH automatically" -ForegroundColor Yellow
    Write-Host "  Add this directory manually: $InstallDir" -ForegroundColor Yellow
}

# Register in Add/Remove Programs
Write-Host "[6/6] Registering in Add/Remove Programs..." -ForegroundColor Cyan
try {
    if ($IsAdmin) {
        $UninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$AppName"
    } else {
        $UninstallKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$AppName"
    }

    # Create the uninstall registry entry
    if (-not (Test-Path $UninstallKey)) {
        New-Item -Path $UninstallKey -Force | Out-Null
    }

    # Calculate installed size in KB
    $InstalledSizeKB = [math]::Round((Get-ChildItem $InstallDir -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1024)

    # Uninstall command runs the uninstall script non-interactively
    $UninstallCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"irm https://matrixshader.com/uninstall.ps1 | iex`""

    Set-ItemProperty -Path $UninstallKey -Name 'DisplayName' -Value 'Matrix Terminal Shader'
    Set-ItemProperty -Path $UninstallKey -Name 'DisplayVersion' -Value ($TagName -replace '^v', '')
    Set-ItemProperty -Path $UninstallKey -Name 'Publisher' -Value 'MatrixShader'
    Set-ItemProperty -Path $UninstallKey -Name 'InstallLocation' -Value $InstallDir
    Set-ItemProperty -Path $UninstallKey -Name 'UninstallString' -Value $UninstallCmd
    Set-ItemProperty -Path $UninstallKey -Name 'DisplayIcon' -Value "$InstallDir\wakeupneo.exe"
    Set-ItemProperty -Path $UninstallKey -Name 'EstimatedSize' -Value $InstalledSizeKB -Type DWord
    Set-ItemProperty -Path $UninstallKey -Name 'NoModify' -Value 1 -Type DWord
    Set-ItemProperty -Path $UninstallKey -Name 'NoRepair' -Value 1 -Type DWord
    Set-ItemProperty -Path $UninstallKey -Name 'URLInfoAbout' -Value 'https://matrixshader.com'
    Set-ItemProperty -Path $UninstallKey -Name 'URLUpdateInfo' -Value 'https://github.com/matrixshader/matrix-shader/releases'

    Write-Host "  Registered in Add/Remove Programs" -ForegroundColor Gray
}
catch {
    Write-Host "  WARNING: Could not register in Add/Remove Programs" -ForegroundColor Yellow
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  To uninstall manually: irm https://matrixshader.com/uninstall.ps1 | iex" -ForegroundColor Yellow
}

# Success!
Write-Host ""
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  IMPORTANT: Open a NEW terminal window for commands to work." -ForegroundColor Yellow
Write-Host ""
Write-Host "  COMMANDS" -ForegroundColor Cyan
Write-Host "    wakeupneo  - Start here"
Write-Host "    construct  - Launch individual Matrix terminal (--help for colors)"
Write-Host "    bluepill   - Quickly relaunch last saved settings"
Write-Host "    redpill    - Full control panel (fine tuning)"
Write-Host "    matrixlite - Visual effect only"
Write-Host ""

Write-Host "  Enjoying Matrix Shader? Buy me a coffee:" -ForegroundColor DarkGray
Write-Host "  https://buymeacoffee.com/IKnowKungFu" -ForegroundColor Yellow
Write-Host ""

# Auto-launch wakeupneo in a new terminal window
$WakeupNeo = Join-Path $InstallDir "wakeupneo.exe"
if (Test-Path $WakeupNeo) {
    Write-Host "  Launching wakeupneo..." -ForegroundColor Green
    Start-Process $WakeupNeo
}
