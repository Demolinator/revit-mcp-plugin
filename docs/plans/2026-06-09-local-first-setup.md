# Local-First Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the ngrok-required Cowork setup with a one-time, local-first setup that auto-wires the Revit MCP server into Claude Desktop over stdio (no tunnel), auto-enables pyRevit Routes, supports any MCP client, and keeps ngrok as an optional web/mobile path.

**Architecture:** PowerShell setup orchestrator (`setup-revit-mcp.ps1`) dot-sources small, single-responsibility helper functions in `lib/`. Each helper is independently tested by a PowerShell assertion script in `tests/`. Server-side: trim cold-start and fix one response-formatting bug in `revit-mcp-server`. All validated live against Revit 2027 + the proven MCP stdio client.

**Tech Stack:** Windows PowerShell 5.1, Python 3.11 (uv venv), FastMCP, pyRevit Routes (:48884), Claude Desktop (MSIX) `claude_desktop_config.json`.

**Test tooling:** No external deps. Tests are `.ps1` scripts that dot-source a helper and `throw` on failure (exit 1) or print `PASS`. Run with `powershell -ExecutionPolicy Bypass -File <test>`. Live server tests reuse the verified Python MCP stdio client pattern.

**Repos / branches:** Work on branch `local-first-setup` in BOTH `revit-mcp-server` and `revit-mcp-plugin`.

**Key facts (proven 2026-06-09):**
- Server already defaults to stdio (`revit-mcp-server/main.py:126`); no transport code change needed.
- This machine's config path (MSIX): `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json`.
- Launch command that works from any cwd: `<server>\.venv\Scripts\python.exe <server>\main.py`.
- Desktop logs each MCP load to `logs\mcp-server-revit.log` (`Server started and connected successfully`).

---

### Task 0: Branches + scaffolding

**Files:**
- Create: `revit-mcp-plugin/lib/.gitkeep`, `revit-mcp-plugin/tests/_assert.ps1`

- [ ] **Step 1: Create feature branches**

```powershell
git -C "C:\Users\revitadmin\Documents\Claude Code\revit-mcp-server" checkout -b local-first-setup
git -C "C:\Users\revitadmin\Documents\Claude Code\revit-mcp-plugin" checkout -b local-first-setup
```
Expected: `Switched to a new branch 'local-first-setup'` for each.

- [ ] **Step 2: Create the test assertion helper**

Create `revit-mcp-plugin/tests/_assert.ps1`:
```powershell
# Minimal assertion helper for setup tests. Dot-source it, then use Assert/AssertEq.
$script:Failures = 0
function Assert($cond, $msg) {
  if ($cond) { Write-Host "  [PASS] $msg" -ForegroundColor Green }
  else { Write-Host "  [FAIL] $msg" -ForegroundColor Red; $script:Failures++ }
}
function AssertEq($actual, $expected, $msg) {
  Assert ($actual -eq $expected) "$msg (expected '$expected', got '$actual')"
}
function EndTests {
  if ($script:Failures -gt 0) { Write-Host "FAILED: $script:Failures" -ForegroundColor Red; exit 1 }
  Write-Host "ALL PASSED" -ForegroundColor Green; exit 0
}
```

- [ ] **Step 3: Commit**

```powershell
git -C "C:\Users\revitadmin\Documents\Claude Code\revit-mcp-plugin" add tests/_assert.ps1
git -C "C:\Users\revitadmin\Documents\Claude Code\revit-mcp-plugin" commit -m "test: add assertion helper for setup tests"
```

---

### Task 1: `Find-ClaudeConfig` — detect config path (MSIX vs standard)

**Files:**
- Create: `revit-mcp-plugin/lib/Find-ClaudeConfig.ps1`
- Test: `revit-mcp-plugin/tests/Test-FindClaudeConfig.ps1`

- [ ] **Step 1: Write the failing test**

Create `revit-mcp-plugin/tests/Test-FindClaudeConfig.ps1`:
```powershell
. "$PSScriptRoot\_assert.ps1"
. "$PSScriptRoot\..\lib\Find-ClaudeConfig.ps1"
$p = Find-ClaudeConfig
Write-Host "Resolved: $p"
Assert ($null -ne $p) "returns a path"
Assert ($p -like "*claude_desktop_config.json") "path ends in claude_desktop_config.json"
Assert (Test-Path (Split-Path $p)) "parent directory exists"
EndTests
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -ExecutionPolicy Bypass -File "C:\Users\revitadmin\Documents\Claude Code\revit-mcp-plugin\tests\Test-FindClaudeConfig.ps1"`
Expected: FAIL — `Find-ClaudeConfig.ps1` not found / function undefined.

