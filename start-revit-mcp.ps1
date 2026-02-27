# ============================================================
# Revit MCP - Per-Session Startup for Claude Cowork
# ============================================================
# Double-click start-revit-mcp.bat (or run this) before each
# Cowork session. It starts the MCP server + ngrok tunnel.
#
# Prerequisites: Run setup-revit-mcp.ps1 first (one-time).
#
# Usage: Right-click > Run with PowerShell
#        Or: powershell -ExecutionPolicy Bypass -File start-revit-mcp.ps1
# ============================================================

$ErrorActionPreference = "Stop"

# Force TLS 1.2 - PowerShell 5.1 defaults to TLS 1.0 which GitHub/ngrok reject
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ============================================================
# Constants
# ============================================================
$SCRIPT_DIR   = Split-Path -Parent $MyInvocation.MyCommand.Path
$CONFIG_DIR   = Join-Path $env:APPDATA "RevitMCP"
$CONFIG_FILE  = Join-Path $CONFIG_DIR "config.json"
$LOG_DIR      = $CONFIG_DIR

# Process tracking
$script:mcpProcess   = $null
$script:ngrokProcess = $null

# ============================================================
# Helper Functions
# ============================================================
function Write-Banner {
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host "      Revit MCP - Starting Session" -ForegroundColor White
    Write-Host "  ============================================================" -ForegroundColor Cyan
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

function Stop-AllProcesses {
    Write-Host ""
    Write-Host "  Shutting down..." -ForegroundColor Yellow

    if ($script:ngrokProcess -and -not $script:ngrokProcess.HasExited) {
        try {
            Stop-Process -Id $script:ngrokProcess.Id -Force -ErrorAction Stop
            Write-Info "ngrok stopped (PID $($script:ngrokProcess.Id))"
        } catch {
            Write-Info "ngrok already stopped"
        }
    }

    if ($script:mcpProcess -and -not $script:mcpProcess.HasExited) {
        try {
            Stop-Process -Id $script:mcpProcess.Id -Force -ErrorAction Stop
            Write-Info "MCP server stopped (PID $($script:mcpProcess.Id))"
        } catch {
            Write-Info "MCP server already stopped"
        }
    }

    # Also kill any orphaned ngrok processes from previous sessions
    Get-Process -Name "ngrok" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "  Goodbye!" -ForegroundColor Cyan
    Write-Host ""
}

function Abort($msg) {
    Write-Fail $msg
    Stop-AllProcesses
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit 1
}

# ============================================================
# Start
# ============================================================
Write-Banner

$TOTAL_STEPS = 6

# ============================================================
# STEP 1: Load and validate configuration
# ============================================================
Write-Step 1 $TOTAL_STEPS "Loading configuration..."

if (-not (Test-Path $CONFIG_FILE)) {
    Write-Fail "No configuration found."
    Write-Host ""
    Write-Host "      Run setup first:" -ForegroundColor White
    Write-Host "        powershell -ExecutionPolicy Bypass -File setup-revit-mcp.ps1" -ForegroundColor Yellow
    Write-Host "        Or double-click: setup-revit-mcp.bat" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit 1
}

try {
    $config = Get-Content $CONFIG_FILE -Raw | ConvertFrom-Json
} catch {
    Abort "Configuration file is corrupted. Delete $CONFIG_FILE and run setup-revit-mcp.bat again."
}

# Validate required fields
$requiredFields = @("ngrok_domain", "mcp_server_dir", "mcp_port", "revit_port")
foreach ($field in $requiredFields) {
    $val = $config.PSObject.Properties[$field]
    if (-not $val -or [string]::IsNullOrWhiteSpace("$($val.Value)")) {
        Abort "Config missing required field '$field'. Run setup-revit-mcp.bat again."
    }
}

$NGROK_DOMAIN  = $config.ngrok_domain
$SERVER_DIR    = $config.mcp_server_dir
$MCP_PORT      = [int]$config.mcp_port
$REVIT_PORT    = [int]$config.revit_port

# If saved server dir doesn't exist, try resolving from current script location
if (-not (Test-Path $SERVER_DIR)) {
    $fallbackDir = Join-Path $SCRIPT_DIR "mcp-server"
    if (Test-Path $fallbackDir) {
        Write-Warn "Saved server path not found. Using: $fallbackDir"
        $SERVER_DIR = $fallbackDir
    }
}

Write-Ok "Config loaded"
Write-Info "Domain:     https://$NGROK_DOMAIN"
Write-Info "MCP port:   $MCP_PORT"
Write-Info "Revit port: $REVIT_PORT"

# ============================================================
# STEP 2: Check prerequisites
# ============================================================
Write-Step 2 $TOTAL_STEPS "Checking prerequisites..."

# Check uv
if (-not (Test-CommandExists "uv")) {
    Abort "uv not found. Run setup-revit-mcp.bat to install it."
}
Write-Ok "uv found"

# Check ngrok
if (-not (Test-CommandExists "ngrok")) {
    Abort "ngrok not found. Run setup-revit-mcp.bat to install it."
}
Write-Ok "ngrok found"

# Fix ngrok config version if needed (v3.3.x only supports version 1 or 2)
$ngrokConfigPaths = @(
    (Join-Path $env:LOCALAPPDATA "ngrok\ngrok.yml"),
    (Join-Path $env:USERPROFILE ".ngrok2\ngrok.yml")
)
foreach ($cfgPath in $ngrokConfigPaths) {
    if (Test-Path $cfgPath) {
        $cfgContent = Get-Content $cfgPath -Raw -ErrorAction SilentlyContinue
        if ($cfgContent -match 'version:\s*"?3"?') {
            Write-Info "Fixing ngrok config version (3 -> 2)..."
            $cfgContent = $cfgContent -replace 'version:\s*"?3"?', 'version: "2"'
            [System.IO.File]::WriteAllText($cfgPath, $cfgContent)
            Write-Ok "ngrok config version fixed"
        }
        break
    }
}

# Check MCP server directory
if (-not (Test-Path (Join-Path $SERVER_DIR "main.py"))) {
    Abort "MCP server not found at: $SERVER_DIR`n      Has the installation been moved or deleted?"
}
Write-Ok "MCP server found at $SERVER_DIR"

# ============================================================
# STEP 3: Check Revit
# ============================================================
Write-Step 3 $TOTAL_STEPS "Checking Revit connection..."

$revitReady = $false
$revitAttempts = 3

for ($i = 1; $i -le $revitAttempts; $i++) {
    if (Test-TcpPort "127.0.0.1" $REVIT_PORT) {
        try {
            $resp = Invoke-RestMethod -Uri "http://127.0.0.1:${REVIT_PORT}/revit_mcp/status/" -Method GET -TimeoutSec 5
            if ($resp.health -eq "healthy") {
                Write-Ok "Revit is running: $($resp.document_title)"
                $revitReady = $true
                break
            } else {
                Write-Warn "Revit responded but health=$($resp.health)"
            }
        } catch {
            Write-Warn "Port $REVIT_PORT open but API not responding (attempt $i/$revitAttempts)"
        }
    } else {
        if ($i -lt $revitAttempts) {
            Write-Warn "Revit not detected on port $REVIT_PORT (attempt $i/$revitAttempts, retrying...)"
            Start-Sleep -Seconds 3
        }
    }
}

if (-not $revitReady) {
    Write-Host ""
    Write-Host "      Revit is not responding on port $REVIT_PORT." -ForegroundColor Red
    Write-Host ""
    Write-Host "      Please ensure:" -ForegroundColor Yellow
    Write-Host "        1. Autodesk Revit (2024, 2025, or 2026) is open" -ForegroundColor White
    Write-Host "        2. A project file is open in Revit" -ForegroundColor White
    Write-Host "        3. pyRevit is installed and loaded" -ForegroundColor White
    Write-Host "           (look for the pyRevit tab in Revit's ribbon)" -ForegroundColor Gray
    Write-Host ""

    $continue = Read-Host "  Continue anyway and retry later? (y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Host ""
        Write-Host "  Start Revit first, then run this script again." -ForegroundColor Cyan
        Write-Host ""
        Read-Host "  Press Enter to exit"
        exit 0
    }
}

