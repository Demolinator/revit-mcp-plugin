# ============================================================
# Revit MCP - Local-First Setup for Claude Desktop / Cowork
# ============================================================
# Wires the Revit MCP server into Claude Desktop over local stdio.
# No ngrok, no tunnel, no terminal to keep open. Run ONCE.
#
# Optional: -EnableWebMobile also sets up the ngrok remote connector
# for use from claude.ai web / phone (delegates to setup-web-mobile.ps1).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File setup-revit-mcp.ps1
#   powershell -ExecutionPolicy Bypass -File setup-revit-mcp.ps1 -DryRun
#   powershell -ExecutionPolicy Bypass -File setup-revit-mcp.ps1 -EnableWebMobile
# ============================================================
param(
  [switch] $DryRun,
  [string] $ServerDir,
  [string] $ConfigPath,
  [switch] $EnableWebMobile
)

$MCP_REPO_URL = "https://github.com/Demolinator/revit-mcp-server.git"
$MCP_ZIP_URL  = "https://github.com/Demolinator/revit-mcp-server/archive/refs/heads/master.zip"

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$SCRIPT_DIR\lib\Find-ClaudeConfig.ps1"
. "$SCRIPT_DIR\lib\Set-RevitMcpConnector.ps1"
. "$SCRIPT_DIR\lib\Enable-PyRevitRoutes.ps1"

if (-not $ServerDir) { $ServerDir = Join-Path $SCRIPT_DIR "mcp-server" }

function Section($t) { Write-Host ""; Write-Host "  --- $t ---" -ForegroundColor Cyan }
function Ok($t)   { Write-Host "      [OK] $t" -ForegroundColor Green }
function Info($t) { Write-Host "      $t" -ForegroundColor Gray }
function Warn($t) { Write-Host "      [WARN] $t" -ForegroundColor Yellow }

Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Cyan
Write-Host "      Revit MCP - Local-First Setup (no ngrok)" -ForegroundColor White
Write-Host "  ============================================================" -ForegroundColor Cyan
if ($DryRun) { Write-Host "      *** DRY RUN - no changes will be made ***" -ForegroundColor Yellow }

# ---- 1. Server runtime (uv + deps) ----
Section "MCP server runtime"
if ($DryRun) {
  Info "Would verify uv, ensure server at: $ServerDir, and run 'uv sync'."
} else {
  $uv = (Get-Command uv -ErrorAction SilentlyContinue).Source
  if (-not $uv) { throw "uv not found. Install it from https://docs.astral.sh/uv/ then re-run." }
  Ok "uv found ($uv)"

  if (-not (Test-Path (Join-Path $ServerDir "main.py"))) {
    Info "MCP server not found locally. Downloading from GitHub..."
    if (Test-Path $ServerDir) { Remove-Item $ServerDir -Recurse -Force -ErrorAction SilentlyContinue }
    $parent = Split-Path $ServerDir
    if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $downloaded = $false
    # Method 1: git clone (if git is available)
    if (Get-Command git -ErrorAction SilentlyContinue) {
      $tmp = Join-Path $env:TEMP ("revit-mcp-clone-" + [guid]::NewGuid().ToString("N"))
      $prevEAP = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
      & git clone --depth 1 $MCP_REPO_URL $tmp | Out-Null
      $code = $LASTEXITCODE
      $ErrorActionPreference = $prevEAP
      if ($code -eq 0 -and (Test-Path (Join-Path $tmp "main.py"))) {
        Move-Item -Force $tmp $ServerDir; $downloaded = $true; Ok "Server downloaded (git clone)"
      } elseif (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
    # Method 2: ZIP download (no git required)
    if (-not $downloaded) {
      $zip = Join-Path $env:TEMP ("revit-mcp-" + [guid]::NewGuid().ToString("N") + ".zip")
      $ext = Join-Path $env:TEMP ("revit-mcp-ext-" + [guid]::NewGuid().ToString("N"))
      $ProgressPreference = 'SilentlyContinue'
      Invoke-WebRequest -Uri $MCP_ZIP_URL -OutFile $zip -UseBasicParsing
      Expand-Archive -Path $zip -DestinationPath $ext -Force
      $inner = Get-ChildItem -Path $ext -Directory | Select-Object -First 1
      if ($inner -and (Test-Path (Join-Path $inner.FullName "main.py"))) {
        Move-Item -Force $inner.FullName $ServerDir; $downloaded = $true; Ok "Server downloaded (ZIP)"
      }
      Remove-Item $zip -Force -ErrorAction SilentlyContinue
      Remove-Item $ext -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (-not $downloaded) { throw "Could not download the MCP server. Check your internet connection." }
  } else {
    Ok "MCP server found at $ServerDir"
  }
  Push-Location $ServerDir
  try {
    # uv writes progress to stderr; under ErrorActionPreference=Stop PowerShell 5.1
    # raises that as a fatal NativeCommandError even on success. Drop to Continue
    # around the native call and gate on the exit code instead.
    $prevEAP = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & uv sync | Out-Null
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
    if ($code -ne 0) { throw "uv sync failed (exit $code)" }
    Ok "Dependencies installed (uv sync)"
  } finally { Pop-Location }
}

# ---- 2. pyRevit Routes ----
Section "pyRevit Routes"
if ($DryRun) {
  Info "Would enable pyRevit Routes on port 48884 (auto via pyRevit CLI)."
} else {
  $r = Enable-PyRevitRoutes -Port 48884
  if ($r.ok) { Ok $r.message } else { Warn $r.message }
}

# ---- 3. Claude Desktop connector ----
Section "Claude Desktop connector"
$cfg = if ($ConfigPath) { $ConfigPath } else { Find-ClaudeConfig }
Info "Config path: $cfg"
if ($DryRun) {
  Info "Would write mcpServers.revit connector (stdio) pointing at:"
  Info "  $(Join-Path $ServerDir '.venv\Scripts\python.exe') $(Join-Path $ServerDir 'main.py')"
} else {
  Set-RevitMcpConnector -ConfigPath $cfg -ServerDir $ServerDir
  Ok "mcpServers.revit connector written (backup saved alongside config)"
}

# ---- 4. Optional: web/mobile via ngrok ----
if ($EnableWebMobile) {
  Section "Optional: web/mobile (ngrok)"
  $web = Join-Path $SCRIPT_DIR "setup-web-mobile.ps1"
  if ($DryRun) { Info "Would run $web to configure the ngrok remote connector." }
  elseif (Test-Path $web) { & $web }
  else { Warn "setup-web-mobile.ps1 not found; skipping web/mobile setup." }
}

# ---- Done ----
Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Green
if ($DryRun) {
  Write-Host "      DRY RUN COMPLETE - nothing was changed." -ForegroundColor White
} else {
  Write-Host "      SETUP COMPLETE" -ForegroundColor White
  Write-Host ""
  Write-Host "      Next steps:" -ForegroundColor White
  Write-Host "      1. Open Revit with a project (pyRevit Routes loads automatically)." -ForegroundColor Gray
  Write-Host "      2. Restart Claude Desktop so it loads the 'revit' connector." -ForegroundColor Gray
  Write-Host "      3. In Claude/Cowork you'll see the 'revit' tools - no terminal needed." -ForegroundColor Gray
  Write-Host ""
  Write-Host "      Verify: logs\mcp-server-revit.log should show" -ForegroundColor Gray
  Write-Host "              'Server started and connected successfully'." -ForegroundColor Gray
}
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host ""