- [ ] **Step 3: Write minimal implementation**

Create `revit-mcp-plugin/lib/Find-ClaudeConfig.ps1`:
```powershell
function Find-ClaudeConfig {
  # MSIX/Store build: config lives under the package's virtualized Roaming.
  $pkg = Get-AppxPackage -Name "*Claude*" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($pkg) {
    $fam = $pkg.PackageFamilyName
    $msix = Join-Path $env:LOCALAPPDATA "Packages\$fam\LocalCache\Roaming\Claude\claude_desktop_config.json"
    if (Test-Path (Split-Path $msix)) { return $msix }
  }
  # Standard installer build.
  $std = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"
  if (-not (Test-Path (Split-Path $std))) {
    New-Item -ItemType Directory -Path (Split-Path $std) -Force | Out-Null
  }
  return $std
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -ExecutionPolicy Bypass -File "...\tests\Test-FindClaudeConfig.ps1"`
Expected: `ALL PASSED`; resolved path is the MSIX virtualized path on this machine.

- [ ] **Step 5: Commit**

```powershell
git -C "...\revit-mcp-plugin" add lib/Find-ClaudeConfig.ps1 tests/Test-FindClaudeConfig.ps1
git -C "...\revit-mcp-plugin" commit -m "feat(setup): detect Claude Desktop config path (MSIX + standard)"
```

---

### Task 2: `Set-RevitMcpConnector` — backup + idempotent merge of mcpServers

**Files:**
- Create: `revit-mcp-plugin/lib/Set-RevitMcpConnector.ps1`
- Test: `revit-mcp-plugin/tests/Test-SetRevitMcpConnector.ps1`

- [ ] **Step 1: Write the failing test** (uses a temp config, never the real one)

Create `revit-mcp-plugin/tests/Test-SetRevitMcpConnector.ps1`:
```powershell
. "$PSScriptRoot\_assert.ps1"
. "$PSScriptRoot\..\lib\Set-RevitMcpConnector.ps1"

$tmp = Join-Path $env:TEMP "rmc_test_config.json"
'{ "preferences": { "keep": "me" } }' | Set-Content $tmp -Encoding UTF8

$server = "C:\fake\server"
Set-RevitMcpConnector -ConfigPath $tmp -ServerDir $server

$j = Get-Content $tmp -Raw | ConvertFrom-Json
Assert ($null -ne $j.mcpServers.revit) "revit server added"
Assert ($j.mcpServers.revit.command -like "*python.exe") "command points to python"
AssertEq $j.preferences.keep "me" "existing preferences preserved"
Assert (Test-Path "$tmp.bak-*") "backup created"

# Idempotency: run again, must not duplicate or error
Set-RevitMcpConnector -ConfigPath $tmp -ServerDir $server
$j2 = Get-Content $tmp -Raw | ConvertFrom-Json
Assert ($null -ne $j2.mcpServers.revit) "still present after re-run"

Remove-Item "$tmp" -Force -ErrorAction SilentlyContinue
Remove-Item "$tmp.bak-*" -Force -ErrorAction SilentlyContinue
EndTests
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -ExecutionPolicy Bypass -File "...\tests\Test-SetRevitMcpConnector.ps1"`
Expected: FAIL — function undefined.

- [ ] **Step 3: Write minimal implementation**

Create `revit-mcp-plugin/lib/Set-RevitMcpConnector.ps1`:
```powershell
function Set-RevitMcpConnector {
  param(
    [Parameter(Mandatory)] [string] $ConfigPath,
    [Parameter(Mandatory)] [string] $ServerDir,
    [string] $Name = "revit"
  )
  $py = Join-Path $ServerDir ".venv\Scripts\python.exe"
  $main = Join-Path $ServerDir "main.py"

  if (Test-Path $ConfigPath) {
    $stamp = Get-Date -Format "yyyyMMddHHmmss"
    Copy-Item $ConfigPath "$ConfigPath.bak-$stamp" -Force
    $raw = Get-Content $ConfigPath -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { $obj = [pscustomobject]@{} }
    else { $obj = $raw | ConvertFrom-Json }
  } else {
    $obj = [pscustomobject]@{}
  }

  # Ensure mcpServers exists (as a hashtable for easy key assignment).
  $servers = @{}
  if ($obj.PSObject.Properties.Name -contains 'mcpServers' -and $obj.mcpServers) {
    foreach ($p in $obj.mcpServers.PSObject.Properties) { $servers[$p.Name] = $p.Value }
  }
  $servers[$Name] = [pscustomobject]@{ command = $py; args = @($main) }

  if ($obj.PSObject.Properties.Name -contains 'mcpServers') { $obj.mcpServers = $servers }
  else { $obj | Add-Member -NotePropertyName mcpServers -NotePropertyValue $servers }

  $json = $obj | ConvertTo-Json -Depth 12
  [System.IO.File]::WriteAllText($ConfigPath, $json, (New-Object System.Text.UTF8Encoding $false))
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -ExecutionPolicy Bypass -File "...\tests\Test-SetRevitMcpConnector.ps1"`
Expected: `ALL PASSED`.