# ============================================================
# STEP 4: Start MCP server
# ============================================================
Write-Step 4 $TOTAL_STEPS "Starting MCP server on port $MCP_PORT..."

# Check if port is already in use
if (Test-TcpPort "127.0.0.1" $MCP_PORT) {
    Write-Warn "Port $MCP_PORT is already in use"

    $existingPid = $null
    $existingName = "unknown"
    try {
        $conn = Get-NetTCPConnection -LocalPort $MCP_PORT -ErrorAction Stop | Select-Object -First 1
        if ($conn) {
            $existingPid = $conn.OwningProcess
            $proc = Get-Process -Id $existingPid -ErrorAction Stop
            $existingName = $proc.ProcessName
        }
    } catch {}

    if ($existingPid) {
        Write-Info "Process: $existingName (PID: $existingPid)"

        # If it's a previous MCP server (python), offer to kill it
        if ($existingName -match "python|uv") {
            $kill = Read-Host "      Stop previous MCP server? (Y/n)"
            if ($kill -ne "n" -and $kill -ne "N") {
                try {
                    Stop-Process -Id $existingPid -Force
                    Start-Sleep -Seconds 2

                    if (Test-TcpPort "127.0.0.1" $MCP_PORT) {
                        Abort "Port $MCP_PORT still in use after stopping process"
                    }
                    Write-Ok "Previous server stopped"
                } catch {
                    Abort "Could not stop process $existingPid : $($_.Exception.Message)"
                }
            } else {
                Abort "Cannot start - port $MCP_PORT is in use by $existingName (PID $existingPid)"
            }
        } else {
            Abort "Port $MCP_PORT is in use by $existingName (PID $existingPid). Stop that process and try again."
        }
    } else {
        Write-Info "Could not identify the process using port $MCP_PORT."
        Write-Info "Try closing other applications or wait a few seconds and retry."
        Abort "Port $MCP_PORT is in use. Free the port and run this script again."
    }
}

