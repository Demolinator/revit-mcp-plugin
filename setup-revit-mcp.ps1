# ============================================================
# Revit MCP — One-Time Setup for Claude Cowork
# ============================================================
# Run this ONCE to install dependencies, configure ngrok,
# and generate the Cowork plugin with a permanent URL.
#
# After setup, just double-click start-revit-mcp.bat each session.
#
# Usage: Right-click > Run with PowerShell
#        Or: powershell -ExecutionPolicy Bypass -File setup-revit-mcp.ps1
# ============================================================

$ErrorActionPreference = "Stop"

# Force TLS 1.2 — PowerShell 5.1 defaults to TLS 1.0 which GitHub/ngrok reject
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ============================================================
# Constants
# ============================================================
$SCRIPT_DIR     = Split-Path -Parent $MyInvocation.MyCommand.Path
$SERVER_DIR     = Join-Path $SCRIPT_DIR "mcp-server"
$PLUGIN_DIR     = Join-Path $SCRIPT_DIR "revit-bim"
$MCP_REPO_URL   = "https://github.com/Demolinator/revit-mcp-server.git"
$CONFIG_DIR     = Join-Path $env:APPDATA "RevitMCP"
$CONFIG_FILE    = Join-Path $CONFIG_DIR "config.json"
$DIST_DIR       = Join-Path $SCRIPT_DIR "dist"
$TOOLS_DIR      = Join-Path $SCRIPT_DIR ".tools"