- [ ] **Step 5: Commit**

```powershell
git -C "...\revit-mcp-plugin" add lib/Set-RevitMcpConnector.ps1 tests/Test-SetRevitMcpConnector.ps1
git -C "...\revit-mcp-plugin" commit -m "feat(setup): idempotent mcpServers writer with backup"
```

---

### Task 3: `Enable-PyRevitRoutes` — auto-enable Routes via CLI, with fallback

**Files:**
- Create: `revit-mcp-plugin/lib/Enable-PyRevitRoutes.ps1`
- Test: `revit-mcp-plugin/tests/Test-EnablePyRevitRoutes.ps1`

> NOTE during execution: confirm the exact pyRevit CLI subcommands against the installed version first via `pyrevit configs --help` and `pyrevit configs routes --help`. The code below uses the documented form; adjust to the actual help output before finalizing. Always keep the manual fallback.

- [ ] **Step 1: Write the failing test**

Create `revit-mcp-plugin/tests/Test-EnablePyRevitRoutes.ps1`:
```powershell
. "$PSScriptRoot\_assert.ps1"
. "$PSScriptRoot\..\lib\Enable-PyRevitRoutes.ps1"
$r = Enable-PyRevitRoutes -Port 48884
Assert ($r.ContainsKey('ok')) "returns a result with 'ok'"
Assert ($r.ContainsKey('method')) "reports method (cli|manual|already)"
# Live check: if Revit is open, Routes should answer.
try {
  $resp = Invoke-RestMethod "http://localhost:48884/revit_mcp/status/" -TimeoutSec 4
  Assert ($resp.health -eq 'healthy') "Routes reachable on 48884 (Revit open)"
} catch { Write-Host "  [SKIP] Revit not open; Routes liveness not checked" -ForegroundColor Yellow }
EndTests
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -ExecutionPolicy Bypass -File "...\tests\Test-EnablePyRevitRoutes.ps1"`
Expected: FAIL — function undefined.

- [ ] **Step 3: Write minimal implementation**

Create `revit-mcp-plugin/lib/Enable-PyRevitRoutes.ps1`:
```powershell
function Enable-PyRevitRoutes {
  param([int] $Port = 48884)
  $pyrevit = (Get-Command pyrevit -ErrorAction SilentlyContinue).Source
  if (-not $pyrevit) {
    return @{ ok = $false; method = 'manual'; message =
      "pyRevit CLI not found. Enable manually: pyRevit tab > Settings > Routes > Enable Routes Server (port $Port) > Save." }
  }
  try {
    & pyrevit configs routes port $Port 2>&1 | Out-Null
    & pyrevit configs routes enable 2>&1 | Out-Null
    & pyrevit configs routes load enable 2>&1 | Out-Null   # load-on-startup; verify subcommand vs help
    return @{ ok = $true; method = 'cli'; message = "Routes enabled on port $Port (restart Revit to apply)." }
  } catch {
    return @{ ok = $false; method = 'manual'; message =
      "pyRevit CLI call failed: $($_.Exception.Message). Enable manually via pyRevit > Settings > Routes." }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -ExecutionPolicy Bypass -File "...\tests\Test-EnablePyRevitRoutes.ps1"`
Expected: `ALL PASSED` (Routes liveness PASS since Revit is open).

- [ ] **Step 5: Commit**

```powershell
git -C "...\revit-mcp-plugin" add lib/Enable-PyRevitRoutes.ps1 tests/Test-EnablePyRevitRoutes.ps1
git -C "...\revit-mcp-plugin" commit -m "feat(setup): auto-enable pyRevit Routes via CLI with manual fallback"
```

---

### Task 4: Server cold-start — measure, then trim if needed

