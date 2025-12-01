# =============================
# Claude Session Manager v3.3
# =============================

trap {
    Write-Host "GLOBAL ERROR: " + $_.Exception.Message -ForegroundColor Red
    continue
}

$BasePath = "C:\Projects\Zespri-Github"
$TabColors = @("#0078D4", "#2D7D46", "#8B2F97", "#D83B01", "#498205", "#5C2D91", "#E81123", "#FF8C00")
$global:ClaudeTabIndex = 0

# Resolve correct PowerShell 7.x executable
$Pwsh = (Get-Command pwsh).Source

# ============================================
# Logger
# ============================================
$LogDate = Get-Date -Format "yyyy-MM-dd"
$LogDir = Join-Path $PSScriptRoot "claude-power-tools\logs"
$LogFile = Join-Path $LogDir "$LogDate`_start-claude.log"

# Ensure log directory exists
if (-not (Test-Path $LogDir)) {
    try {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
    catch {
        # Fail silently
    }
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Line = "[" + $Timestamp + "] [" + $Level + "] " + $Message
    # Output to console
    Write-Host $Line
    # Append to log file
    try {
        Add-Content -Path $LogFile -Value $Line
    }
    catch {
        # Fail silently
    }
}

# ============================================
# Folder Selection
# ============================================
function Pick-ProjectFolder {
    try {
        $folders = Get-ChildItem -Directory -Path $BasePath -ErrorAction Stop
    }
    catch {
        Write-Log ("Cannot list folders under " + $BasePath + ": " + $_.Exception.Message) "ERROR"
        return $null
    }

    if ($folders.Count -eq 0) {
        Write-Log ("No project folders found under " + $BasePath) "ERROR"
        return $null
    }

    Write-Host "`nSelect a project folder:`n"
    for ($i = 0; $i -lt $folders.Count; $i++) {
        Write-Host "[$($i+1)] " + $folders[$i].Name
    }

    $choiceRaw = Read-Host "`nEnter number"

    [int]$choice = $null
    if (-not [int]::TryParse($choiceRaw, [ref]$choice)) {
        Write-Host "Invalid selection (not a number)." -ForegroundColor Red
        Write-Log "Invalid folder selection: not a number" "WARN"
        return $null
    }

    if ($choice -lt 1 -or $choice -gt $folders.Count) {
        Write-Host "Invalid selection (out of range)." -ForegroundColor Red
        Write-Log "Invalid folder selection: out of range" "WARN"
        return $null
    }

    $selected = $folders[$choice - 1]
    Write-Log ("Selected project folder: " + $selected.Name)
    return $selected
}

# ============================================
# Launch new Claude tab
# ============================================
function New-ClaudeTab {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Host "ERROR: Path does not exist: " + $Path -ForegroundColor Red
        Write-Log ("Path does not exist: " + $Path) "ERROR"
        return
    }

    try {
        $FolderName = Split-Path $Path -Leaf
        $Color = $TabColors[$global:ClaudeTabIndex % $TabColors.Count]
        $global:ClaudeTabIndex++

        $WrapperPath = Join-Path $PSScriptRoot "claude-power-tools\ClaudeTabWrapper.ps1"
        if (-not (Test-Path $WrapperPath)) {
            Write-Host "ERROR: Wrapper script not found at " + $WrapperPath -ForegroundColor Red
            Write-Log ("Wrapper script not found: " + $WrapperPath) "ERROR"
            return
        }

        Write-Log ("Launching new Windows Terminal tab for project '" + $FolderName + "'")
        wt.exe -w 0 nt `
            --title "...loading Claude" `
            --tabColor "$Color" `
            pwsh -NoExit -File "$WrapperPath" -ProjectName "$FolderName" -ProjectPath "$Path" | Out-Null
    }
    catch {
        Write-Host "ERROR: Failed to open Claude tab." -ForegroundColor Red
        Write-Log ("Failed to open Claude tab: " + $_.Exception.Message) "ERROR"
    }
}

# ============================================
# Main
# ============================================
Clear-Host
Write-Host "==== Claude Session Manager ===="
Write-Log "Session Manager started"

while ($true) {
    $folder = Pick-ProjectFolder
    if ($folder) {
        New-ClaudeTab -Path $folder.FullName
    }
    else {
        Write-Host "Please select a valid folder." -ForegroundColor Yellow
        Start-Sleep 1
        continue
    }

    $again = Read-Host "`nOpen another Claude tab? (Y/N)"
    if ($again -notin @("Y", "y")) { break }
}

Write-Log "Session Manager finished"
