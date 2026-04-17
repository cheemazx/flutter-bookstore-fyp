$ErrorActionPreference = "Stop"

$url = "https://dl.google.com/android/repository/commandlinetools-win-14742923_latest.zip"
$androidSdkDir = "$env:LOCALAPPDATA\Android\Sdk"
$cmdlineToolsDir = "$androidSdkDir\cmdline-tools"
$latestDir = "$cmdlineToolsDir\latest"
$zipFile = "$env:TEMP\cmdline-tools.zip"
$tempExtractDir = "$env:TEMP\cmdline-tools-extract"

if (-not (Test-Path $androidSdkDir)) {
    Write-Host "Creating Android SDK directory at $androidSdkDir..."
    New-Item -ItemType Directory -Force -Path $androidSdkDir | Out-Null
}

if (Test-Path $latestDir) {
    Write-Host "Command-line tools 'latest' directory already exists. Removing old version..."
    Remove-Item -Path $latestDir -Recurse -Force
}

Write-Host "Downloading Android SDK Command-line Tools..."
Invoke-WebRequest -Uri $url -OutFile $zipFile

Write-Host "Extracting..."
if (Test-Path $tempExtractDir) { Remove-Item $tempExtractDir -Recurse -Force }
Expand-Archive -Path $zipFile -DestinationPath $tempExtractDir -Force

# The zip contains a folder called 'cmdline-tools'. 
# Inside that is 'bin', 'lib', 'source.properties', and 'NOTICE.txt'.
# We need to move those inside $cmdlineToolsDir\latest
if (-not (Test-Path $cmdlineToolsDir)) {
    New-Item -ItemType Directory -Force -Path $cmdlineToolsDir | Out-Null
}
New-Item -ItemType Directory -Force -Path $latestDir | Out-Null

Write-Host "Moving files to $latestDir..."
Move-Item -Path "$tempExtractDir\cmdline-tools\*" -Destination $latestDir -Force

Write-Host "Setting ANDROID_HOME environment variable..."
[System.Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidSdkDir, "User")
$env:ANDROID_HOME = $androidSdkDir

Write-Host "Adding tools to User PATH..."
$userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
$toolsPaths = @(
    "$latestDir\bin",
    "$androidSdkDir\platform-tools"
)

foreach ($path in $toolsPaths) {
    if ($userPath -notmatch [regex]::Escape($path)) {
        $userPath = "$userPath;$path"
        Write-Host "Added $path to PATH."
    }
}
[Environment]::SetEnvironmentVariable("PATH", $userPath, [EnvironmentVariableTarget]::User)

Write-Host "Cleaning up..."
Remove-Item -Path $zipFile -Force
Remove-Item -Path $tempExtractDir -Recurse -Force

Write-Host "`nDone! Command-line tools have been installed."
Write-Host "IMPORTANT: You MUST close and reopen your terminal for the environment variables to take effect."
Write-Host "Then, run: flutter doctor --android-licenses"
