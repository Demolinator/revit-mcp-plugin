# Revit MCP Plugin

Natural-language building design for Autodesk Revit 2024/2025/2026 via Claude.

Describe buildings in plain English — Claude creates BIM elements in Revit automatically. 45 MCP tools for architects, structural engineers, and MEP engineers.

## How It Works

```
Claude (Cowork/Desktop/Code) → MCP Server → pyRevit Routes → Revit API
```

You speak naturally. Claude translates your intent into precise Revit operations.

## Quick Setup (Cowork Users)

### Prerequisites

| Requirement | Why |
|-------------|-----|
| Windows 10/11 | Revit is Windows-only |
| Autodesk Revit 2024, 2025, or 2026 | The BIM application |
| pyRevit | Runs the HTTP routes inside Revit (port 48884) |
| Git | To clone this repo |
| Internet connection | For ngrok tunnel and MCP server download |

### Step 1: Clone this repo

```powershell
git clone https://github.com/Demolinator/revit-mcp-plugin.git
cd revit-mcp-plugin
```

### Step 2: One-time setup

Double-click **`setup-revit-mcp.bat`** (or right-click > Run with PowerShell).

The setup script automatically:
- Installs `uv` (Python package manager) if missing
- Installs `ngrok` (tunnel) if missing
- Configures your ngrok auth token and free static domain
- Downloads the MCP server from GitHub
- Installs MCP server dependencies
- Tests connectivity to Revit
- Generates a ready-to-upload plugin ZIP with your permanent URL

### Step 3: Upload plugin to Cowork

1. Open [Claude Cowork](https://claude.ai)
2. Go to **Plugins** > **Upload Plugin**
3. Upload the ZIP file from `dist/revit-architect-plugin.zip`

### Step 4: Each session

1. Open Revit (2024, 2025, or 2026) with a project file
2. Double-click **`start-revit-mcp.bat`**
3. Wait for "READY!" message
4. Use Cowork — your plugin is connected

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
├── setup-revit-mcp.bat/.ps1           # One-time setup script
├── start-revit-mcp.bat/.ps1           # Per-session startup script
└── revit-bim/                         # The plugin
    ├── .claude-plugin/plugin.json     # Plugin manifest
    ├── .mcp.json                      # MCP server config (HTTP)
    ├── CONNECTORS.md                  # Connection setup docs
    ├── README.md                      # Plugin docs
    ├── commands/                      # 5 slash commands
    └── skills/revit-bim/             # BIM knowledge + references
```

## Requirements

- **Autodesk Revit 2024, 2025, or 2026**
- **pyRevit** installed and loaded in Revit
- **Windows 10/11**

## Author

**Talal Ahmed**

## License

Apache-2.0 — See [LICENSE](LICENSE) for details.