**Files:**
- Modify: `revit-mcp-server/main.py` (only if measurement warrants)
- Test: `revit-mcp-server/tests/test_init_latency.py`

- [ ] **Step 1: Write the measurement test**

Create `revit-mcp-server/tests/test_init_latency.py`:
```python
# Measures time from spawn to MCP initialize response over stdio.
import asyncio, time, sys
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

PY = sys.executable
MAIN = __file__.replace("tests\\test_init_latency.py", "main.py").replace("tests/test_init_latency.py", "main.py")

async def main():
    t0 = time.time()
    params = StdioServerParameters(command=PY, args=[MAIN])
    async with stdio_client(params) as (r, w):
        async with ClientSession(r, w) as s:
            await s.initialize()
            dt = time.time() - t0
            print("INIT_LATENCY_S=%.3f" % dt)
            assert dt < 3.0, "initialize too slow: %.3f s" % dt

asyncio.run(main())
```

- [ ] **Step 2: Run it to get the baseline**

Run: `cd revit-mcp-server; .\.venv\Scripts\python.exe tests\test_init_latency.py`
Expected: prints `INIT_LATENCY_S=<n>`. Record the baseline (~2.4s observed).

- [ ] **Step 3: Profile imports**

Run: `.\.venv\Scripts\python.exe -X importtime main.py < NUL 2> importtime.txt` then inspect the largest cumulative imports.
Decision rule: if a single non-essential import dominates (>0.4s), lazy-import it inside the function that uses it. If the cost is spread across required modules, leave as-is and lower the assertion target to a realistic value.

- [ ] **Step 4: Apply the smallest effective change**

If warranted, move the dominant import into the using function (lazy import). Example pattern (only if a heavy module is identified):
```python
# at module top: remove "import heavy_mod"
def tool_that_needs_it(...):
    import heavy_mod  # lazy: paid only when this tool runs
    ...
```
If not warranted, set the test threshold to baseline*1.1 and note that interpreter+required imports are the floor.

- [ ] **Step 5: Re-run latency test**

Run: `.\.venv\Scripts\python.exe tests\test_init_latency.py`
Expected: PASS; latency ≤ baseline (improved or unchanged with documented floor).

- [ ] **Step 6: Commit**

```powershell
git -C "...\revit-mcp-server" add main.py tests/test_init_latency.py
git -C "...\revit-mcp-server" commit -m "perf(server): measure + trim stdio cold-start"
```

---

### Task 5: Fix `get_revit_model_info` false-error header

**Files:**
- Modify: the tool/route that formats `get_revit_model_info` (locate in `revit-mcp-server/tools/` or `revit-mcp-server/revit_mcp/`)
- Test: `revit-mcp-server/tests/test_model_info_format.py`

- [ ] **Step 1: Locate the formatter**

