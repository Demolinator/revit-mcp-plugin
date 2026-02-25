# Connectors

## ~~revit

The Revit MCP Server connects Claude to Autodesk Revit 2024/2025/2026 via the Model Context Protocol. It provides 45 tools for building design, model editing, structural systems, MEP, documentation, and analysis.

**Connection**: Uses a permanent ngrok tunnel. Run `start-revit-mcp.bat` on your machine before using Cowork.

## Connection Flow

```
Claude Cowork --> HTTPS (ngrok tunnel) --> MCP Server (localhost:8000) --> pyRevit Routes (:48884) --> Revit API
```

## Prerequisites

- **Autodesk Revit 2024/2025/2026** installed and running with a project open
- **pyRevit** installed and loaded (provides Routes on port 48884)
- **start-revit-mcp.bat** running on your machine (starts MCP server + tunnel)

## Setup

1. Run `setup-revit-mcp.bat` once (installs dependencies, configures tunnel, generates this plugin)
2. Run `start-revit-mcp.bat` before each Cowork session

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| "Failed to connect to Revit" | Start script not running | Run `start-revit-mcp.bat` |
| "No active Revit document" | Revit not open or no project | Open Revit with a project file |
| "Connection refused on 48884" | pyRevit Routes not active | Check pyRevit is installed (pyRevit tab in Revit ribbon) |
| Tools return errors | Invalid family type names | Call `list_families` or `list_family_categories` first |
| Tunnel URL not working | ngrok session expired | Restart `start-revit-mcp.bat` |
