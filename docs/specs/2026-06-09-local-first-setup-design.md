# Streamlined Local-First Setup for Revit MCP (No ngrok)

**Date:** 2026-06-09
**Status:** Draft — awaiting review
**Author:** Talal Ahmed (with Claude)

---

## 1. Problem

The current Cowork setup routes Claude → **ngrok tunnel (cloud)** → local MCP server → Revit.
For a non-technical architect/engineer this means:

- Create an ngrok account, copy an auth token, reserve a static domain, paste two values.
- Manually enable pyRevit Routes through the ribbon (Settings → Routes → checkbox).
- Run `start-revit-mcp.bat` every session and **keep a terminal window open** (closing it disconnects).
- Two scripts, no status indicator, fragile.

## 2. Key finding (verified on this machine, 2026-06-09)

Claude Cowork runs **inside the Claude Desktop app**, which can launch a **local MCP server over stdio** and bridge it into Cowork — **no tunnel required**. Verified end-to-end:

- The MCP server already defaults to `stdio` transport (`main.py` line ~126); the ngrok path is just the `--http` flag. **Zero server code changes needed.**
- Wrote an `mcpServers.revit` block into `claude_desktop_config.json`, restarted Desktop, and observed in `logs/mcp-server-revit.log`:
  - `Server started and connected successfully`
  - client `claude-ai` completed the MCP `initialize` handshake; server returned `serverInfo: Revit MCP Server v1.9.0`.
- `revit` now appears in the Desktop app's **Connectors** section, which Cowork draws from. Confirmed by user.

