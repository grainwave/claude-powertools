# =============================
# Claude Session Manager v3.4
# =============================

trap {
    Write-Host "GLOBAL ERROR: " + $_.Exception.Message -ForegroundColor Red
    continue
}

# ============================================
# Auto-relaunch in colored tab if needed
# ============================================
if (-not $env:CPT_COLORED_TAB) {
    # Not running in a colored tab yet - relaunch with color
    $env:CPT_COLORED_TAB = "1"
    $scriptPath = $PSCommandPath
    wt.exe -w 0 nt `
        --title "Claude PowerTools" `
        --tabColor "#C0C0C0" `
        pwsh -NoExit -Command "& '$scriptPath'"
    exit
}

$RootProjectsPath = "C:\Projects"
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
# Interactive Menu with Arrow Key Navigation
# ============================================
function Show-InteractiveMenu {
    param(
        [string]$Title,
        [array]$Items
    )

    if ($Items.Count -eq 0) {
        Write-Host "No items available." -ForegroundColor Red
        return $null
    }

    $selectedIndex = 0
    $exitMenu = $false

    while (-not $exitMenu) {
        Clear-Host
        Write-Host "==== $Title ====" -ForegroundColor Cyan
        Write-Host ""

        for ($i = 0; $i -lt $Items.Count; $i++) {
            if ($i -eq $selectedIndex) {
                Write-Host "> " -NoNewline -ForegroundColor Green
                Write-Host $Items[$i].Name -ForegroundColor Green
            }
            else {
                Write-Host "  " -NoNewline
                Write-Host $Items[$i].Name
            }
        }

        Write-Host ""
        Write-Host "Use " -NoNewline
        Write-Host "↑/↓" -NoNewline -ForegroundColor Yellow
        Write-Host " or " -NoNewline
        Write-Host "1-9" -NoNewline -ForegroundColor Yellow
        Write-Host " to select, " -NoNewline
        Write-Host "Enter" -NoNewline -ForegroundColor Yellow
        Write-Host " to confirm, " -NoNewline
        Write-Host "Q" -NoNewline -ForegroundColor Yellow
        Write-Host " to quit"

        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        switch ($key.VirtualKeyCode) {
            38 {
                # Up arrow
                $selectedIndex = ($selectedIndex - 1)
                if ($selectedIndex -lt 0) { $selectedIndex = $Items.Count - 1 }
            }
            40 {
                # Down arrow
                $selectedIndex = ($selectedIndex + 1) % $Items.Count
            }
            13 {
                # Enter
                $exitMenu = $true
            }
            81 {
                # Q key
                return $null
            }
            default {
                # Check for number keys (1-9)
                if ($key.Character -match '^\d$') {
                    $num = [int]::Parse($key.Character)
                    if ($num -ge 1 -and $num -le $Items.Count) {
                        $selectedIndex = $num - 1
                        $exitMenu = $true
                    }
                }
            }
        }
    }

    Write-Log ("Selected: " + $Items[$selectedIndex].Name)
    return $Items[$selectedIndex]
}

# ============================================
# Root Folder Selection
# ============================================
function Pick-RootFolder {
    try {
        $folders = Get-ChildItem -Directory -Path $RootProjectsPath -ErrorAction Stop
    }
    catch {
        Write-Log ("Cannot list folders under " + $RootProjectsPath + ": " + $_.Exception.Message) "ERROR"
        return $null
    }

    if ($folders.Count -eq 0) {
        Write-Log ("No folders found under " + $RootProjectsPath) "ERROR"
        return $null
    }

    return Show-InteractiveMenu -Title "Select Root Project Folder" -Items $folders
}

# ============================================
# Project Folder Selection
# ============================================
function Pick-ProjectFolder {
    param([string]$BasePath)

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

    return Show-InteractiveMenu -Title "Select Project Folder" -Items $folders
}

# ============================================
# Launch new Claude tab
# ============================================
function New-ClaudeTab {
    param(
        [string]$Path,
        [string]$RootPath
    )

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
            pwsh -NoExit -File "$WrapperPath" -ProjectName "$FolderName" -ProjectPath "$Path" -RootPath "$RootPath" | Out-Null
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
Write-Host "==== Claude Session Manager ====" -ForegroundColor Cyan
Write-Log "Session Manager started"

# Step 1: Select root folder
$rootFolder = Pick-RootFolder
if (-not $rootFolder) {
    Write-Host "No root folder selected. Exiting." -ForegroundColor Yellow
    Write-Log "No root folder selected. Exiting."
    exit
}

$rootFolderName = $rootFolder.Name
$basePath = $rootFolder.FullName
Write-Log ("Root folder selected: " + $rootFolderName + " at " + $basePath)

# Step 2: Rename this session manager tab
$sessionManagerTitle = "CPT:$rootFolderName"
$host.UI.RawUI.WindowTitle = $sessionManagerTitle
Write-Log ("Session manager tab renamed to: " + $sessionManagerTitle)

# Step 2.5: Check for index.md and offer to generate if missing
$docsPath = Join-Path $basePath "docs"
$indexPath = Join-Path $docsPath "index.md"

if (-not (Test-Path $indexPath)) {
    Write-Host ""
    Write-Host "No index.md found in docs folder." -ForegroundColor Yellow
    Write-Host "The index.md file provides an overview of all projects and their dependencies." -ForegroundColor Gray
    Write-Host ""
    $initialize = Read-Host "Would you like to generate it now? (Y/N)"

    if ($initialize -in @("Y", "y")) {
        Write-Host ""
        Write-Host "Generating index.md..." -ForegroundColor Cyan
        Write-Log "User chose to generate index.md for $rootFolderName"

        $indexGeneratorPath = Join-Path $PSScriptRoot "claude-power-tools\IndexGenerator.ps1"
        if (Test-Path $indexGeneratorPath) {
            try {
                & $indexGeneratorPath -RootPath $basePath -RootFolderName $rootFolderName
                Write-Host ""
                Write-Host "Index generation complete!" -ForegroundColor Green
                Write-Log "Index.md generation completed successfully"
                Start-Sleep 2
            }
            catch {
                Write-Host "Error generating index: $($_.Exception.Message)" -ForegroundColor Red
                Write-Log "Error generating index: $($_.Exception.Message)" "ERROR"
                Start-Sleep 2
            }
        }
        else {
            Write-Host "Error: IndexGenerator.ps1 not found at $indexGeneratorPath" -ForegroundColor Red
            Write-Log "IndexGenerator.ps1 not found at $indexGeneratorPath" "ERROR"
            Start-Sleep 2
        }
    }
    else {
        Write-Log "User declined to generate index.md"
    }
}
else {
    Write-Log "index.md already exists at: $indexPath"
}

# Step 3: Loop to open project tabs
while ($true) {
    $folder = Pick-ProjectFolder -BasePath $basePath
    if ($folder) {
        New-ClaudeTab -Path $folder.FullName -RootPath $basePath
    }
    else {
        Write-Host "No folder selected." -ForegroundColor Yellow
        Start-Sleep 1
        continue
    }

    Clear-Host
    Write-Host "==== Claude Session Manager ====" -ForegroundColor Cyan
    Write-Host "Root: " -NoNewline
    Write-Host $rootFolderName -ForegroundColor Green
    Write-Host ""
    $again = Read-Host "Open another Claude tab? (Y/N)"
    if ($again -notin @("Y", "y")) { break }
}

Write-Log "Session Manager finished"
