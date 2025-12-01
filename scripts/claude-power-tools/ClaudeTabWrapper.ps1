param(
    [string]$ProjectName,
    [string]$ProjectPath,
    [string]$RootPath
)

# ============================================
# Logger
# ============================================
$LogDate = Get-Date -Format "yyyy-MM-dd"
$LogDir = Join-Path $PSScriptRoot "logs"
$LogFile = Join-Path $LogDir "$LogDate`_start-claude.log"

# Ensure log directory exists
if (-not (Test-Path $LogDir)) {
    try {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
    catch {
        # Fail silently to avoid breaking the script
    }
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Line = "[$Timestamp] [$Level] $Message"
    # Output to console
    Write-Host $Line
    # Append to log file
    try {
        Add-Content -Path $LogFile -Value $Line
    }
    catch {
        # Fail silently to avoid breaking the script
    }
}

Write-Log "Wrapper started for project '$ProjectName' at '$ProjectPath'"

# ============================================
# Change to project folder
# ============================================
try {
    Set-Location $ProjectPath
    Write-Log "Changed directory to $ProjectPath"
}
catch {
    Write-Log "Failed to change directory: $($_.Exception.Message)" "ERROR"
    exit
}

# ============================================
# Check for enterprise docs folder
# ============================================
$DocsPath = $null
if ($RootPath) {
    $PotentialDocsPath = Join-Path $RootPath "docs"
    if (Test-Path $PotentialDocsPath) {
        $DocsPath = $PotentialDocsPath
        Write-Log "Found enterprise docs folder at: $DocsPath"
    }
    else {
        Write-Log "No enterprise docs folder found at: $PotentialDocsPath" "DEBUG"
    }
}

# ============================================
# Launch Claude in the foreground
# ============================================
Write-Log "Launching Claude CLI"
try {
    if ($DocsPath) {
        Write-Log "Including enterprise docs folder: $DocsPath"
        claude --add-dir "$DocsPath"
    }
    else {
        claude
    }
    Write-Log "Claude exited normally"
}
catch {
    Write-Log "Error running Claude: $($_.Exception.Message)" "ERROR"
}

Write-Log "Wrapper finished for project '$ProjectName'"
