param(
    [string]$ProjectName,
    [string]$ProjectPath
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
# Setup custom prompt to maintain tab title
# ============================================
$DesiredTitle = "Claude [$ProjectName]"

# Inject a profile script that sets the title in the prompt
$ProfileScript = @"
# Custom prompt that maintains tab title
`$global:ClaudeProjectTitle = '$DesiredTitle'

function prompt {
    # Set window title every time prompt is drawn
    `$host.UI.RawUI.WindowTitle = `$global:ClaudeProjectTitle

    # Return the normal prompt
    "PS `$(`$executionContext.SessionState.Path.CurrentLocation)> "
}
"@

$TempProfilePath = [System.IO.Path]::GetTempFileName() + ".ps1"
Set-Content -Path $TempProfilePath -Value $ProfileScript
Write-Log "Created temporary profile at: $TempProfilePath"

# ============================================
# Launch Claude in the foreground
# ============================================
Write-Log "Launching Claude CLI"

try {
    # Source the profile script to inject the prompt function
    . $TempProfilePath
    Write-Log "Injected custom prompt function"

    # Now launch Claude in this session
    claude
    Write-Log "Claude exited normally"
}
catch {
    Write-Log "Error running Claude: $($_.Exception.Message)" "ERROR"
}
finally {
    # Cleanup temp profile
    if (Test-Path $TempProfilePath) {
        Remove-Item $TempProfilePath -Force -ErrorAction SilentlyContinue
        Write-Log "Cleaned up temporary profile"
    }
}

Write-Log "Wrapper finished for project '$ProjectName'"