# ============================================================
# Helper Functions
# ============================================================
function Write-Banner {
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host "      Revit MCP — One-Time Setup for Claude Cowork" -ForegroundColor White
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Section($text) {
    Write-Host ""
    Write-Host "  --- $text ---" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step($num, $total, $text) {
    Write-Host "  [$num/$total] " -ForegroundColor Yellow -NoNewline
    Write-Host $text
}

function Write-Ok($text) {
    Write-Host "      [OK] " -ForegroundColor Green -NoNewline
    Write-Host $text
}

function Write-Fail($text) {
    Write-Host "      [FAIL] " -ForegroundColor Red -NoNewline
    Write-Host $text
}

function Write-Warn($text) {
    Write-Host "      [WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host $text
}

function Write-Info($text) {
    Write-Host "      " -NoNewline
    Write-Host $text -ForegroundColor Gray
}

function Test-CommandExists($cmd) {
    try {
        $null = Get-Command $cmd -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Test-TcpPort($hostAddr, $port) {
    $tcp = $null
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connectTask = $tcp.ConnectAsync($hostAddr, $port)
        $completed = $connectTask.Wait(3000)  # 3 second timeout
        if ($completed -and -not $connectTask.IsFaulted) {
            return $true
        }
        return $false
    } catch {
        return $false
    } finally {
        if ($tcp) { $tcp.Dispose() }
    }
}

function Refresh-Path {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
}

function Abort($msg) {
    Write-Fail $msg
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit 1
}

# ============================================================
# Start
# ============================================================
Write-Banner

Write-Host "  This script will:" -ForegroundColor White
Write-Host "    1. Install uv (Python package manager) if needed"
Write-Host "    2. Install ngrok (secure tunnel) if needed"
Write-Host "    3. Configure your ngrok account + static domain"
Write-Host "    4. Install MCP server dependencies"
Write-Host "    5. Test Revit connectivity (optional)"
Write-Host "    6. Generate your Cowork plugin ZIP"
Write-Host ""
Write-Host "  Estimated time: 3-5 minutes" -ForegroundColor Gray
Write-Host ""

# ============================================================
# Check for existing config
# ============================================================
if (Test-Path $CONFIG_FILE) {
    try {
        $existing = Get-Content $CONFIG_FILE -Raw | ConvertFrom-Json
        Write-Warn "Existing setup found:"
        Write-Info "Domain: $($existing.ngrok_domain)"
        Write-Info "Date:   $($existing.setup_date)"
        Write-Host ""
        $choice = Read-Host "  Reconfigure from scratch? (y/N)"
        if ($choice -ne "y" -and $choice -ne "Y") {
            Write-Host ""
            Write-Host "  Setup cancelled. Your existing config is still active." -ForegroundColor Cyan
            Write-Host "  Run start-revit-mcp.bat to start a session." -ForegroundColor Cyan
            Write-Host ""
            exit 0
        }
    } catch {
        Write-Warn "Existing config is corrupted. Starting fresh."
    }
}

# Create directories
foreach ($dir in @($CONFIG_DIR, $TOOLS_DIR, $DIST_DIR)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

$TOTAL_STEPS = 6

# ============================================================
# STEP 1: Install uv
# ============================================================
Write-Step 1 $TOTAL_STEPS "Checking uv (Python package manager)..."

if (Test-CommandExists "uv") {
    $uvVer = (& uv --version 2>&1) -join ""
    Write-Ok "uv already installed ($uvVer)"
} else {
    Write-Warn "uv not found. Installing..."

    $installed = $false

    # Method 1: Official installer
    if (-not $installed) {
        try {
            Write-Info "Trying official installer..."
            $ProgressPreference = 'SilentlyContinue'
            Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
            $ProgressPreference = 'Continue'
            Refresh-Path
            if (Test-CommandExists "uv") { $installed = $true }
        } catch {
            Write-Info "Official installer failed: $($_.Exception.Message)"
        }
    }

    # Method 2: winget
    if (-not $installed -and (Test-CommandExists "winget")) {
        try {
            Write-Info "Trying winget..."
            & winget install astral-sh.uv --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
            Refresh-Path
            if (Test-CommandExists "uv") { $installed = $true }
        } catch {
            Write-Info "winget install failed"
        }
    }

    if ($installed) {
        $uvVer = (& uv --version 2>&1) -join ""
        Write-Ok "uv installed ($uvVer)"
    } else {
        Abort "Could not install uv. Please install manually: https://docs.astral.sh/uv/getting-started/installation/"
    }
}

# ============================================================
# STEP 2: Install ngrok
# ============================================================
Write-Step 2 $TOTAL_STEPS "Checking ngrok (secure tunnel)..."

if (Test-CommandExists "ngrok") {
    $ngrokVer = (& ngrok version 2>&1) -join ""
    Write-Ok "ngrok already installed ($ngrokVer)"
} else {
    Write-Warn "ngrok not found. Installing..."

    $installed = $false

    # Method 1: winget
    if (-not $installed -and (Test-CommandExists "winget")) {
        try {
            Write-Info "Trying winget..."
            & winget install ngrok.ngrok --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
            Refresh-Path
            if (Test-CommandExists "ngrok") { $installed = $true }
        } catch {
            Write-Info "winget install failed"
        }
    }

    # Method 2: chocolatey
    if (-not $installed -and (Test-CommandExists "choco")) {
        try {
            Write-Info "Trying chocolatey..."
            & choco install ngrok -y 2>&1 | Out-Null
            Refresh-Path
            if (Test-CommandExists "ngrok") { $installed = $true }
        } catch {
            Write-Info "chocolatey install failed"
        }
    }

    # Method 3: Direct download
    if (-not $installed) {
        try {
            Write-Info "Downloading ngrok directly..."
            $ngrokZip = Join-Path $env:TEMP "ngrok-download.zip"
            $ngrokInstallDir = Join-Path $TOOLS_DIR "ngrok"
            # Detect architecture
            $arch = if ([System.Environment]::Is64BitOperatingSystem) {
                if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64" -or (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue).Architecture -eq 12) { "arm64" } else { "amd64" }
            } else { "386" }
            $ngrokUrl = "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-$arch.zip"
            Write-Info "Architecture: $arch"
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $ngrokUrl -OutFile $ngrokZip -UseBasicParsing
            $ProgressPreference = 'Continue'

            if (-not (Test-Path $ngrokInstallDir)) { New-Item -ItemType Directory -Path $ngrokInstallDir -Force | Out-Null }
            Expand-Archive -Path $ngrokZip -DestinationPath $ngrokInstallDir -Force
            Remove-Item $ngrokZip -Force -ErrorAction SilentlyContinue

            # Add to user PATH permanently
            $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
            if ($userPath -notlike "*$ngrokInstallDir*") {
                [System.Environment]::SetEnvironmentVariable("PATH", "$userPath;$ngrokInstallDir", "User")
            }
            $env:PATH += ";$ngrokInstallDir"

            if (Test-CommandExists "ngrok") { $installed = $true }
        } catch {
            Write-Info "Direct download failed: $($_.Exception.Message)"
        }
    }

    if ($installed) {
        $ngrokVer = (& ngrok version 2>&1) -join ""
        Write-Ok "ngrok installed ($ngrokVer)"
    } else {
        Abort "Could not install ngrok. Please install manually: https://ngrok.com/download"
    }
}

# ============================================================
# STEP 3: Configure ngrok auth + static domain
# ============================================================
Write-Step 3 $TOTAL_STEPS "Configuring ngrok account..."

# --- Auth token ---
$authValid = $false
try {
    # Test if current auth works by calling the API
    $result = & ngrok api reserved-domains list 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and $result -notmatch "ERR_NGROK" -and $result -notmatch "authentication failed") {
        $authValid = $true
        Write-Ok "ngrok already authenticated"
    }
} catch {}

if (-not $authValid) {
    Write-Host ""
    Write-Host "      You need a free ngrok account." -ForegroundColor White
    Write-Host "      1. Go to: " -NoNewline -ForegroundColor White
    Write-Host "https://dashboard.ngrok.com/signup" -ForegroundColor Cyan
    Write-Host "      2. Sign up (free — no credit card)" -ForegroundColor White
    Write-Host "      3. Go to: " -NoNewline -ForegroundColor White
    Write-Host "https://dashboard.ngrok.com/get-started/your-authtoken" -ForegroundColor Cyan
    Write-Host "      4. Copy your auth token" -ForegroundColor White
    Write-Host ""

    # Open signup page in browser
    try { Start-Process "https://dashboard.ngrok.com/signup" } catch {}
    Start-Sleep -Seconds 1

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $token = Read-Host "  Paste your ngrok auth token (attempt $attempt/3)"
        $token = $token.Trim()

        if ([string]::IsNullOrWhiteSpace($token)) {
            Write-Fail "Token cannot be empty"
            continue
        }

        # Must look like a token (alphanumeric with underscores)
        if ($token -notmatch "^[A-Za-z0-9_\-]+$") {
            Write-Fail "Token contains invalid characters. Copy the full token from ngrok dashboard."
            continue
        }

        try {
            $addResult = & ngrok config add-authtoken $token 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) {
                Write-Fail "ngrok rejected the token: $addResult"
                continue
            }

            # Verify auth works
            $verifyResult = & ngrok api reserved-domains list 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0 -and $verifyResult -notmatch "authentication failed") {
                $authValid = $true
                Write-Ok "ngrok authenticated successfully"
                break
            } else {
                Write-Fail "Token saved but API verification failed. Is this the correct token?"
            }
        } catch {
            Write-Fail "Error configuring token: $($_.Exception.Message)"
        }
    }

    if (-not $authValid) {
        Abort "Could not authenticate ngrok after 3 attempts. Verify your account at https://dashboard.ngrok.com"
    }
}

