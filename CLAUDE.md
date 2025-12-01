# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a PowerShell utility toolkit for managing Claude Code CLI sessions on Windows. It provides an interactive session manager that launches Claude CLI instances in separate Windows Terminal tabs with automatic tab naming, color coding, and logging.

## Project Structure

- **scripts/cpt.ps1** - Claude Session Manager v3.3 (main entry point)
  - Interactive menu to select projects from `C:\Projects\Zespri-Github`
  - Launches Claude CLI in new Windows Terminal tabs with random colors
  - Supports opening multiple Claude sessions sequentially
  - Uses relative paths to invoke ClaudeTabWrapper.ps1
  - Date-based logging to `claude-power-tools\logs\`

- **scripts/claude-power-tools/ClaudeTabWrapper.ps1** - Core wrapper script that:
  - Changes to a specified project directory
  - Launches Claude CLI in that context
  - Automatically renames the terminal tab to "Claude [ProjectName]" using a timer (runs every 500ms)
  - Logs all activities with date-based log files
  - Parameters: `$ProjectName` (display name), `$ProjectPath` (working directory)

- **publish-local.ps1** - Deployment script that copies the scripts folder to `c:\tools\scripts`

## Architecture

### Session Manager (cpt.ps1)
- Provides an interactive menu listing all projects in a base directory
- Launches Windows Terminal tabs with color-coded tabs using `wt.exe`
- Each tab runs ClaudeTabWrapper.ps1 with PowerShell 7.x in `-NoExit` mode
- Tab colors cycle through 8 predefined colors to help visually distinguish multiple sessions

### Tab Wrapper (ClaudeTabWrapper.ps1)
- Uses an aggressive timer-based approach to maintain terminal tab titles
- A `System.Timers.Timer` runs every 150ms to enforce tab naming
- Uses both PowerShell `WindowTitle` and ANSI escape sequences for maximum compatibility
- Overcomes Claude CLI's behavior of resetting the terminal title on startup
- The timer is properly disposed when Claude exits
- All paths (logging, wrapper location) are relative for portability

## Commands

### Development (from repository)
```powershell
# Run the interactive Claude Session Manager
.\scripts\cpt.ps1

# Publish to local system
.\publish-local.ps1
```

### After Publishing (from c:\tools\scripts)
```powershell
# Run from anywhere after publishing
cpt.ps1
```

The Session Manager will:
1. Display a numbered list of projects from `C:\Projects\Zespri-Github`
2. Prompt you to select a project by number
3. Launch a new Windows Terminal tab with Claude CLI in that project directory
4. Ask if you want to open another tab

## Logging

Logs are stored in: `c:\tools\scripts\claude-power-tools\logs\`
- Log files are named by date: `YYYY-MM-DD_start-claude.log`
- Log format: `[yyyy-MM-dd HH:mm:ss] [LEVEL] Message`
- Levels: INFO, WARN, ERROR, DEBUG
- A new log file is created each day
- The log directory is created automatically if it doesn't exist
- The logger fails silently if the log file is inaccessible to avoid breaking execution
