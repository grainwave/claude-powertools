# =============================
# Index.md Generator for Claude PowerTools
# =============================
# This script uses Claude AI to intelligently analyze all projects in a root folder
# and generates an index.md file with project summaries, dependencies, and architecture overview.

param(
    [Parameter(Mandatory = $true)]
    [string]$RootPath,

    [Parameter(Mandatory = $true)]
    [string]$RootFolderName
)

# ============================================
# Logger
# ============================================
$LogDate = Get-Date -Format "yyyy-MM-dd"
$LogDir = Join-Path $PSScriptRoot "logs"
$LogFile = Join-Path $LogDir "$LogDate`_index-generator.log"

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
    $Line = "[$Timestamp] [$Level] $Message"
    Write-Host $Line
    try {
        Add-Content -Path $LogFile -Value $Line
    }
    catch {
        # Fail silently
    }
}

Write-Log "Index Generator started for root: $RootPath"

# ============================================
# Ensure docs folder exists
# ============================================
$DocsPath = Join-Path $RootPath "docs"
if (-not (Test-Path $DocsPath)) {
    try {
        New-Item -Path $DocsPath -ItemType Directory -Force | Out-Null
        Write-Log "Created docs folder at: $DocsPath"
    }
    catch {
        Write-Log "Failed to create docs folder: $($_.Exception.Message)" "ERROR"
        exit 1
    }
}

# ============================================
# Get list of all projects
# ============================================
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Claude PowerTools - Index Generator" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Root Folder: " -NoNewline
Write-Host $RootFolderName -ForegroundColor Green
Write-Host "Path: " -NoNewline
Write-Host $RootPath -ForegroundColor Gray
Write-Host ""
Write-Host "This process will use Claude AI to analyze all projects." -ForegroundColor Yellow
Write-Host "It may take several minutes depending on the number of projects." -ForegroundColor Yellow
Write-Host ""

Write-Log "Scanning for projects in: $RootPath"

$projects = Get-ChildItem -Directory -Path $RootPath -ErrorAction SilentlyContinue | Where-Object {
    # Exclude common non-project folders
    $_.Name -notin @('docs', 'node_modules', '.git', '.vs', 'bin', 'obj', 'packages')
}

if (-not $projects -or $projects.Count -eq 0) {
    Write-Host "No project folders found in $RootPath" -ForegroundColor Red
    Write-Log "No project folders found in $RootPath" "ERROR"
    exit 1
}

Write-Host "Found " -NoNewline
Write-Host $projects.Count -NoNewline -ForegroundColor Green
Write-Host " project(s) to analyze"
Write-Host ""

# ============================================
# Analyze each project with Claude
# ============================================
$projectAnalyses = @()
$currentProject = 0

