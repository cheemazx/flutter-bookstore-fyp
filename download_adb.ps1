$ErrorActionPreference = "Stop"

$androidSdkDir = "$env:LOCALAPPDATA\Android\Sdk"
$platformToolsDir = "$androidSdkDir\platform-tools"
$zipFile = "$env:TEMP\platform-tools.zip"

if (-not (Test-Path $androidSdkDir)) {
    Write-Host "Creating Android SDK directory at $androidSdkDir..."
    New-Item -ItemType Directory -Force -Path $androidSdkDir | Out-Null
}

Write-Host "Downloading Android SDK Platform-Tools..."
Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $zipFile

Write-Host "Extracting..."
Expand-Archive -Path $zipFile -DestinationPath $androidSdkDir -Force

Write-Host "Adding to User PATH..."
$userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
if ($userPath -notmatch [regex]::Escape($platformToolsDir)) {
    $newPath = "$userPath;$platformToolsDir"
    [Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::User)
    Write-Host "Added $platformToolsDir to PATH."
} else {
    Write-Host "$platformToolsDir is already in PATH."
}

Write-Host "Cleaning up..."
Remove-Item -Path $zipFile -Force

Write-Host "Done! ADB has been installed."
Write-Host "IMPORTANT: You must CLOSE AND REOPEN your terminal for the PATH changes to take effect."
