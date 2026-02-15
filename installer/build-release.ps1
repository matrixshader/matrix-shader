$ErrorActionPreference = 'Stop'
$Publish = Join-Path $PSScriptRoot "publish"
$Output = Join-Path $PSScriptRoot "output"

# Ensure output dir exists
if (-not (Test-Path $Output)) { New-Item -ItemType Directory -Path $Output -Force | Out-Null }

# 1. Create MatrixShader.zip from publish directory
$ZipPath = Join-Path $Output "MatrixShader.zip"
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }

Write-Host "Creating MatrixShader.zip..." -ForegroundColor Cyan
Compress-Archive -Path "$Publish\*" -DestinationPath $ZipPath -CompressionLevel Optimal
$zipInfo = Get-Item $ZipPath
Write-Host "  Created: $ZipPath ($([math]::Round($zipInfo.Length / 1MB, 1)) MB)" -ForegroundColor Green

Write-Host ""
Write-Host "Done! Zip ready." -ForegroundColor Green