# Start the server
$mcpLogFile = Join-Path $LOG_DIR "mcp-server.log"
$mcpErrFile = Join-Path $LOG_DIR "mcp-server-err.log"

# Clear old logs
"" | Set-Content $mcpLogFile -ErrorAction SilentlyContinue
"" | Set-Content $mcpErrFile -ErrorAction SilentlyContinue

try {
    $script:mcpProcess = Start-Process -FilePath "uv" `
        -ArgumentList "run", "main.py", "--streamable-http" `
        -WorkingDirectory $SERVER_DIR `
        -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput $mcpLogFile `
        -RedirectStandardError $mcpErrFile
} catch {
    Abort "Failed to start MCP server: $($_.Exception.Message)"
}

# Wait for server to be ready (up to 20 seconds)
$serverReady = $false
for ($i = 1; $i -le 20; $i++) {
    Start-Sleep -Seconds 1

    # Check if process crashed
    if ($script:mcpProcess.HasExited) {
        $exitCode = $script:mcpProcess.ExitCode
        $errContent = Get-Content $mcpErrFile -Raw -ErrorAction SilentlyContinue
        if (-not $errContent) { $errContent = "(no error output)" }

        if ($errContent -match "ModuleNotFoundError|ImportError") {
            Abort "MCP server missing dependencies. Run setup-revit-mcp.bat again.`n      Error: $errContent"
        } elseif ($errContent -match "Address already in use") {
            Abort "Port $MCP_PORT is still in use. Wait a few seconds and try again."
        } else {
            $snippet = if ($errContent.Length -gt 300) { $errContent.Substring(0, 300) + "..." } else { $errContent }
            Abort "MCP server exited with code $exitCode`n      Error: $snippet`n      Full log: $mcpErrFile"
        }
    }

    # Check if port is open
    if (Test-TcpPort "127.0.0.1" $MCP_PORT) {
        $serverReady = $true
        break
    }
}

if ($serverReady) {
    Write-Ok "MCP server running on port $MCP_PORT (PID: $($script:mcpProcess.Id))"
} else {
    Abort "MCP server did not start within 20 seconds.`n      Check log: $mcpErrFile"
}

# ============================================================
# STEP 5: Start ngrok tunnel
# ============================================================
Write-Step 5 $TOTAL_STEPS "Starting ngrok tunnel..."

# Kill any orphaned ngrok processes
Get-Process -Name "ngrok" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

$ngrokLogFile = Join-Path $LOG_DIR "ngrok.log"
"" | Set-Content $ngrokLogFile -ErrorAction SilentlyContinue