# --- Static domain ---
Write-Section "Static Domain"

$ngrokDomain = $null

# Check for existing domain
try {
    $domainJson = & ngrok api reserved-domains list 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        $domainData = $domainJson | ConvertFrom-Json
        if ($domainData.reserved_domains -and $domainData.reserved_domains.Count -gt 0) {
            $existingDomain = $domainData.reserved_domains[0].domain
            Write-Ok "Found your existing ngrok domain: $existingDomain"
            $useit = Read-Host "  Use this domain? (Y/n)"
            if ($useit -ne "n" -and $useit -ne "N") {
                $ngrokDomain = $existingDomain
            }
        }
    }
} catch {
    Write-Info "Could not auto-detect domains, will ask for input."
}

if (-not $ngrokDomain) {
    Write-Host ""
    Write-Host "      You get 1 free permanent domain from ngrok." -ForegroundColor White
    Write-Host "      1. Go to: " -NoNewline -ForegroundColor White
    Write-Host "https://dashboard.ngrok.com/domains" -ForegroundColor Cyan
    Write-Host "      2. Click 'New Domain' (free — you get 1)" -ForegroundColor White
    Write-Host "      3. Copy the domain name" -ForegroundColor White
    Write-Host "         (looks like: " -NoNewline -ForegroundColor White
    Write-Host "something-random.ngrok-free.app" -ForegroundColor Yellow -NoNewline
    Write-Host ")" -ForegroundColor White
    Write-Host ""

    try { Start-Process "https://dashboard.ngrok.com/domains" } catch {}
    Start-Sleep -Seconds 1

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $domainInput = Read-Host "  Paste your ngrok static domain (attempt $attempt/3)"
        $domainInput = $domainInput.Trim()

        if ([string]::IsNullOrWhiteSpace($domainInput)) {
            Write-Fail "Domain cannot be empty"
            continue
        }

        # Clean up common mistakes
        $domainInput = $domainInput -replace "^https?://", ""    # Remove protocol prefix
        $domainInput = $domainInput -replace "/.*$", ""           # Remove path suffix
        $domainInput = $domainInput.ToLower()

        # Validate format
        if ($domainInput -match "^[a-z0-9][a-z0-9\-]*\.(ngrok-free\.app|ngrok\.app|ngrok\.io)$") {
            $ngrokDomain = $domainInput
            Write-Ok "Domain set: $ngrokDomain"
            break
        } else {
            Write-Fail "Invalid format. Expected: something.ngrok-free.app"
            Write-Info "You entered: $domainInput"
            Write-Info "Get your domain at: https://dashboard.ngrok.com/domains"
        }
    }

    if (-not $ngrokDomain) {
        Abort "Could not set ngrok domain after 3 attempts."
    }
}

