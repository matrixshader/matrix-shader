# Update-ShaderPaths.ps1
# Updates Windows Terminal settings.json so each Matrix-N profile points to its own shader file

param(
    [switch]$WhatIf  # Preview changes without applying
)

$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$shaderDir = "$env:USERPROFILE\Documents\Matrix\shaders"

if (-not (Test-Path $wtSettingsPath)) {
    Write-Host "ERROR: Windows Terminal settings.json not found at: $wtSettingsPath" -ForegroundColor Red
    exit 1
}

# Read the settings file
$content = Get-Content $wtSettingsPath -Raw -Encoding UTF8
$settings = $content | ConvertFrom-Json

$updated = 0

# Update each Matrix-N profile
for ($i = 0; $i -lt $settings.profiles.list.Count; $i++) {
    $profile = $settings.profiles.list[$i]

    # Check if this is a Matrix profile (Matrix-1 through Matrix-8)
    if ($profile.name -match '^Matrix-(\d+)$') {
        $slotNum = $matches[1]
        $newShaderPath = "$shaderDir\Matrix-$slotNum.hlsl"
        $oldPath = $profile.'experimental.pixelShaderPath'

        if ($oldPath -ne $newShaderPath) {
            if ($WhatIf) {
                Write-Host "[WhatIf] Would update $($profile.name): $oldPath -> $newShaderPath" -ForegroundColor Yellow
            } else {
                # Update the shader path
                $settings.profiles.list[$i].'experimental.pixelShaderPath' = $newShaderPath
                Write-Host "Updated $($profile.name): $newShaderPath" -ForegroundColor Green
            }
            $updated++
        } else {
            Write-Host "$($profile.name) already correct: $newShaderPath" -ForegroundColor Cyan
        }
    }
}

if (-not $WhatIf -and $updated -gt 0) {
    # Write back to settings.json
    $settings | ConvertTo-Json -Depth 10 | Set-Content $wtSettingsPath -Encoding UTF8
    Write-Host "`nUpdated $updated profile(s) in settings.json" -ForegroundColor Green
} elseif ($updated -eq 0) {
    Write-Host "`nAll profiles already have correct shader paths" -ForegroundColor Cyan
} else {
    Write-Host "`n[WhatIf] Would update $updated profile(s)" -ForegroundColor Yellow
}
