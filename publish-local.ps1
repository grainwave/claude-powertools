# ============================================
# Publish Claude Power Tools Locally
# ============================================
# Copies the scripts folder to c:\tools\scripts

$SourcePath = Join-Path $PSScriptRoot "scripts"
$DestinationPath = "c:\tools\scripts"

Write-Host "Publishing Claude Power Tools..." -ForegroundColor Cyan
Write-Host "Source: $SourcePath" -ForegroundColor Gray
Write-Host "Destination: $DestinationPath" -ForegroundColor Gray
Write-Host ""

# Create destination directory if it doesn't exist
if (-not (Test-Path $DestinationPath)) {
    Write-Host "Creating destination directory..." -ForegroundColor Yellow
    try {
        New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
        Write-Host "Destination directory created." -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Failed to create destination directory: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Copy scripts folder contents to destination
try {
    Write-Host "Copying files..." -ForegroundColor Yellow
    Copy-Item -Path "$SourcePath\*" -Destination $DestinationPath -Recurse -Force
    Write-Host "Files copied successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Claude Power Tools published to: $DestinationPath" -ForegroundColor Green
    Write-Host "You can now run: cpt.ps1" -ForegroundColor Cyan
}
catch {
    Write-Host "ERROR: Failed to copy files: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