**Conclusion:** ngrok is unnecessary for Desktop + Cowork. It remains necessary only for **claude.ai web / mobile** (where the connection originates from Anthropic's cloud, per Anthropic docs).

## 3. Goals / Non-goals

**Goals**
- One-time setup that needs **no ngrok account** for the default (Desktop/Cowork) path.
- **Auto-enable pyRevit Routes** (no manual ribbon steps).
- **Auto-write** the `mcpServers` entry into the correct `claude_desktop_config.json`.
- Eliminate the per-session terminal/`start` script for the default path.
- Keep ngrok available as an **opt-in** for web/mobile users.

**Non-goals (YAGNI)**
- System service / tray app (no longer needed — Desktop manages the process lifecycle).
- Changing the 48 tools or the pyRevit route handlers.
- Supporting claude.ai web without a tunnel (impossible by design).

## 4. Architecture

```
Default (Desktop + Cowork):
  Claude Desktop ──spawns──> local MCP server (stdio) ──HTTP :48884──> pyRevit Routes ──> Revit API

Optional (web / mobile), opt-in:
  claude.ai ──HTTPS──> ngrok ──> local MCP server (--http :8000) ──:48884──> pyRevit ──> Revit
```

The server binary and pyRevit side are identical for both; only the transport to Claude differs.

## 4a. Multi-client support (all AI tools — Claude is priority)

The MCP server is a **standard MCP server** speaking three transports (`stdio`, `sse`, `streamable-http`). MCP is an open protocol, so **any MCP-capable AI tool can use it with no server changes** — this is a documentation + config-snippet task, not new code.

| Client | Transport | How |
|--------|-----------|-----|
| **Claude Desktop / Cowork** (priority) | stdio | `mcpServers` block in `claude_desktop_config.json` — auto-written by setup |
| **Claude Code (CLI)** | stdio | `.mcp.json` `command/args` (already documented) |
| Cursor | stdio | `.cursor/mcp.json` with `command/args` |
| Windsurf / Cline / Continue / VS Code MCP | stdio | each tool's MCP config — same `command/args` |
| Remote / cloud clients (claude.ai web, others) | http/sse | run with `--http`; expose via tunnel |

**Plan:** Claude (Desktop/Cowork) is the default the setup wires automatically. Ship a short `references/mcp-clients.md` with copy-paste config snippets for the other tools, all pointing at the same `command/args` we validated. No per-client code.

## 5. New one-time setup flow (`setup-revit-mcp.ps1` v2)

1. **Install runtime** — `uv` (brings its own Python); download the MCP server repo; `uv sync`. *(unchanged, minus ngrok)*
2. **pyRevit Routes — automatic**
   - Detect pyRevit (CLI on PATH / ribbon present).
   - Enable Routes server, set port `48884`, and enable load-on-startup via the **pyRevit CLI**.
   - *(Exact CLI subcommands to be confirmed during implementation — see Open Questions.)*
   - Fallback: if CLI path fails, print the 3 manual ribbon steps.
3. **Wire into Claude Desktop — automatic**
   - **Locate the config** (see §6).
   - Back it up (`claude_desktop_config.json.bak-<date>`).
   - **Merge** an `mcpServers.revit` stdio block (idempotent — skip/update if `revit` already present), pointing at the venv Python + `main.py`:
     ```json
     "mcpServers": {
       "revit": {
         "command": "<server>\\.venv\\Scripts\\python.exe",
         "args": ["<server>\\main.py"]
       }
     }
     ```
   - Prompt the user to **restart Claude Desktop** (the script can't restart it safely if launched from within it).
4. **Optional: web/mobile** — ask `Enable use from claude.ai web or phone? (y/N)`. If yes, run the existing ngrok flow (account/token/domain) and register the remote connector. Off by default.

**Daily use after setup:** open Revit → open Cowork/Desktop → `revit` tools are live. No script, no terminal.

## 6. Config-path detection (important — discovered gotcha)

Two cases:
- **MSIX / Microsoft Store build** (this machine): config lives at the **virtualized** path
  `%LOCALAPPDATA%\Packages\Claude_<id>\LocalCache\Roaming\Claude\claude_desktop_config.json`.
- **Standard installer build**: `%APPDATA%\Claude\claude_desktop_config.json`.

Detection logic: enumerate `Get-AppxPackage *Claude*`; if present, use the package's `LocalCache\Roaming\Claude` path; else fall back to `%APPDATA%\Claude`. Create the file if absent (valid empty `{}` → merge).

## 7. Server cold-start trim (small server-side polish)

Observed `initialize` latency ~2.4s (Python start + importing all 48 tools at module load). Reduce so the handshake answers quickly:
- Defer heavy imports / tool registration until first use where feasible, or
- Lazy-import per-tool modules.
Target: `initialize` response < ~0.8s. Low risk; behind the same public tool surface.

## 8. Documentation changes

- **README.md** — lead with the local-first flow; demote ngrok to an "Optional: web/mobile" section.
- **CONNECTORS.md** — describe the stdio connector; keep ngrok troubleshooting under the optional path.
- **SKILL.md / plugin.json** — note local stdio is the default transport; no behavior change to tools.

## 9. Backward compatibility / migration

- Existing ngrok users keep working — the remote connector is untouched; the new local connector is additive.
- A `revit` (local) and `revit-cloud` (remote) connector can coexist; document that local is preferred when on this PC.

## 10. Risks / open questions

- **pyRevit CLI exact syntax** for enabling Routes + setting port + load-on-startup — must be verified against the installed pyRevit version before relying on it (fallback to manual steps if unavailable).
- **MSIX restart**: setup launched from inside the Desktop app can't restart it; we instruct the user instead. Setup launched from a normal terminal can restart it.
- **uv vs direct venv Python** in the config command: direct venv Python proved fastest/most reliable here; uv is more portable if the venv moves. Decide default (lean: direct venv Python, with uv as fallback).

## 11. Verification plan

- After setup: assert config JSON valid; assert `mcpServers.revit` present.
- After restart: parse `logs/mcp-server-revit.log` for `Server started and connected successfully` + handshake (this is the deterministic check we used today).
- Manual: `revit` appears in Connectors; a tool call returns data with Revit open.

### 11a. Validation results (2026-06-09) — PASSED 100%

End-to-end proven live on this machine through the exact stdio transport Claude uses:
- `initialize` → `Revit MCP Server v1.9.0`; `tools/list` → **48 tools**.
- `get_revit_status` → live data: Document **ESB**, healthy/active.
- `get_revit_model_info` → real model: 138 elements (28 walls, 98 floors, 8 furniture, 4 doors), full level list.
- `list_levels` → server hit `GET :48884/revit_mcp/list_levels/` → `200 OK`.
- Desktop side: `revit` connector visible; `mcp-server-revit.log` shows successful connect + handshake.

Full chain confirmed with no ngrok: **MCP client → stdio server → pyRevit `:48884` → Revit → back.**

### 11b. Bug found during validation (add to fix list)

- `get_revit_model_info` emits a misleading `ERROR DETAILS / Status: unknown / Error: Unknown error occurred` header while still returning all correct data. Cause: response formatter checks a `status == "success"` field the route doesn't set, so it takes the error-format branch. Fix: align the route's response envelope or the formatter's success check. Cosmetic (no data loss) but confusing.

## 12. Out of scope

Tray app, Windows service, multi-machine sync, packaging as a signed `.mcpb` extension (possible future enhancement, not now).
