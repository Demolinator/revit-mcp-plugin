# Connectors

## revit

The Revit MCP Server connects Claude to Autodesk Revit 2024/2025/2026/2027 via the Model
Context Protocol. It provides 48 tools for building design, model editing, structural
systems, MEP, documentation, analysis, clash detection, and model persistence.

**Default connection (no tunnel):** Claude Desktop launches the server locally over
**stdio** and bridges it into Cowork. No ngrok, no account, no terminal.

## Connection Flow

```
Claude Desktop / Cowork --stdio--> local MCP server --HTTP :48884--> pyRevit Routes --> Revit API
```

## Prerequisites

- **Autodesk Revit 2024/2025/2026/2027** open with a project
- **pyRevit** installed; Routes enabled on port 48884 (the setup script does this automatically)
- One-time `setup-revit-mcp.bat` (writes the `revit` connector into `claude_desktop_config.json`)

## Setup

**Easiest — install the plugin (it bundles this server):** installing `revit-bim` wires the
`revit` connector automatically via its `.mcp.json` (`uv run` + `${CLAUDE_PLUGIN_ROOT}`), so you
get tools + skill + commands in one step. One-time prep: pyRevit (Routes) + `uv` installed.

**Or wire the server only (no plugin):**
1. Run `setup-revit-mcp.bat` once (installs deps, enables Routes, writes the connector).
2. Restart Claude Desktop — `revit` appears in Connectors.
3. Open Revit + Claude; tools are live. Nothing to run per session.

## Other MCP clients

Cursor, Windsurf, Cline, VS Code, and Claude Code use the same local stdio command — see
`skills/revit-bim/references/mcp-clients.md`.

## Optional: web / mobile (ngrok)

To use from claude.ai web or phone, run `setup-web-mobile.bat` to configure an ngrok tunnel
and a remote connector:

```
claude.ai (web/phone) --HTTPS--> ngrok tunnel --> local MCP server (--http :8000) --> pyRevit :48884 --> Revit
```

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `revit` not in Connectors | Desktop not restarted | Fully quit and reopen Claude Desktop |
| "No active Revit document" | Revit not open | Open Revit with a project |
| "Connection refused on 48884" | pyRevit Routes not loaded | Re-run setup, or enable pyRevit > Settings > Routes |
| Tools return errors | Invalid type names | Call `list_families` / `list_family_categories` first |
