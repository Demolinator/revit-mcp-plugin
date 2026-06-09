# Revit MCP Plugin

Natural-language building design for Autodesk Revit 2024/2025/2026/2027 via Claude.

Describe buildings in plain English — Claude creates BIM elements in Revit automatically. 48 MCP tools (including clash detection) for architects, structural engineers, and MEP engineers.

## How It Works

```
Claude (Cowork/Desktop/Code) → MCP Server → pyRevit Routes → Revit API
```

You speak naturally. Claude translates your intent into precise Revit operations.

## Quick Setup (Claude Desktop / Cowork) — no ngrok

Claude Desktop runs the MCP server **locally over stdio** and bridges it into Cowork.
There is **no tunnel, no ngrok account, and no terminal to keep open**.

### Prerequisites

| Requirement | Why |
|-------------|-----|
| Windows 10/11 | Revit is Windows-only |
| Autodesk Revit 2024, 2025, 2026, or 2027 | The BIM application |
| Claude Desktop app | Cowork lives inside it; it launches the local server |
| Internet connection | One-time: download tools/dependencies |

**You do NOT need** Python, Git, ngrok, or any developer tools installed. The setup script installs what it needs.

### Step 0: Install pyRevit

pyRevit is a free add-in that lets scripts run inside Revit. The MCP server talks to Revit through it.

1. Go to https://github.com/pyrevitlabs/pyRevit/releases
2. Under **Assets**, download the **.exe installer** (e.g. `pyRevit_CLI_4.8.x.x_admin_signed.exe`)
3. Run it — accept defaults, **Next** through each screen, then **Install**
4. Open Revit — you should see a **pyRevit** tab in the ribbon

The setup script in Step 2 **enables pyRevit Routes for you automatically**. (If it can't, enable it manually: pyRevit tab > Settings > Routes > **Enable Routes Server** > Save Settings.)

**How to verify Routes:** browse to `http://localhost:48884/` with Revit open — any response means it's working.

### Step 1: Download this repo

**Option A** — Git: `git clone https://github.com/Demolinator/revit-mcp-plugin.git`

**Option B** — No Git: GitHub > green **Code** button > **Download ZIP** > right-click > **Extract All**. The folder contains `setup-revit-mcp.bat`.

### Step 2: One-time setup

Double-click **`setup-revit-mcp.bat`**. It automatically:
- Installs `uv` (brings its own Python — nothing touches your system Python)
- Installs the MCP server dependencies
- **Enables pyRevit Routes** (port 48884)
- **Wires the `revit` connector into Claude Desktop** (writes `mcpServers` into your `claude_desktop_config.json`, backing it up first)

No ngrok. No account. No plugin ZIP to upload.

### Step 3: Restart Claude Desktop

Fully quit and reopen Claude Desktop so it loads the new connector. You'll see **`revit`** in the Connectors list, available in both Desktop chat and Cowork.

### Done — daily use

1. Open Revit with a project (pyRevit Routes loads automatically).
2. Open Claude Desktop / Cowork — the `revit` tools are live. **No terminal, no start script.**

**Verify it loaded:** the log at
`%LOCALAPPDATA%\Packages\<Claude package>\LocalCache\Roaming\Claude\logs\mcp-server-revit.log`
shows `Server started and connected successfully`.

### Use from other AI tools

The server is standard MCP, so Cursor, Windsurf, Cline, VS Code, and Claude Code work too —
copy-paste configs in [`revit-bim/skills/revit-bim/references/mcp-clients.md`](revit-bim/skills/revit-bim/references/mcp-clients.md).

### Optional: use from claude.ai web or phone (ngrok)

The local connection only works on the PC running Revit. To also reach it from the web or
your phone, run **`setup-web-mobile.bat`** once — it configures an ngrok tunnel + remote
connector. Not needed for Claude Desktop / Cowork.

### Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `revit` not in Connectors | Desktop not restarted after setup | Fully quit and reopen Claude Desktop |
| "Revit not detected on port 48884" | Revit not open or Routes off | Open Revit with a project; re-run setup or enable pyRevit > Settings > Routes |
| Setup script closes immediately | Windows blocked the script | Right-click `setup-revit-mcp.bat` > **Run as administrator** |
| "uv not found" | uv not installed/PATH | Install uv from https://docs.astral.sh/uv/ and re-run |
| Tools return errors | Invalid family type names | Ask Claude to call `list_families` / `list_family_categories` first |
| Web/mobile (ngrok) issues | tunnel/domain/token | See ngrok troubleshooting inside `setup-web-mobile.ps1` output and https://dashboard.ngrok.com |

## Quick Setup (Claude Code CLI)

### Option A: Marketplace

```bash
/plugin marketplace add Demolinator/revit-mcp-plugin
/plugin install revit-bim@revit-mcp
```

Then configure the MCP server connection in your project:

```json
// .mcp.json in your project
{
  "mcpServers": {
    "revit": {
      "command": "uv",
      "args": ["run", "main.py"],
      "cwd": "/path/to/mcp-server"
    }
  }
}
```

### Option B: Direct MCP server

```bash
cd mcp-server
uv sync
uv run main.py
```

## Quick Setup (Claude Desktop / Any MCP Client)

Add to your MCP client config:

```json
{
  "mcpServers": {
    "revit": {
      "command": "uv",
      "args": ["run", "main.py"],
      "cwd": "/path/to/mcp-server"
    }
  }
}
```

## Commands

| Command | Description |
|---------|-------------|
| `/revit-bim:design-building` | Full interactive building design workflow |
| `/revit-bim:create-element` | Create a BIM element from natural language |
| `/revit-bim:query-model` | Query and inspect the Revit model |
| `/revit-bim:modify-model` | Modify, delete, or update elements |
| `/revit-bim:analyze-model` | Analyze statistics, rooms, materials |

## Architecture

```
Claude ──stdio/SSE/HTTP──> MCP Server (Python/FastMCP) ──HTTP :48884──> pyRevit Routes ──> Revit API
```

| Component | Runtime | Purpose |
|-----------|---------|---------|
| MCP Server (`main.py` + `tools/`) | Python 3.11+ | MCP protocol, tool definitions |
| pyRevit Routes (`revit_mcp/`) | IronPython 2.7 inside Revit | Direct Revit API access |

## Repository Structure

```
revit-mcp-plugin/
├── .claude-plugin/marketplace.json    # Marketplace catalog
├── README.md                          # This file
├── setup-revit-mcp.bat/.ps1           # One-time LOCAL setup (no ngrok) — default
├── setup-web-mobile.bat/.ps1          # Optional: ngrok setup for web/phone
├── start-revit-mcp.bat/.ps1           # Per-session launcher (web/mobile path only)
├── lib/                               # Setup helpers (config detect, connector, Routes)
├── tests/                             # Setup unit tests (PowerShell)
└── revit-bim/                         # The plugin
    ├── .claude-plugin/plugin.json     # Plugin manifest
    ├── CONNECTORS.md                  # Connection setup docs
    ├── README.md                      # Plugin docs
    ├── commands/                      # 5 slash commands
    └── skills/revit-bim/             # BIM knowledge + references (incl. mcp-clients.md)
```

## Requirements

- **Autodesk Revit 2024, 2025, 2026, or 2027**
  - *Revit 2027 runs on .NET 10; use a pyRevit build that supports Revit 2027.*
- **pyRevit** installed and loaded in Revit (see Step 0 above)
- **Windows 10/11**
- **Internet connection**

No Python, Git, or developer tools required — the setup script installs everything.

## Author

**Talal Ahmed**

## License

Apache-2.0 — See [LICENSE](LICENSE) for details.