foreach ($project in $projects) {
    $currentProject++
    $projectName = $project.Name
    $projectPath = $project.FullName

    Write-Host "[$currentProject/$($projects.Count)] Analyzing: " -NoNewline
    Write-Host $projectName -ForegroundColor Cyan
    Write-Log "Analyzing project: $projectName at $projectPath"

    # Create analysis prompt for Claude
    $analysisPrompt = @"
You are analyzing a project folder as part of generating a project index for a root repository.

Project Name: $projectName
Project Path: $projectPath

Please analyze this project and provide a JSON response with the following structure:

{
  "summary": "A concise 2-3 sentence summary of what this project does and its main purpose",
  "type": "The type of project (e.g., .NET API, .NET Library, Node.js Service, React App, etc.)",
  "produces": ["List of outputs this project produces, e.g., NuGet packages, Docker images, APIs, executables"],
  "dependencies": {
    "internal": ["List of other projects in this repository that this project depends on - be specific about project names"],
    "external": ["Key external dependencies or frameworks used, e.g., Entity Framework, React, Express"]
  },
  "integrations": ["Other projects or systems this integrates with or is consumed by"],
  "keyTechnologies": ["Main technologies, frameworks, or languages used"]
}

IMPORTANT:
- For "internal" dependencies, look for references to other projects within the same repository structure
- For NuGet packages, check if they match names of other projects in the parent directory
- Look at project references, package references, and import statements
- Be specific and accurate - only include what you can verify from the code

Analyze the project thoroughly and respond ONLY with the JSON object, no additional text.
"@

    # Save prompt to temp file
    $tempPromptFile = Join-Path $env:TEMP "claude_analyze_$projectName.txt"
    $analysisPrompt | Out-File -FilePath $tempPromptFile -Encoding UTF8 -NoNewline

    try {
        # Run Claude CLI to analyze the project
        Push-Location $projectPath
        Write-Host "  Running Claude analysis..." -ForegroundColor Gray

        # Use Get-Content to pipe the prompt to Claude CLI
        $analysisResult = Get-Content $tempPromptFile -Raw | claude 2>&1 | Out-String

        Pop-Location

        if ($analysisResult -and $analysisResult.Trim().Length -gt 0) {
            # Log the raw response for debugging
            Write-Log "  Raw Claude response (first 500 chars): $($analysisResult.Substring(0, [Math]::Min(500, $analysisResult.Length)))" "DEBUG"

            # Try to extract JSON from the response (in case Claude adds extra text)
            # Look for JSON object in the response
            $allMatches = [regex]::Matches($analysisResult, '(?s)(\{(?:[^{}]|\{[^{}]*\})*\})')
            if ($allMatches.Count -gt 0) {
                # Use the last JSON object found (most likely to be the complete response)
                $jsonText = $allMatches[$allMatches.Count - 1].Value

                try {
                    $analysis = $jsonText | ConvertFrom-Json

                    # Add project name and path to the analysis object
                    $analysis | Add-Member -NotePropertyName "projectName" -NotePropertyValue $projectName
                    $analysis | Add-Member -NotePropertyName "projectPath" -NotePropertyValue $projectPath

                    $projectAnalyses += $analysis

                    Write-Host "  ✓ Analysis complete" -ForegroundColor Green
                    Write-Log "Successfully analyzed $projectName" "INFO"
                }
                catch {
                    Write-Host "  ✗ Failed to parse JSON response" -ForegroundColor Red
                    Write-Log "Failed to parse JSON for $projectName : $($_.Exception.Message)" "ERROR"
                    Write-Log "  JSON text was: $jsonText" "DEBUG"
                    # Add a basic entry so we don't lose the project
                    $projectAnalyses += [PSCustomObject]@{
                        projectName = $projectName
                        projectPath = $projectPath
                        summary = "Analysis failed - unable to parse response"
                        type = "Unknown"
                        produces = @()
                        dependencies = @{ internal = @(); external = @() }
                        integrations = @()
                        keyTechnologies = @()
                    }
                }
            }
            else {
                Write-Host "  ✗ No JSON found in response" -ForegroundColor Red
                Write-Log "No JSON found in Claude response for $projectName" "ERROR"
                Write-Log "  Full response: $analysisResult" "DEBUG"
                $projectAnalyses += [PSCustomObject]@{
                    projectName = $projectName
                    projectPath = $projectPath
                    summary = "Analysis failed - no JSON response"
                    type = "Unknown"
                    produces = @()
                    dependencies = @{ internal = @(); external = @() }
                    integrations = @()
                    keyTechnologies = @()
                }
            }
        }
        else {
            Write-Host "  ✗ No response from Claude" -ForegroundColor Red
            Write-Log "No response from Claude for $projectName" "ERROR"
            $projectAnalyses += [PSCustomObject]@{
                projectName = $projectName
                projectPath = $projectPath
                summary = "Analysis failed - no response"
                type = "Unknown"
                produces = @()
                dependencies = @{ internal = @(); external = @() }
                integrations = @()
                keyTechnologies = @()
            }
        }
    }
    catch {
        Write-Host "  ✗ Error during analysis: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "Error analyzing $projectName : $($_.Exception.Message)" "ERROR"
        $projectAnalyses += [PSCustomObject]@{
            projectName = $projectName
            projectPath = $projectPath
            summary = "Analysis failed due to error"
            type = "Unknown"
            produces = @()
            dependencies = @{ internal = @(); external = @() }
            integrations = @()
            keyTechnologies = @()
        }
    }
    finally {
        if (Test-Path $tempPromptFile) {
            Remove-Item $tempPromptFile -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host ""
}

# ============================================
# Generate architecture overview with Claude
# ============================================
Write-Host "Generating architecture overview..." -ForegroundColor Cyan
Write-Log "Generating architecture overview with Claude"

# Create a summary of all projects for Claude to analyze
$projectSummaries = $projectAnalyses | ForEach-Object {
    @"
Project: $($_.projectName)
Type: $($_.type)
Summary: $($_.summary)
Produces: $($_.produces -join ', ')
Internal Dependencies: $($_.dependencies.internal -join ', ')
External Dependencies: $($_.dependencies.external -join ', ')
Integrations: $($_.integrations -join ', ')
Key Technologies: $($_.keyTechnologies -join ', ')
"@
} | Out-String

$architecturePrompt = @"
You are creating an architecture overview for a repository containing multiple projects.

Repository: $RootFolderName

Here are the analyses of all projects in this repository:

$projectSummaries

Based on these project analyses, please provide a comprehensive architecture overview in the following format:

# Architecture Overview

[2-3 paragraphs describing the overall architecture, how projects relate to each other, major integration points, and the overall purpose of this repository]

# Key Patterns

[Bullet points describing architectural patterns, common technologies, or design approaches used across projects]

# Dependency Flow

[Describe the dependency flow between projects - which projects are foundational/core, which depend on others, and how data/functionality flows through the system]

# Integration Points

[Describe how projects integrate with each other and any external systems]

Please write this in clear, professional markdown format.
"@

try {
    Write-Host "  Running Claude architecture analysis..." -ForegroundColor Gray

    # Save architecture prompt to temp file
    $tempArchPromptFile = Join-Path $env:TEMP "claude_architecture_$RootFolderName.txt"
    $architecturePrompt | Out-File -FilePath $tempArchPromptFile -Encoding UTF8 -NoNewline

    # Use Get-Content to pipe the prompt to Claude CLI
    $architectureOverview = Get-Content $tempArchPromptFile -Raw | claude 2>&1 | Out-String

    if ($architectureOverview) {
        Write-Host "  ✓ Architecture overview generated" -ForegroundColor Green
        Write-Log "Architecture overview generated successfully"
    }
    else {
        $architectureOverview = "Architecture overview could not be generated."
        Write-Host "  ✗ Failed to generate architecture overview" -ForegroundColor Yellow
        Write-Log "Failed to generate architecture overview" "WARN"
    }
}
catch {
    $architectureOverview = "Architecture overview generation failed due to error."
    Write-Host "  ✗ Error generating architecture overview: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log "Error generating architecture overview: $($_.Exception.Message)" "ERROR"
}
finally {
    if (Test-Path $tempArchPromptFile) {
        Remove-Item $tempArchPromptFile -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""

# ============================================
# Generate index.md
# ============================================
Write-Host "Generating index.md..." -ForegroundColor Cyan
Write-Log "Generating index.md file"

$indexPath = Join-Path $DocsPath "index.md"
$indexContent = @"
# $RootFolderName - Project Index

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

This document provides an AI-generated overview of all projects in this repository, their relationships, and the overall architecture.

---

$architectureOverview

---

## Projects

"@

# Add each project analysis
foreach ($analysis in ($projectAnalyses | Sort-Object projectName)) {
    $indexContent += "`n### $($analysis.projectName)`n`n"
    $indexContent += "**Type:** $($analysis.type)`n`n"
    $indexContent += "$($analysis.summary)`n`n"

    if ($analysis.produces.Count -gt 0) {
        $indexContent += "**Produces:**`n"
        foreach ($item in $analysis.produces) {
            $indexContent += "- $item`n"
        }
        $indexContent += "`n"
    }

    if ($analysis.dependencies.internal.Count -gt 0) {
        $indexContent += "**Internal Dependencies:**`n"
        foreach ($dep in $analysis.dependencies.internal) {
            $indexContent += "- $dep`n"
        }
        $indexContent += "`n"
    }

    if ($analysis.dependencies.external.Count -gt 0 -and $analysis.dependencies.external.Count -le 10) {
        $indexContent += "**Key External Dependencies:**`n"
        foreach ($dep in $analysis.dependencies.external) {
            $indexContent += "- $dep`n"
        }
        $indexContent += "`n"
    }
    elseif ($analysis.dependencies.external.Count -gt 10) {
        $indexContent += "**External Dependencies:** $($analysis.dependencies.external.Count) packages/libraries`n`n"
    }

    if ($analysis.integrations.Count -gt 0) {
        $indexContent += "**Integrations:**`n"
        foreach ($integration in $analysis.integrations) {
            $indexContent += "- $integration`n"
        }
        $indexContent += "`n"
    }

    if ($analysis.keyTechnologies.Count -gt 0) {
        $indexContent += "**Key Technologies:** " + ($analysis.keyTechnologies -join ', ') + "`n`n"
    }

    $indexContent += "---`n"
}

# Add footer
$indexContent += "`n## Notes`n`n"
$indexContent += "This index was automatically generated by Claude PowerTools using AI analysis. "
$indexContent += "To regenerate, delete this file and run the Claude Session Manager again.`n"

# Save index.md
try {
    $indexContent | Out-File -FilePath $indexPath -Encoding UTF8
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "  ✓ Successfully generated index.md" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Location: " -NoNewline
    Write-Host $indexPath -ForegroundColor Cyan
    Write-Host ""
    Write-Log "Successfully generated index.md at: $indexPath"
}
catch {
    Write-Host ""
    Write-Host "✗ Error writing index.md: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log "Error writing index.md: $($_.Exception.Message)" "ERROR"
    exit 1
}

Write-Log "Index Generator completed successfully"
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
