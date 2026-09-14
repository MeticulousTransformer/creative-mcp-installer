[CmdletBinding()]
param(
    [ValidateSet('all', 'godot', 'blender', 'after-effects', 'premiere-pro', 'unreal-engine')]
    [string]$Selection = '',
    [switch]$DryRun,
    [switch]$NoConfig,
    [switch]$ReplaceConfig
)

$ErrorActionPreference = 'Stop'
$InstallRoot = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.creative-mcps'
$InstallerIsWindows = $env:OS -eq 'Windows_NT'
$NpmRoot = Join-Path $InstallRoot 'npm'
function Get-NodePath { if ($DryRun) { return 'C:\path\to\node.exe' }; return (Get-Command node -ErrorAction Stop).Source }

function Write-Title { param([string]$Text) Write-Host "`n=== $Text ===" -ForegroundColor Cyan }
function Write-Note { param([string]$Text) Write-Host "  $Text" }
function Write-WarningNote { param([string]$Text) Write-Host "  $Text" -ForegroundColor Yellow }
function Invoke-Step { param([string]$Label, [scriptblock]$Action); if ($DryRun) { Write-Note "Dry run: would $Label"; return }; Write-Note $Label; $global:LASTEXITCODE = 0; & $Action; if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "Failed to $Label (exit code $LASTEXITCODE)." } }
function Require-Command { param([string]$Name, [string]$Why); if ($DryRun) { return }; if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) { throw "'$Name' is required to $Why. Install it, reopen this installer, and try again." } }
function Ensure-CodexEntry {
    param([string]$Name, [string[]]$Arguments, [switch]$Http)
    if ($NoConfig) { Write-Note "Skipping Codex configuration for $Name."; return }
    Require-Command 'codex' 'configure MCP servers in Codex'
    if ($DryRun) { Write-Note "Dry run: would add $Name to Codex."; return }
    & codex mcp get $Name *> $null
    if ($LASTEXITCODE -eq 0 -and -not $ReplaceConfig) { Write-Note "$Name is already configured in Codex; left unchanged. To repair it, rerun with -Selection $Name -ReplaceConfig."; return }
    if ($Http) { & codex mcp add $Name --url $Arguments[0] } else { & codex mcp add $Name -- @Arguments }
    if ($LASTEXITCODE -ne 0) { throw "Codex could not add $Name." }
    Write-Note "Added $Name to Codex."
}
function Install-Godot { Write-Title 'Godot MCP'; Require-Command 'npm' 'install Godot MCP'; Invoke-Step 'install Godot MCP' { npm install --prefix $NpmRoot -g '@coding-solo/godot-mcp@0.1.1' }; Ensure-CodexEntry -Name 'godot' -Arguments @((Get-NodePath), (Join-Path $NpmRoot 'node_modules\@coding-solo\godot-mcp\build\index.js')); Write-Note 'Open Godot once after installation. If it is not found automatically, set GODOT_PATH in your Codex MCP settings.' }
function Install-Blender {
    Write-Title 'Blender MCP'; Require-Command 'python' 'install Blender MCP'; Require-Command 'git' 'install Blender MCP from Blender Lab'
    $venvRoot = Join-Path $InstallRoot 'blender-mcp'; $venvPython = Join-Path $venvRoot 'Scripts\python.exe'
    if (-not $InstallerIsWindows) { $venvPython = Join-Path $venvRoot 'bin/python' }
    if (-not (Test-Path $venvPython)) { Invoke-Step 'create Blender MCP private environment' { python -m venv $venvRoot } }
    Invoke-Step 'install Blender MCP from Blender Lab' { & $venvPython -m pip install 'git+https://projects.blender.org/lab/blender_mcp.git#subdirectory=mcp' }
    Ensure-CodexEntry -Name 'blender' -Arguments @($venvPython, '-m', 'blmcp')
    Write-Note 'In Blender: Preferences > Get Extensions > add https://lab.blender.org/ > install and enable MCP. Then start its local bridge.'
}
function Install-AfterEffects {
    Write-Title 'After Effects MCP'
    if (-not $InstallerIsWindows) { Write-WarningNote 'After Effects MCP is not installed: run Install on macOS.command for macOS support.'; return }
    Require-Command 'git' 'download After Effects MCP'; Require-Command 'npm' 'build After Effects MCP'
    if (-not (Test-Path $InstallRoot)) { Invoke-Step 'create the private creative MCP folder' { New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null } }
    $repo = Join-Path $InstallRoot 'after-effects-mcp'
    if (-not (Test-Path $repo)) { Invoke-Step 'download After Effects MCP' { git clone 'https://github.com/HeroicSwan/after-effects-mcp.git' $repo } } else { Write-Note "Using existing independent copy at $repo (not updated automatically)." }
    Invoke-Step 'install After Effects MCP dependencies' { Push-Location $repo; try { npm install --package-lock=false } finally { Pop-Location } }
    Invoke-Step 'build After Effects MCP' { Push-Location $repo; try { npm run build } finally { Pop-Location } }
    Invoke-Step 'install the After Effects bridge' { Push-Location $repo; try { npm run install-bridge } finally { Pop-Location } }
    Ensure-CodexEntry -Name 'after-effects' -Arguments @((Get-NodePath), (Join-Path $repo 'dist\index.js'), 'serve')
    Write-Note 'In After Effects enable Allow Scripts to Write Files and Access Network, then open Window > ae-mcp-status.jsx and click CONNECT BRIDGE.'
}
function Install-Premiere { Write-Title 'Premiere Pro MCP'; if (-not $InstallerIsWindows -and $PSVersionTable.Platform -eq 'Unix' -and $IsMacOS -eq $false) { Write-WarningNote 'Premiere Pro MCP is not installed: Adobe Premiere Pro is not supported on Linux.'; return }; Require-Command 'npm' 'install Premiere Pro MCP'; Invoke-Step 'install Premiere Pro MCP' { npm install --prefix $NpmRoot -g 'premiere-pro-mcp@1.6.0' }; Invoke-Step 'install the Premiere bridge panel' { & (Get-NodePath) (Join-Path $NpmRoot 'node_modules\premiere-pro-mcp\dist\index.js') --install-cep }; Invoke-Step 'verify the Premiere bridge panel' { & (Get-NodePath) (Join-Path $NpmRoot 'node_modules\premiere-pro-mcp\dist\index.js') --diagnose-cep }; Ensure-CodexEntry -Name 'premiere-pro' -Arguments @((Get-NodePath), (Join-Path $NpmRoot 'node_modules\premiere-pro-mcp\dist\index.js')); Write-Note 'Restart Premiere Pro, then confirm Window > Extensions > MCP Bridge shows Running.' }
function Install-Unreal { Write-Title 'Unreal Engine MCP'; Ensure-CodexEntry -Name 'unreal-engine' -Arguments @('http://127.0.0.1:8000/mcp') -Http; Write-Note 'In Unreal Engine 5.8, enable Unreal MCP, Python Editor Script Plugin, and EditorToolset. Restart the editor and start the loopback MCP server on port 8000.' }
function Get-Selection { if ($Selection) { return $Selection }; Write-Host 'Choose what to install: all, godot, blender, after-effects, premiere-pro, unreal-engine.'; $answer = Read-Host 'Press Enter for all'; if ([string]::IsNullOrWhiteSpace($answer)) { return 'all' }; return $answer.Trim().ToLowerInvariant() }
$requested = Get-Selection
if ($requested -notin @('all', 'godot', 'blender', 'after-effects', 'premiere-pro', 'unreal-engine')) { throw "Unknown choice '$requested'." }
Write-Host 'Creative MCP Installer' -ForegroundColor Green
if (-not $NoConfig) { Require-Command 'codex' 'configure MCP servers in Codex' }
Write-Note 'This installer creates independent per-user copies and preserves existing Codex entries unless -ReplaceConfig is set. Existing MCP source folders are never changed.'
switch ($requested) {
    'all' { Install-Godot; Install-Blender; Install-AfterEffects; Install-Premiere; Install-Unreal }
    'godot' { Install-Godot }; 'blender' { Install-Blender }; 'after-effects' { Install-AfterEffects }; 'premiere-pro' { Install-Premiere }; 'unreal-engine' { Install-Unreal }
}
if ($DryRun) { Write-Host "`nPreview complete. Nothing was installed."; exit 0 }
Write-Host "`nInstallation steps completed. Restart Codex and follow the app-side steps above. Live app connections have not been tested by this installer." -ForegroundColor Green
