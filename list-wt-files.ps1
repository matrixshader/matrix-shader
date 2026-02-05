$dir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
Get-ChildItem $dir | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