Run: `grep -rn "ERROR DETAILS" "revit-mcp-server"` and `grep -rn "get_revit_model_info\|model_info" "revit-mcp-server\tools" "revit-mcp-server\revit_mcp"`
Identify where the success/error branch is chosen (a check like `status == "success"` against a response that doesn't set it).

- [ ] **Step 2: Write the failing test** (requires Revit open)

Create `revit-mcp-server/tests/test_model_info_format.py`:
```python
import asyncio, sys
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

PY = sys.executable
MAIN = __file__.replace("tests\\test_model_info_format.py", "main.py").replace("tests/test_model_info_format.py", "main.py")

async def main():
    async with stdio_client(StdioServerParameters(command=PY, args=[MAIN])) as (r, w):
        async with ClientSession(r, w) as s:
            await s.initialize()
            res = await s.call_tool("get_revit_model_info", {})
            txt = " ".join(getattr(c, "text", "") for c in res.content)
            assert "ERROR DETAILS" not in txt, "false error header present"
            assert "element_summary" in txt or "total_elements" in txt, "expected model data"
            print("MODEL_INFO_OK")

asyncio.run(main())
```

- [ ] **Step 3: Run to verify it fails**

Run: `.\.venv\Scripts\python.exe tests\test_model_info_format.py`
Expected: FAIL on `false error header present`.

- [ ] **Step 4: Fix the branch**

In the located formatter, make the success check tolerant: treat a response containing model payload keys (e.g. `element_summary`/`project_info`) as success even when an explicit `status == "success"` is absent. Show the actual edited lines during execution (exact code depends on the located file).

- [ ] **Step 5: Run to verify it passes**

Run: `.\.venv\Scripts\python.exe tests\test_model_info_format.py`
Expected: `MODEL_INFO_OK`.

- [ ] **Step 6: Commit**

```powershell
git -C "...\revit-mcp-server" add -A
git -C "...\revit-mcp-server" commit -m "fix(server): get_revit_model_info no longer prints false error header"
```

---

### Task 6: Main orchestrator rewrite (`setup-revit-mcp.ps1`) — local-first + optional ngrok

**Files:**
- Modify: `revit-mcp-plugin/setup-revit-mcp.ps1`
- Test: `revit-mcp-plugin/tests/Test-SetupDryRun.ps1`

- [ ] **Step 1: Write the dry-run test**

Create `revit-mcp-plugin/tests/Test-SetupDryRun.ps1`:
```powershell
. "$PSScriptRoot\_assert.ps1"
$setup = "$PSScriptRoot\..\setup-revit-mcp.ps1"
$out = & powershell -ExecutionPolicy Bypass -File $setup -DryRun -ServerDir "C:\fake\server" 2>&1 | Out-String
Write-Host $out
Assert ($out -match "Find-ClaudeConfig|config path") "reports config path step"
Assert ($out -match "pyRevit Routes") "reports pyRevit step"
Assert ($out -match "mcpServers|connector") "reports connector write step"
Assert ($out -notmatch "ngrok auth token") "ngrok NOT in default path"
EndTests
```

- [ ] **Step 2: Run to verify it fails**

Run: `powershell -ExecutionPolicy Bypass -File "...\tests\Test-SetupDryRun.ps1"`
Expected: FAIL — `-DryRun` param not yet supported.

- [ ] **Step 3: Rewrite the orchestrator**

Rewrite `setup-revit-mcp.ps1` to:
1. Accept params: `[switch]$DryRun`, `[string]$ServerDir`, `[switch]$EnableWebMobile`.
2. Dot-source `lib/Find-ClaudeConfig.ps1`, `lib/Set-RevitMcpConnector.ps1`, `lib/Enable-PyRevitRoutes.ps1`.
3. Reuse existing uv-install + server-download + `uv sync` blocks from the current script (lines covering STEP 1 and STEP 4 in the old script) for the bootstrap. Skip these on `-DryRun`.
4. Resolve `$ServerDir` (default to `Join-Path $SCRIPT_DIR "mcp-server"`).
5. `Enable-PyRevitRoutes` → print result message.
6. `$cfg = Find-ClaudeConfig`; on `-DryRun` print intended path + steps and exit; else `Set-RevitMcpConnector -ConfigPath $cfg -ServerDir $ServerDir`.
7. If `-EnableWebMobile`: run the existing ngrok flow (auth token, domain, generate plugin ZIP) — moved verbatim from the old script into this optional branch only.
8. Print "Restart Claude Desktop to load the revit connector" + the deterministic log check path.

Each numbered action must `Write-Host` a recognizable line so the dry-run test matches (`config path`, `pyRevit Routes`, `connector`).

- [ ] **Step 4: Run dry-run test to verify it passes**

Run: `powershell -ExecutionPolicy Bypass -File "...\tests\Test-SetupDryRun.ps1"`
Expected: `ALL PASSED`.

- [ ] **Step 5: Commit**

```powershell
git -C "...\revit-mcp-plugin" add setup-revit-mcp.ps1 tests/Test-SetupDryRun.ps1
git -C "...\revit-mcp-plugin" commit -m "feat(setup): local-first orchestrator; ngrok behind --EnableWebMobile"
```

---

### Task 7: `references/mcp-clients.md` — multi-client snippets

**Files:**
- Create: `revit-mcp-plugin/revit-bim/skills/revit-bim/references/mcp-clients.md`

- [ ] **Step 1: Write the doc**

Content: one section per client (Claude Desktop/Cowork, Claude Code, Cursor, Windsurf, Cline, VS Code, generic remote via `--http`). Each shows the exact `command`/`args` JSON pointing at `<server>\.venv\Scripts\python.exe` + `main.py`, plus the file each client reads. State Claude is the auto-configured priority; others are manual snippets.

- [ ] **Step 2: Verify it renders / links resolve**

Run: `grep -c "python.exe" "...\references\mcp-clients.md"`
Expected: ≥ 5 (one per stdio client).

- [ ] **Step 3: Commit**

```powershell
git -C "...\revit-mcp-plugin" add revit-bim/skills/revit-bim/references/mcp-clients.md
git -C "...\revit-mcp-plugin" commit -m "docs: add multi-client MCP config snippets"
```

---

### Task 8: Docs update (README / CONNECTORS / SKILL / plugin.json)

**Files:**
- Modify: `revit-mcp-plugin/README.md`, `revit-mcp-plugin/revit-bim/CONNECTORS.md`, `revit-mcp-plugin/revit-bim/skills/revit-bim/SKILL.md`

- [ ] **Step 1: README — lead with local-first**

Replace the "Quick Setup (Cowork Users)" ngrok-centric flow with: Step 0 install pyRevit (note: setup auto-enables Routes), Step 1 download repo, Step 2 run `setup-revit-mcp.bat` (auto-wires Claude Desktop, no ngrok), Step 3 restart Desktop, done. Add "Optional: use from web/phone" section describing `setup-revit-mcp.bat` with the web/mobile toggle (ngrok). Link `references/mcp-clients.md` for other AI tools.

- [ ] **Step 2: CONNECTORS.md — describe stdio connector**

Rewrite connection flow to `Claude Desktop → local stdio server → pyRevit :48884 → Revit` as default; keep ngrok troubleshooting under the optional path.

- [ ] **Step 3: SKILL.md — note default transport**

Add one line under Critical Constraints: default transport is local stdio via Claude Desktop; ngrok optional for web/mobile. No tool behavior change.

- [ ] **Step 4: Verify no stale "ngrok required" claims remain in the default path**

Run: `grep -rn "ngrok" "...\revit-mcp-plugin\README.md"` and confirm every hit is under an "Optional"/web-mobile context.

- [ ] **Step 5: Commit**

```powershell
git -C "...\revit-mcp-plugin" add README.md revit-bim/CONNECTORS.md revit-bim/skills/revit-bim/SKILL.md
git -C "...\revit-mcp-plugin" commit -m "docs: local-first setup; ngrok demoted to optional web/mobile"
```

---

### Task 9: Final live end-to-end validation + real config apply

**Files:** none (validation), then real `claude_desktop_config.json` via the new script

- [ ] **Step 1: Run all PowerShell unit tests**

Run each `tests\Test-*.ps1`. Expected: every one prints `ALL PASSED`.

- [ ] **Step 2: Apply for real via the new orchestrator**

Run: `powershell -ExecutionPolicy Bypass -File "...\setup-revit-mcp.ps1" -ServerDir "C:\Users\revitadmin\Documents\Claude Code\revit-mcp-server"`
Expected: config path resolved to MSIX path; Routes enabled message; connector written; backup created.

- [ ] **Step 3: Confirm config**

Run: validate JSON + `mcpServers.revit` present + existing keys (`coworkUserFilesPath`, `remoteToolsDeviceName`) intact.
Expected: all present.

- [ ] **Step 4: Restart Desktop (only WindowsApps tree; never the CLI host) and check log**

Kill only `claude.exe` whose path is under `WindowsApps`, relaunch via `shell:AppsFolder\Claude_pzs8sxrjxfjjc!Claude`, wait, then read `logs\mcp-server-revit.log`.
Expected: `Server started and connected successfully` for `revit`.

- [ ] **Step 5: Live tool call through stdio (Revit open)**

Run the proven MCP stdio client calling `get_revit_status`, `get_revit_model_info`, `list_levels`.
Expected: real ESB data; **no** `ERROR DETAILS` header (Task 5 fix confirmed).

- [ ] **Step 6: Final commit + summary**

```powershell
git -C "...\revit-mcp-plugin" add -A
git -C "...\revit-mcp-plugin" commit -m "chore: validated local-first setup end-to-end"
```
Then report results to the user (do NOT push or open PRs until the user asks).

---

## Self-Review

**Spec coverage:** §5 setup flow → Tasks 1,2,3,6. §6 config detection → Task 1. §7 cold-start → Task 4. §8 docs → Tasks 7,8. §4a multi-client → Task 7. Optional ngrok → Task 6 (`-EnableWebMobile`). §11b bug → Task 5. Validation → Task 9. All covered.

**Placeholders:** Tasks 4 and 5 intentionally locate-then-edit (file/import identity is environment-dependent); both specify the exact decision rule and show the edit pattern + a concrete passing assertion. No vague "add error handling".

**Type/name consistency:** `Find-ClaudeConfig` (no args, returns path), `Set-RevitMcpConnector -ConfigPath -ServerDir [-Name]`, `Enable-PyRevitRoutes -Port` (returns hashtable with `ok`/`method`/`message`) — used consistently in tests, orchestrator, and Task 9.
