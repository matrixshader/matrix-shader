# Matrix Terminal Shader Installer
$u="https://raw.githubusercontent.com/matrixshader/wt/main"
$d="$env:USERPROFILE\Documents\Matrix";mkdir $d -Force >$null
iwr "$u/Matrix.hlsl" -Out "$d\Matrix.hlsl"
iwr "$u/matrix_tool.ps1" -Out "$d\matrix_tool.ps1"
$wt=ls "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal*\LocalState\settings.json" -ea 0|select -First 1
if($wt){$c=gc $wt -Raw;if($c-notmatch'pixelShaderPath'){cp $wt "$wt.bak";$c-replace'("defaults"\s*:\s*\{)',('$1`n      "experimental.pixelShaderPath": "'+($d-replace'\\','\\\\')+'\\\Matrix.hlsl",')|sc $wt -NoNewline}}
Write-Host "`n  MATRIX INSTALLED! Restart Terminal, run: ~\Documents\Matrix\matrix_tool.ps1`n" -ForegroundColor Green
