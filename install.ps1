# Matrix Terminal Shader - One-Line Installer
$base = "https://raw.githubusercontent.com/Ehomey/matrix-terminal-shader/master"
$docs = "$env:USERPROFILE\Documents"
iwr "$base/Matrix.hlsl" -OutFile "$docs\Matrix.hlsl"
iwr "$base/matrix_tool.ps1" -OutFile "$docs\matrix_tool.ps1"
$wt = ls "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal*\LocalState\settings.json" -ea 0 | select -First 1
if ($wt) {
    $c = gc $wt -Raw
    if ($c -notmatch 'pixelShaderPath') {
        cp $wt "$wt.bak"
        $c -replace '("defaults"\s*:\s*\{)', ('$1`n      "experimental.pixelShaderPath": "' + ($docs -replace '\\','\\\\') + '\\\\Matrix.hlsl",') | sc $wt -NoNewline
    }
}
Write-Host "`n  MATRIX INSTALLED! Restart Windows Terminal, then run:`n  ~\Documents\matrix_tool.ps1`n" -ForegroundColor Green