# Quick validation: try to use the domain (start+stop ngrok)
Write-Info "Validating domain ownership..."
try {
    $testProc = Start-Process -FilePath "ngrok" `
        -ArgumentList "http", "--domain=$ngrokDomain", "8000", "--log=stdout" `
        -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $env:TEMP "ngrok-test.log") `
        -RedirectStandardError (Join-Path $env:TEMP "ngrok-test-err.log")

    Start-Sleep -Seconds 5

    if ($testProc.HasExited) {
        $errLog = Get-Content (Join-Path $env:TEMP "ngrok-test-err.log") -Raw -ErrorAction SilentlyContinue
        $outLog = Get-Content (Join-Path $env:TEMP "ngrok-test.log") -Raw -ErrorAction SilentlyContinue
        $combined = "$errLog $outLog".Trim()
        if ([string]::IsNullOrEmpty($combined)) { $combined = "(no output)" }

        if ($combined -match "is not bound to your account") {
            Abort "Domain '$ngrokDomain' does not belong to your ngrok account. Check https://dashboard.ngrok.com/domains"
        } elseif ($combined -match "ERR_NGROK") {
            Write-Warn "Domain validation returned an error (may still work): $($combined.Substring(0, [Math]::Min(200, $combined.Length)))"
        } else {
            Write-Warn "ngrok exited unexpectedly during validation. Continuing anyway..."
        }
    } else {
        # ngrok is running — domain is valid
        Stop-Process -Id $testProc.Id -Force -ErrorAction SilentlyContinue
        Write-Ok "Domain validated: https://$ngrokDomain"
    }
} catch {
    Write-Warn "Could not validate domain: $($_.Exception.Message). Continuing..."
} finally {
    # Cleanup any test ngrok process
    Get-Process -Name "ngrok" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $env:TEMP "ngrok-test.log") -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $env:TEMP "ngrok-test-err.log") -Force -ErrorAction SilentlyContinue
}

# ============================================================
# STEP 4: Install MCP server dependencies
# ============================================================
Write-Step 4 $TOTAL_STEPS "Installing MCP server dependencies..."

if (-not (Test-Path (Join-Path $SERVER_DIR "main.py"))) {
    Write-Info "MCP server not found locally. Downloading..."

    # Clean up any partial download from a previous failed attempt
    if (Test-Path $SERVER_DIR) {
        Write-Info "Removing incomplete previous download..."
        Remove-Item $SERVER_DIR -Recurse -Force -ErrorAction SilentlyContinue
    }

    $downloaded = $false

    # Method 1: Try git clone (fast, if git is installed)
    if (-not $downloaded -and (Test-CommandExists "git")) {
        try {
            $tempClone = Join-Path $env:TEMP "revit-mcp-clone-$(Get-Random)"
            Write-Info "Downloading via git clone..."
            & git clone --depth 1 $MCP_REPO_URL $tempClone 2>&1 | Out-Null

            if ($LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $tempClone "main.py"))) {
                Copy-Item -Recurse -Force $tempClone $SERVER_DIR
                Remove-Item -Recurse -Force $tempClone -ErrorAction SilentlyContinue
                Write-Ok "MCP server downloaded via git"
                $downloaded = $true
            } else {
                Remove-Item -Recurse -Force $tempClone -ErrorAction SilentlyContinue
                Write-Info "git clone failed, trying ZIP download..."
            }
        } catch {
            Write-Info "git clone error: $($_.Exception.Message). Trying ZIP download..."
        }
    }

    # Method 2: Download ZIP from GitHub (no git required)
    if (-not $downloaded) {
        try {
            $zipUrl = "https://github.com/Demolinator/revit-mcp-server/archive/refs/heads/master.zip"
            $tempZip = Join-Path $env:TEMP "revit-mcp-server-$(Get-Random).zip"
            $tempExtract = Join-Path $env:TEMP "revit-mcp-extract-$(Get-Random)"

            Write-Info "Downloading ZIP from GitHub..."
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing
            $ProgressPreference = 'Continue'

            Write-Info "Extracting..."
            Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

            # GitHub ZIPs extract to a subfolder named repo-branch
            $extractedDir = Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1
            if ($extractedDir -and (Test-Path (Join-Path $extractedDir.FullName "main.py"))) {
                Copy-Item -Recurse -Force $extractedDir.FullName $SERVER_DIR
                Write-Ok "MCP server downloaded via ZIP"
                $downloaded = $true
            } else {
                Write-Fail "ZIP extraction did not produce expected files"
            }

            Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
            Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Info "ZIP download failed: $($_.Exception.Message)"
        }
    }

    if (-not $downloaded) {
        Abort "Could not download MCP server. Check your internet connection and try again."
    }
}

try {
    Push-Location $SERVER_DIR
    $syncOut = & uv sync 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
        Pop-Location -ErrorAction SilentlyContinue
        Write-Fail "uv sync failed:"
        Write-Info $syncOut
        Abort "Dependency installation failed. Check your internet connection."
    }

    Pop-Location
    Write-Ok "MCP server dependencies installed"
} catch {
    Pop-Location -ErrorAction SilentlyContinue
    Abort "Failed to install dependencies: $($_.Exception.Message)"
}

# ============================================================
# STEP 5: Test Revit connectivity
# ============================================================
Write-Step 5 $TOTAL_STEPS "Testing Revit connectivity..."

$revitOk = $false
if (Test-TcpPort "127.0.0.1" 48884) {
    try {
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:48884/revit_mcp/status/" -Method GET -TimeoutSec 5
        if ($resp.health -eq "healthy") {
            Write-Ok "Revit is running: $($resp.document_title)"
            $revitOk = $true
        } else {
            Write-Warn "Revit responded but health is: $($resp.health)"
        }
    } catch {
        Write-Warn "Port 48884 open but Revit API not responding"
    }
} else {
    Write-Warn "Revit not detected on port 48884"
}

if (-not $revitOk) {
    Write-Host ""
    Write-Host "      Revit is not required during setup." -ForegroundColor Gray
    Write-Host "      Make sure it's running before you use start-revit-mcp.bat" -ForegroundColor Gray
    Write-Host "      Requirements: Revit (2024/2025/2026) open + pyRevit loaded + project open" -ForegroundColor Gray
    Write-Host ""
}

# ============================================================
# STEP 6: Generate plugin ZIP
# ============================================================
Write-Step 6 $TOTAL_STEPS "Generating Cowork plugin with permanent URL..."

if (-not (Test-Path (Join-Path (Join-Path $PLUGIN_DIR ".claude-plugin") "plugin.json"))) {
    Abort "Plugin template not found at: $PLUGIN_DIR"
}

# Create a temp copy of the plugin
$tempDir = Join-Path $env:TEMP "revit-mcp-plugin-build-$(Get-Random)"
try {
    # Copy plugin template
    Copy-Item -Path $PLUGIN_DIR -Destination $tempDir -Recurse -Force

    # Remove the server/ directory if it exists (not needed for HTTP transport)
    $serverSubDir = Join-Path $tempDir "server"
    if (Test-Path $serverSubDir) {
        Remove-Item $serverSubDir -Recurse -Force
    }

    # Write .mcp.json with permanent ngrok URL
    $mcpConfig = @{
        mcpServers = @{
            revit = @{
                type = "http"
                url  = "https://$ngrokDomain/mcp"
            }
        }
    }
    $mcpConfig | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $tempDir ".mcp.json") -Encoding UTF8

    # Update CONNECTORS.md
    $connectorsContent = @"
# Connectors

## ~~revit

The Revit MCP Server connects Claude to Autodesk Revit 2024/2025/2026 via the Model Context Protocol. It provides 45 tools for building design, model editing, structural systems, MEP, documentation, and analysis.

**Connection**: Uses a permanent ngrok tunnel. Run ``start-revit-mcp.bat`` on your machine before using Cowork.

**Your tunnel URL**: https://$ngrokDomain/mcp

## Connection Flow

``````
Claude Cowork --> https://$ngrokDomain/mcp --> ngrok tunnel --> MCP Server (localhost:8000) --> pyRevit Routes (:48884) --> Revit API
``````

## Prerequisites

- **Autodesk Revit 2024/2025/2026** installed and running with a project open
- **pyRevit** installed (provides Routes on port 48884)
- **start-revit-mcp.bat** running (starts MCP server + tunnel)

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| "Failed to connect to Revit" | start script not running | Run ``start-revit-mcp.bat`` |
| "No active Revit document" | Revit not open | Open Revit with a project |
| "Connection refused on 48884" | pyRevit not loaded | Check pyRevit tab in Revit |
| Tools return errors | Invalid type names | Call ``list_families`` first |
"@
    $connectorsContent | Set-Content (Join-Path $tempDir "CONNECTORS.md") -Encoding UTF8

    # Create ZIP
    $zipPath = Join-Path $DIST_DIR "revit-architect-plugin.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $zipPath)

    if (Test-Path $zipPath) {
        $zipSize = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
        Write-Ok "Plugin ZIP created: $zipPath ($zipSize KB)"
    } else {
        Abort "ZIP file was not created"
    }
} catch {
    Abort "Failed to generate plugin: $($_.Exception.Message)"
} finally {
    # Cleanup temp directory
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# Save config
# ============================================================
$config = @{
    ngrok_domain   = $ngrokDomain
    mcp_server_dir = $SERVER_DIR
    repo_dir       = $SCRIPT_DIR
    mcp_port       = 8000
    revit_port     = 48884
    plugin_zip     = $zipPath
    setup_date     = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    setup_version  = "1.1.0"
}
$config | ConvertTo-Json -Depth 3 | Set-Content $CONFIG_FILE -Encoding UTF8
Write-Ok "Configuration saved"

# ============================================================
# Done!
# ============================================================
Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host "      SETUP COMPLETE!" -ForegroundColor White
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "      Your permanent URL: " -NoNewline -ForegroundColor White
Write-Host "https://$ngrokDomain/mcp" -ForegroundColor Yellow
Write-Host ""
Write-Host "      Next steps:" -ForegroundColor White
Write-Host ""
Write-Host "      1. Upload the plugin to Cowork (one time only):" -ForegroundColor White
Write-Host "         File: " -NoNewline; Write-Host $zipPath -ForegroundColor Yellow
Write-Host "         Go to: Cowork > Plugins > Upload Plugin" -ForegroundColor Gray
Write-Host ""
Write-Host "      2. Before each Cowork session, double-click:" -ForegroundColor White
Write-Host "         " -NoNewline; Write-Host "start-revit-mcp.bat" -ForegroundColor Yellow
Write-Host ""
Write-Host "      That's it! The URL never changes." -ForegroundColor Cyan
Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host ""

# Open dist folder so user can find the ZIP
try { Start-Process "explorer.exe" $DIST_DIR } catch {}

Read-Host "  Press Enter to exit"
