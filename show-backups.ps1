$dir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
Get-ChildItem $dir -Filter "*.bak*" | ForEach-Object {
    Write-Host "$($_.Name) - $($_.LastWriteTime)"
}
