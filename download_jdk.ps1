$url = "https://download.java.net/java/GA/jdk21.0.2/f2283984656d49d69e91c558476027ac/13/GPL/openjdk-21.0.2_windows-x64_bin.zip"
$file = "D:\fyp\flutter-bookstore-fyp\jdk.zip"
$maxRetries = 30
$retryCount = 0

Write-Host "Starting robust download of JDK..."

do {
    curl.exe -L -C - -o $file "$url"
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-Host "`nDownload completed successfully!"
        break
    }
    
    if ($exitCode -eq 33 -or $exitCode -eq 18 -or $exitCode -eq 56 -or $exitCode -eq 92) {
       $retryCount++
       Write-Host "`nDownload interrupted with connection reset. Retrying ($retryCount/$maxRetries) in 3 seconds..."
       Start-Sleep -Seconds 3
    } else {
       $retryCount++
       Write-Host "`nDownload failed with exit code $exitCode. Retrying ($retryCount/$maxRetries)..."
       Start-Sleep -Seconds 3
    }
} while ($retryCount -lt $maxRetries)

if ($exitCode -eq 0 -or (Test-Path $file)) {
    Write-Host "Extracting the zip file. This might take a minute..."
    if (Test-Path "D:\fyp\jdk") {
        Remove-Item "D:\fyp\jdk" -Recurse -Force -ErrorAction Ignore
    }
    Expand-Archive -Path $file -DestinationPath "D:\fyp\jdk" -Force
    Write-Host "Extraction complete!"
    
    Remove-Item $file -Force
    
    # Set the JAVA_HOME for the user permanently
    $javaPath = "D:\fyp\jdk\jdk-21.0.2"
    Write-Host "Setting JAVA_HOME to $javaPath..."
    [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaPath, "User")
    
    $oldPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if ($oldPath -notmatch "jdk-21.0.2\\bin") {
        $newPath = "$oldPath;$javaPath\bin"
        [System.Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Host "Added Java to Path."
    }
    Write-Host "Done! Please restart your terminal so the new PATH and JAVA_HOME take effect."
} else {
    Write-Host "Failed to download the zip file."
    exit 1
}
