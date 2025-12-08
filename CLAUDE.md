# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a PowerShell utility toolkit for managing Claude Code CLI sessions on Windows. It provides an interactive session manager with arrow key navigation that launches Claude CLI instances in separate Windows Terminal tabs with color coding and logging.

## Project Structure

- **scripts/cpt.ps1** - Claude Session Manager v3.4 (main entry point)
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
  - Automatically includes enterprise-level documentation from `docs` folder in root path
  - Launches Claude CLI with additional working directories when available
  - Logs all activities with date-based log files
  - Parameters: `$ProjectName` (display name), `$ProjectPath` (working directory), `$RootPath` (root folder for enterprise docs)

- **scripts/claude-power-tools/IndexGenerator.ps1** - AI-powered project index generator that:
  - Scans all projects/repos in a root folder
  - Uses Claude AI to intelligently analyze each project (code, structure, dependencies)
  - Detects NuGet packages, internal dependencies, integrations, and key technologies
  - Generates concise AI summaries for each project
  - Creates a comprehensive architecture overview showing how projects relate
  - Produces an index.md file in the docs folder with full context
  - Parameters: `$RootPath` (root folder to scan), `$RootFolderName` (display name)
  - Note: Can take several minutes depending on number of projects

- **publish-local.ps1** - Deployment script that copies the scripts folder to `c:\tools\scripts`

## Architecture