try {
    $ngrokErrFile = Join-Path $LOG_DIR "ngrok-err.log"
    $ngrokBat = Join-Path $LOG_DIR "run-ngrok.bat"
    $batContent = "@echo off`r`nngrok http $MCP_PORT --domain $NGROK_DOMAIN"
    [System.IO.File]::WriteAllText($ngrokBat, $batContent, [System.Text.Encoding]::ASCII)
    Write-Info "Debug: ngrok http $MCP_PORT --domain $NGROK_DOMAIN"
    $script:ngrokProcess = Start-Process -FilePath "cmd.exe" `
        -ArgumentList "/c `"$ngrokBat`"" `
        -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput $ngrokLogFile `
        -RedirectStandardError $ngrokErrFile
} catch {
    Abort "Failed to start ngrok: $($_.Exception.Message)"
}

# Wait for tunnel to be ready (check via ngrok local API on port 4040)
$tunnelReady = $false
for ($i = 1; $i -le 15; $i++) {
    Start-Sleep -Seconds 2

    # Check if ngrok crashed
    if ($script:ngrokProcess.HasExited) {
        $logContent = Get-Content $ngrokLogFile -Raw -ErrorAction SilentlyContinue
        $errContent = Get-Content $ngrokErrFile -Raw -ErrorAction SilentlyContinue
        if ($errContent) { $logContent = "$logContent`n$errContent" }
        if (-not $logContent) { $logContent = "(no log output)" }

        if ($logContent -match "is not bound to your account") {
            Abort "Domain '$NGROK_DOMAIN' is not bound to your ngrok account.`n      Fix: Go to https://dashboard.ngrok.com/domains and verify your domain."
        } elseif ($logContent -match "authentication failed") {
            Abort "ngrok authentication failed. Your token may have expired.`n      Fix: Run setup-revit-mcp.bat again to reconfigure."
        } elseif ($logContent -match "tunnel session limit") {
            Abort "ngrok session limit reached. Close other ngrok tunnels first.`n      Fix: Check https://dashboard.ngrok.com/tunnels for active sessions."
        } elseif ($logContent -match "ERR_NGROK_108") {
            Abort "Your ngrok account has too many active sessions.`n      Fix: Close other ngrok tunnels or upgrade your account."
        } else {
            $snippet = if ($logContent.Length -gt 400) { $logContent.Substring(0, 400) + "..." } else { $logContent }
            Abort "ngrok exited unexpectedly.`n      Log: $snippet`n      Full log: $ngrokLogFile"
        }
    }

    # Check ngrok API for tunnel status
    try {
        $tunnelInfo = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 3
        if ($tunnelInfo.tunnels.Count -gt 0) {
            $tunnelUrl = $tunnelInfo.tunnels[0].public_url
            Write-Ok "Tunnel active: $tunnelUrl"
            $tunnelReady = $true
            break
        }
    } catch {
        # ngrok API not ready yet, keep waiting
    }
}

if (-not $tunnelReady) {
    Abort "ngrok tunnel did not start within 30 seconds.`n      Check log: $ngrokLogFile"
}

# ============================================================
# STEP 6: Verify end-to-end
# ============================================================
Write-Step 6 $TOTAL_STEPS "Verifying end-to-end connection..."

$e2eOk = $false
for ($i = 1; $i -le 3; $i++) {
    try {
        $headers = @{
            "Content-Type"                 = "application/json"
            "Accept"                       = "application/json, text/event-stream"
            "ngrok-skip-browser-warning"   = "true"
        }
        $body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"health-check","version":"1.0"}}}'

        $response = Invoke-RestMethod -Uri "https://$NGROK_DOMAIN/mcp/" `
            -Method POST -Headers $headers -Body $body -TimeoutSec 15

        if ($response.result.serverInfo.name) {
            Write-Ok "MCP handshake successful!"
            Write-Ok "Server: $($response.result.serverInfo.name) v$($response.result.serverInfo.version)"
            $e2eOk = $true
            break
        }
    } catch {
        if ($i -lt 3) {
            Write-Warn "Handshake attempt $i failed, retrying..."
            Start-Sleep -Seconds 3
        }
    }
}

if (-not $e2eOk) {
    Write-Warn "End-to-end verification failed. The tunnel may need a few more seconds."
    Write-Info "Try using Cowork anyway - it may work once the tunnel fully connects."
}

# Quick Revit tool test (if Revit was available)
if ($revitReady -and $e2eOk) {
    try {
        $headers = @{
            "Content-Type"                 = "application/json"
            "Accept"                       = "application/json, text/event-stream"
            "ngrok-skip-browser-warning"   = "true"
        }
        $body = '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_revit_status","arguments":{}}}'
        $toolResp = Invoke-RestMethod -Uri "https://$NGROK_DOMAIN/mcp/" `
            -Method POST -Headers $headers -Body $body -TimeoutSec 15

        if ($toolResp.result.content[0].text -match "healthy") {
            Write-Ok "Revit tool test PASSED - full pipeline working!"
        } else {
            Write-Warn "Revit tool returned unexpected response"
        }
    } catch {
        Write-Warn "Revit tool test failed: $($_.Exception.Message)"
    }
}

