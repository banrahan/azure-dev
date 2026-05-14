# install-azd-ext.ps1 — Build and install a local azd extension + core azd binary,
# and configure environment variables for local agent template development.
#
# Usage:
#   .\install-azd-ext.ps1                    # builds azure.ai.agents extension only
#   .\install-azd-ext.ps1 -Core              # also builds and installs core azd
#   .\install-azd-ext.ps1 -ExtDir <path>     # builds a specific extension directory
#
# Environment variables set globally (User scope):
#   AZD_AGENT_TEMPLATES_PATH  — points to local foundry-samples templates.json
#   AZD_AGENT_CLONE_SKILLS    — enables Copilot skills download during init

param(
    [switch]$Core,
    [string]$ExtDir = ""
)

$ErrorActionPreference = "Stop"

$RepoRoot = git rev-parse --show-toplevel 2>$null
if (-not $RepoRoot) {
    Write-Error "ERROR: not inside a git repo"
    exit 1
}

$AzdDir = Join-Path $RepoRoot "cli/azd"
$DefaultExt = "azure.ai.agents"

if (-not $ExtDir) {
    $ExtDir = Join-Path $AzdDir "extensions/$DefaultExt"
}

# Resolve extension ID from directory name
$ExtId = Split-Path $ExtDir -Leaf
# Convention: dots → dashes for binary name
$ExtBinName = ($ExtId -replace '\.', '-') + "-windows-amd64.exe"
$InstallDir = Join-Path $env:USERPROFILE ".azd/extensions/$ExtId"

Write-Host "==> Extension: $ExtId"
Write-Host "    Source:    $ExtDir"
Write-Host "    Install:   $InstallDir\$ExtBinName"

# Step 1: Ensure extension is registered
if (-not (Test-Path $InstallDir)) {
    Write-Host "==> Extension not installed, registering via azd extension install..."
    azd extension install $ExtId
}

# Step 2: Build core azd if requested
if ($Core) {
    Write-Host "==> Building core azd..."
    Push-Location $AzdDir
    try {
        go build
        $AzdExe = Join-Path $AzdDir "azd.exe"
        $AzdDest = (Get-Command azd -ErrorAction SilentlyContinue).Source
        if ($AzdDest) {
            Copy-Item $AzdExe $AzdDest -Force
            Write-Host "    Installed core azd to $AzdDest"
        } else {
            Write-Host "    WARNING: could not find azd in PATH. Built at $AzdExe"
        }
    } finally {
        Pop-Location
    }
}

# Step 3: Build the extension
Write-Host "==> Building extension..."
Push-Location $ExtDir
try {
    $env:GOOS = "windows"
    $env:GOARCH = "amd64"
    go build -o "bin/$ExtBinName" .
} finally {
    Pop-Location
}

# Step 4: Install the extension binary
Copy-Item (Join-Path $ExtDir "bin/$ExtBinName") (Join-Path $InstallDir $ExtBinName) -Force

# Step 5: Set environment variables globally (User scope)
$TemplatesPath = Join-Path $env:USERPROFILE "working/foundry-samples/templates.json"

$CurrentTemplates = [Environment]::GetEnvironmentVariable("AZD_AGENT_TEMPLATES_PATH", "User")
if (-not $CurrentTemplates) {
    [Environment]::SetEnvironmentVariable("AZD_AGENT_TEMPLATES_PATH", $TemplatesPath, "User")
    Write-Host "==> Set AZD_AGENT_TEMPLATES_PATH (User scope)"
} else {
    Write-Host "==> AZD_AGENT_TEMPLATES_PATH already set"
}

$CurrentSkills = [Environment]::GetEnvironmentVariable("AZD_AGENT_CLONE_SKILLS", "User")
if (-not $CurrentSkills) {
    [Environment]::SetEnvironmentVariable("AZD_AGENT_CLONE_SKILLS", "true", "User")
    Write-Host "==> Set AZD_AGENT_CLONE_SKILLS (User scope)"
} else {
    Write-Host "==> AZD_AGENT_CLONE_SKILLS already set"
}

# Also set for current session
$env:AZD_AGENT_TEMPLATES_PATH = $TemplatesPath
$env:AZD_AGENT_CLONE_SKILLS = "true"

Write-Host "==> Done! Extension $ExtId installed from local build."
