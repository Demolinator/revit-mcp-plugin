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
| Internet connection | For downloading tools and creating the tunnel |

**You do NOT need** Python, Git, or any developer tools installed. The setup script installs everything automatically.

### Step 0: Install pyRevit

pyRevit is a free add-in that lets scripts run inside Revit. The MCP server needs it to communicate with Revit.

1. Go to https://github.com/pyrevitlabs/pyRevit/releases
2. Scroll down to **Assets** and download the **.exe installer** (the file named something like `pyRevit_CLI_4.8.x.x_admin_signed.exe`)
3. Run the installer — accept all defaults, click **Next** through each screen, then **Install**
4. Open Revit (or restart it if it was already open)
5. You should now see a **pyRevit** tab in the ribbon at the top of Revit — if you see it, pyRevit is installed
6. Click the **pyRevit** tab, then click **Settings** (the gear icon)
7. In the Settings window, find the **Routes** section on the left sidebar and click it
8. Check the box that says **Enable Routes Server**
9. Click **Save Settings** at the bottom and wait for pyRevit to reload

**How to verify:** Open your web browser and go to `http://localhost:48884/` — if you see any response (even an error page), it's working. If you see "This site can't be reached" or "Connection refused", go back to step 6 and make sure Routes Server is enabled.

### Step 1: Download this repo

**Option A** — If you have Git:
```powershell
git clone https://github.com/Demolinator/revit-mcp-plugin.git
cd revit-mcp-plugin
```

**Option B** — No Git (download ZIP):
1. Go to https://github.com/Demolinator/revit-mcp-plugin
2. Click the green **Code** button at the top right
3. Click **Download ZIP**
4. Find the downloaded ZIP file (usually in your Downloads folder)
5. Right-click the ZIP > **Extract All** > choose a location (like your Desktop) > **Extract**
6. Open the extracted folder — you should see `setup-revit-mcp.bat` inside

### Step 2: One-time setup

Double-click **`setup-revit-mcp.bat`**.

The setup script automatically handles everything:
- Installs `uv` (Python package manager) — no Python needed on your PC
- Installs Python via uv (a standalone copy, doesn't affect your system)
- Installs `ngrok` (secure tunnel to connect Cowork to your PC)
- Asks you to create a free ngrok account and paste your auth token
- Asks you to create a free static domain on ngrok
- Downloads the MCP server from GitHub
- Installs all MCP server dependencies
- Tests connectivity to Revit (optional — Revit doesn't need to be open during setup)
- Generates a ready-to-upload Cowork plugin ZIP with your permanent URL

**During setup you'll need to:**
1. Create a free ngrok account at https://dashboard.ngrok.com/signup (the script opens this page for you)
2. Copy your auth token from the ngrok dashboard and paste it when asked
3. Create a free static domain at https://dashboard.ngrok.com/domains and paste it when asked

### Step 3: Upload plugin to Cowork

1. Open [Claude Cowork](https://claude.ai)
2. Go to **Plugins** > **Upload Plugin**
3. Upload the ZIP file from the `dist/` folder (the script opens this folder for you)

### Step 4: Each session

1. Open Revit (2024, 2025, or 2026) with a project file
2. Double-click **`start-revit-mcp.bat`**
3. Wait for the "READY!" message
4. **Keep the terminal window open** (minimize it) — it runs the MCP server and tunnel. Closing it disconnects Cowork from Revit.
5. Open Cowork — your plugin is connected and ready to use
6. When done, press **Ctrl+C** in the terminal to shut down cleanly

### Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| "Revit not detected on port 48884" | Revit not open or pyRevit Routes not enabled | Open Revit with a project, check pyRevit > Settings > Routes > Enable Routes Server |
| Setup script closes immediately | Windows blocked the script | Right-click `setup-revit-mcp.bat` > **Run as administrator** |
| "Could not install uv" | Firewall blocking downloads | Try connecting to a different network, or install uv manually from https://docs.astral.sh/uv/ |
| "Domain is not bound to your account" | Wrong ngrok domain pasted | Go to https://dashboard.ngrok.com/domains and copy your domain again |
| ngrok session limit reached | Another tunnel is running | Close other ngrok sessions at https://dashboard.ngrok.com/tunnels |
| "ngrok version too old" | ngrok < 3.20.0 | Run `ngrok update` in a terminal, or download latest from https://ngrok.com/download |
| ngrok shows help text instead of starting | Invalid ngrok config file | Run `ngrok config check` — if it shows errors, delete the config and re-run setup |
| Tools return errors in Cowork | Invalid family type names | Ask Claude to call `list_families` or `list_family_categories` first |

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
- **pyRevit** installed and loaded in Revit (see Step 0 above)
- **Windows 10/11**
- **Internet connection**

No Python, Git, or developer tools required — the setup script installs everything.

## Author

**Talal Ahmed**

## License

Apache-2.0 — See [LICENSE](LICENSE) for details.
