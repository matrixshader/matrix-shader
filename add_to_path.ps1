$matrixDir = "$env:USERPROFILE\Documents\Matrix"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*Documents\Matrix*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$matrixDir", "User")
    Write-Host "Added to PATH"
} else {
    Write-Host "Already in PATH"
}
