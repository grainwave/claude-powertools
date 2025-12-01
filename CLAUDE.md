# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a PowerShell utility toolkit for managing Claude Code CLI sessions on Windows. It provides an interactive session manager with arrow key navigation that launches Claude CLI instances in separate Windows Terminal tabs with color coding and logging.

## Project Structure

- **scripts/cpt.ps1** - Claude Session Manager v3.3 (main entry point)
  - **Auto-relaunch feature**: Automatically relaunches itself in a light gray colored tab if not already running in one
  - Two-step folder selection process:
    1. Select a root folder from `C:\Projects\`
    2. Select project subfolders within that root
  - Renames the session manager tab to "CPT:[RootFolderName]"
  - Tab color: Light gray (#C0C0C0) for easy identification
  - Interactive menu with arrow key (↑/↓) navigation or number (1-9) selection
  - Launches Claude CLI in new Windows Terminal tabs with cycling colors
  - Supports opening multiple Claude sessions sequentially
  - Uses relative paths to invoke ClaudeTabWrapper.ps1
  - Date-based logging to `claude-power-tools\logs\`

- **scripts/claude-power-tools/ClaudeTabWrapper.ps1** - Core wrapper script that:
  - Changes to a specified project directory
  - Launches Claude CLI in that context
  - Logs all activities with date-based log files
  - Parameters: `$ProjectName` (display name), `$ProjectPath` (working directory)

- **publish-local.ps1** - Deployment script that copies the scripts folder to `c:\tools\scripts`

## Architecture

### Session Manager (cpt.ps1)
- **Auto-relaunch mechanism**: Detects if running in a colored tab; if not, relaunches itself in a new light gray (#C0C0C0) tab
- **Two-tier folder selection**: First picks a root folder from `C:\Projects\`, then lists subfolders within that root
- **Interactive menu system**: Uses arrow keys or number keys with visual feedback (green highlight for selection)
- **Tab management**: The session manager tab is always light gray, renames to "CPT:[RootFolderName]" for easy identification
- **Tab launching**: Creates Windows Terminal tabs with `wt.exe` using PowerShell 7.x in `-NoExit` mode
- **Color coding**: Project tabs cycle through 8 predefined colors to visually distinguish multiple Claude sessions

### Tab Wrapper (ClaudeTabWrapper.ps1)
- Receives project name and path parameters from the session manager
- Changes to the project directory before launching Claude CLI
- Logs all startup and shutdown events
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
1. Auto-relaunch in a light gray colored tab if needed (for easy visual identification)
2. Display an interactive menu of root folders from `C:\Projects\`
3. After selecting a root folder, rename its tab to "CPT:[RootFolderName]"
4. Display project subfolders within the selected root folder
5. Launch a new Windows Terminal tab with Claude CLI in the selected project directory (with cycling colors)
6. Ask if you want to open another tab

Navigation:
- Use **arrow keys** (↑/↓) to navigate through options
- Press **Enter** to confirm selection
- Or press **1-9** to quickly select by number
- Press **Q** to quit the current menu

## Logging

Logs are stored in: `c:\tools\scripts\claude-power-tools\logs\`
- Log files are named by date: `YYYY-MM-DD_start-claude.log`
- Log format: `[yyyy-MM-dd HH:mm:ss] [LEVEL] Message`
- Levels: INFO, WARN, ERROR, DEBUG
- A new log file is created each day
- The log directory is created automatically if it doesn't exist
- The logger fails silently if the log file is inaccessible to avoid breaking execution
