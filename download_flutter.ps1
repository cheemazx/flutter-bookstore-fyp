$url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.41.6-stable.zip"
$file = "D:\fyp\flutter-bookstore-fyp\flutter.zip"
$maxRetries = 30
$retryCount = 0

Write-Host "Starting robust download of Flutter SDK..."

do {
    # Run curl to continue downloading if interrupted
    curl.exe -C - -o $file "$url"
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-Host "`nDownload completed successfully!"
        break
    }
    
    # HTTP error 416 sometimes means the file is already fully downloaded
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
    # Force removal of old extraction folder if it exists
    if (Test-Path "D:\fyp\flutter") {
        Remove-Item "D:\fyp\flutter" -Recurse -Force -ErrorAction Ignore
    }
    Expand-Archive -Path $file -DestinationPath "D:\fyp" -Force
    Write-Host "Extraction complete!"
    
    # The zip contains a 'flutter' folder inside, which creates D:\fyp\flutter
    # Let's clean up the zip
    Remove-Item $file -Force
} else {
    Write-Host "Failed to download the zip file."
    exit 1
}
