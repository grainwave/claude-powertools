# ============================================
# Claude PowerTools Launcher
# ============================================
# Launches cpt.ps1 in a new Windows Terminal tab with a light gray color

$CptPath = Join-Path $PSScriptRoot "cpt.ps1"
$TabColor = "#C0C0C0"  # Light gray

Write-Host "Launching Claude PowerTools..." -ForegroundColor Cyan

# Launch in a new Windows Terminal tab with color
wt.exe -w 0 nt `
    --title "Claude PowerTools" `
    --tabColor "$TabColor" `
    pwsh -NoExit -File "$CptPath"