# ============================================================
# Ready!
# ============================================================
Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host "      READY! Open Claude Cowork and start designing!" -ForegroundColor White
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "      Tunnel: " -NoNewline -ForegroundColor Gray
Write-Host "https://$NGROK_DOMAIN/mcp" -ForegroundColor Green
Write-Host ""
Write-Host "      Press Ctrl+C to stop." -ForegroundColor Gray
Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Green
Write-Host ""

# ============================================================
# Monitor loop - keep alive until Ctrl+C
# ============================================================
$healthCheckInterval = 30  # seconds
$lastHealthCheck = [DateTime]::Now

try {
    while ($true) {
        Start-Sleep -Seconds 5

        # Check MCP server
        if ($script:mcpProcess.HasExited) {
            Write-Host ""
            Write-Fail "MCP server stopped unexpectedly!"
            $errContent = Get-Content (Join-Path $LOG_DIR "mcp-server-err.log") -Raw -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrEmpty($errContent)) {
                $snippet = if ($errContent.Length -gt 200) { $errContent.Substring(0, 200) + "..." } else { $errContent }
                Write-Info "Last error: $snippet"
            }
            Write-Info "Attempting restart..."

            # Try to restart
            try {
                $script:mcpProcess = Start-Process -FilePath "uv" `
                    -ArgumentList "run", "main.py", "--streamable-http" `
                    -WorkingDirectory $SERVER_DIR `
                    -PassThru -WindowStyle Hidden `
                    -RedirectStandardOutput (Join-Path $LOG_DIR "mcp-server.log") `
                    -RedirectStandardError (Join-Path $LOG_DIR "mcp-server-err.log")

                Start-Sleep -Seconds 5

                if ($script:mcpProcess.HasExited) {
                    Abort "MCP server keeps crashing. Check the error log: $(Join-Path $LOG_DIR 'mcp-server-err.log')"
                }

                if (Test-TcpPort "127.0.0.1" $MCP_PORT) {
                    Write-Ok "MCP server restarted (PID: $($script:mcpProcess.Id))"
                } else {
                    Abort "MCP server restarted but not listening on port $MCP_PORT"
                }
            } catch {
                Abort "Failed to restart MCP server: $($_.Exception.Message)"
            }
        }

        # Check ngrok
        if ($script:ngrokProcess.HasExited) {
            Write-Host ""
            Write-Fail "ngrok tunnel stopped unexpectedly!"
            $logContent = Get-Content (Join-Path $LOG_DIR "ngrok.log") -Raw -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrEmpty($logContent)) {
                $snippet = if ($logContent.Length -gt 200) { $logContent.Substring(0, 200) + "..." } else { $logContent }
                Write-Info "Last log: $snippet"
            }
            Write-Info "Attempting restart..."

            # Try to restart
            try {
                $ngrokBat = Join-Path $LOG_DIR "run-ngrok.bat"
                "@echo off`nngrok http $MCP_PORT --domain $NGROK_DOMAIN" | Set-Content $ngrokBat -Encoding ASCII
                $script:ngrokProcess = Start-Process -FilePath "cmd.exe" `
                    -ArgumentList "/c", $ngrokBat `
                    -PassThru -WindowStyle Hidden `
                    -RedirectStandardOutput (Join-Path $LOG_DIR "ngrok.log") `
                    -RedirectStandardError (Join-Path $LOG_DIR "ngrok-err.log")

                Start-Sleep -Seconds 5

                if ($script:ngrokProcess.HasExited) {
                    Abort "ngrok keeps crashing. Check: $(Join-Path $LOG_DIR 'ngrok.log')"
                }

                # Check tunnel is active
                try {
                    $tunnelInfo = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 5
                    if ($tunnelInfo.tunnels.Count -gt 0) {
                        Write-Ok "ngrok tunnel restarted"
                    }
                } catch {
                    Write-Warn "ngrok restarted but tunnel status unclear"
                }
            } catch {
                Abort "Failed to restart ngrok: $($_.Exception.Message)"
            }
        }

        # Periodic health check
        if (([DateTime]::Now - $lastHealthCheck).TotalSeconds -ge $healthCheckInterval) {
            $lastHealthCheck = [DateTime]::Now

            # Quick port check
            if (-not (Test-TcpPort "127.0.0.1" $MCP_PORT)) {
                Write-Warn "MCP server not responding on port $MCP_PORT - may need restart"
            }
        }
    }
} finally {
    Stop-AllProcesses
}