### Session Manager (cpt.ps1)
- **Auto-relaunch mechanism**: Detects if running in a colored tab; if not, relaunches itself in a new light gray (#C0C0C0) tab
- **Two-tier folder selection**: First picks a root folder from `C:\Projects\`, then lists subfolders within that root
- **Index.md initialization**: After selecting a root folder, checks for `docs\index.md` and prompts to generate it if missing
- **Interactive menu system**: Uses arrow keys or number keys with visual feedback (green highlight for selection)
- **Tab management**: The session manager tab is always light gray, renames to "CPT:[RootFolderName]" for easy identification
- **Tab launching**: Creates Windows Terminal tabs with `wt.exe` using PowerShell 7.x in `-NoExit` mode
- **Color coding**: Project tabs cycle through 8 predefined colors to visually distinguish multiple Claude sessions

### Tab Wrapper (ClaudeTabWrapper.ps1)
- Receives project name, path, and root path parameters from the session manager
- Changes to the project directory before launching Claude CLI
- **Enterprise documentation support**: Automatically checks for a `docs` folder in the root path (e.g., `C:\Projects\Zespri-Github\docs`)
  - If found, adds it as an additional working directory using Claude CLI's `--add-dir` flag
  - This gives Claude context access to enterprise-level architecture docs, standards, and guidelines
  - The docs folder is shared across all repos within the same root folder
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
4. Check for `docs\index.md` and offer to generate it if missing
5. Display project subfolders within the selected root folder
6. Launch a new Windows Terminal tab with Claude CLI in the selected project directory (with cycling colors)
7. Ask if you want to open another tab

Navigation:
- Use **arrow keys** (↑/↓) to navigate through options
- Press **Enter** to confirm selection
- Or press **1-9** to quickly select by number
- Press **Q** to quit the current menu

## Enterprise Documentation Support

PowerTools automatically includes enterprise-level documentation in Claude sessions:

1. **Structure**: Place enterprise docs in a `docs` folder within your root project folder
   - Example: `C:\Projects\Zespri-Github\docs\`

2. **Automatic inclusion**: When launching a Claude session for any repo within that root folder, the docs folder is automatically added as an additional working directory

3. **Benefits**:
   - Share architecture documents, coding standards, and guidelines across all repos in a root folder
   - Claude has context about enterprise patterns and requirements without manually specifying them
   - Keeps enterprise docs separate from individual repo documentation

4. **Logging**: Check the log files to confirm when enterprise docs are detected and included

## Project Index Generation (index.md)

PowerTools can automatically generate a comprehensive project index for your root folders:

### Features

1. **Automatic Project Discovery**: Scans all subdirectories in the root folder to discover projects (excludes common folders like docs, node_modules, .git, etc.)

2. **AI-Powered Project Analysis**: For each project, Claude AI analyzes:
   - **Summary**: Concise 2-3 sentence description of purpose and functionality
   - **Type**: Project type (.NET API, .NET Library, Node.js Service, React App, etc.)
   - **Produces**: Outputs like NuGet packages, Docker images, APIs, executables
   - **Internal Dependencies**: References to other projects within the same repository
   - **External Dependencies**: Key frameworks, libraries, and packages used
   - **Integrations**: Systems or projects this integrates with or is consumed by
   - **Key Technologies**: Main technologies, frameworks, and languages

3. **Intelligent Dependency Detection**: Claude examines project references, package references, and import statements to identify:
   - Internal NuGet package dependencies between projects
   - Cross-project references and integrations
   - External framework and library usage

4. **Architecture Overview**: After analyzing all projects, Claude generates a comprehensive architecture document including:
   - Overall architecture description and purpose
   - Key architectural patterns and design approaches
   - Dependency flow between projects
   - Integration points within and outside the repository

### Workflow

When you select a root folder in the Session Manager:
1. PowerTools checks if `docs\index.md` exists
2. If not found, it prompts: "Would you like to generate it now? (Y/N)"
3. If you choose Yes:
   - IndexGenerator.ps1 scans all project folders in the root
   - For each project, launches Claude CLI with a detailed analysis prompt
   - Claude analyzes the project code, structure, and dependencies
   - Collects all project analyses and feeds them to Claude for architecture overview
   - Generates `docs\index.md` with comprehensive documentation

**Important**: This process uses multiple Claude AI API calls and can take several minutes depending on the number of projects. You'll see progress for each project as it's analyzed.

### Example Output

For a root folder with multiple .NET projects, index.md will contain:

**Architecture Overview Section:**
- Comprehensive description of the overall system architecture
- Key patterns and design approaches used
- Dependency flow between projects
- Integration points

**Per-Project Details:**
- Project name and type
- AI-generated 2-3 sentence summary
- NuGet packages or other artifacts produced
- Internal dependencies on other projects
- Key external dependencies (or count if many)
- Integrations with other systems
- Key technologies used

**Example scenario** (Zespri-Github):
- Claude will identify that `dotnet-gen-data-model` produces NuGet packages
- Claude will detect that `dotnet-gen-data-model-attribute-domains` and `dotnet-gen-api` consume those packages
- The architecture overview will explain how these projects form a cohesive data modeling and API generation system
- Internal dependencies will be clearly highlighted with specific package names

### Benefits

- **Context for Claude**: When Claude launches with `--add-dir` pointing to the docs folder, it automatically has access to the index.md file, giving it full context about all projects in the root folder. This is the key benefit - every Claude session knows about all projects.
- **Intelligent Analysis**: Claude AI understands the actual code and structure, not just regex patterns, resulting in accurate summaries and dependency detection
- **Architecture Understanding**: Get a high-level view of how projects integrate and depend on each other
- **Project Overview**: Quickly understand what projects exist and their purposes
- **Dependency Tracking**: See which projects depend on others, including NuGet package relationships
- **Onboarding**: New team members can read the index.md to understand the entire repository structure
- **Living Documentation**: Delete and regenerate the index.md anytime to reflect current state

## Logging

Logs are stored in: `c:\tools\scripts\claude-power-tools\logs\`
- Log files are named by date: `YYYY-MM-DD_start-claude.log`
- Log format: `[yyyy-MM-dd HH:mm:ss] [LEVEL] Message`
- Levels: INFO, WARN, ERROR, DEBUG
- A new log file is created each day
- The log directory is created automatically if it doesn't exist
- The logger fails silently if the log file is inaccessible to avoid breaking execution
