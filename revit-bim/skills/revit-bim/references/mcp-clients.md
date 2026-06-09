# Connecting Other AI Tools (MCP Clients)

The Revit MCP server is a **standard MCP server**. Any MCP-capable AI tool can use
it — Claude is the priority and is configured automatically by `setup-revit-mcp.ps1`;
the tools below are manual one-time snippets.

All local clients use the **same launch command** (stdio transport):

- **command:** `C:\path\to\revit-mcp-server\.venv\Scripts\python.exe`
- **args:** `["C:\path\to\revit-mcp-server\main.py"]`

Replace `C:\path\to\revit-mcp-server` with your actual server folder. Requirements are
identical for every client: Revit open with a project + pyRevit Routes enabled (port 48884).

---

## Claude Desktop / Cowork  (priority — auto-configured)

Written automatically by setup into `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "revit": {
      "command": "C:\\path\\to\\revit-mcp-server\\.venv\\Scripts\\python.exe",
      "args": ["C:\\path\\to\\revit-mcp-server\\main.py"]
    }
  }
}
```
Restart Claude Desktop after the file changes. No tunnel, no terminal.

## Claude Code (CLI)

`.mcp.json` in your project:

```json
{
  "mcpServers": {
    "revit": {
      "command": "C:\\path\\to\\revit-mcp-server\\.venv\\Scripts\\python.exe",
      "args": ["C:\\path\\to\\revit-mcp-server\\main.py"]
    }
  }
}
```

## Cursor

`.cursor/mcp.json` (project) or `%USERPROFILE%\.cursor\mcp.json` (global):

```json
{
  "mcpServers": {
    "revit": {
      "command": "C:\\path\\to\\revit-mcp-server\\.venv\\Scripts\\python.exe",
      "args": ["C:\\path\\to\\revit-mcp-server\\main.py"]
    }
  }
}
```

## Windsurf

`~\.codeium\windsurf\mcp_config.json`:

```json
{
  "mcpServers": {
    "revit": {
      "command": "C:\\path\\to\\revit-mcp-server\\.venv\\Scripts\\python.exe",
      "args": ["C:\\path\\to\\revit-mcp-server\\main.py"]
    }
  }
}
```

## Cline (VS Code extension)

Cline > MCP Servers > Configure (`cline_mcp_settings.json`):

```json
{
  "mcpServers": {
    "revit": {
      "command": "C:\\path\\to\\revit-mcp-server\\.venv\\Scripts\\python.exe",
      "args": ["C:\\path\\to\\revit-mcp-server\\main.py"]
    }
  }
}
```

## VS Code (native MCP / Copilot agent mode)

`.vscode/mcp.json`:

```json
{
  "servers": {
    "revit": {
      "type": "stdio",
      "command": "C:\\path\\to\\revit-mcp-server\\.venv\\Scripts\\python.exe",
      "args": ["C:\\path\\to\\revit-mcp-server\\main.py"]
    }
  }
}
```

---

## Remote / cloud clients (HTTP transport)

For clients that connect over the network (e.g. claude.ai web/phone, or a hosted
agent), run the server with an HTTP transport and expose it with a tunnel:

```powershell
# from the server folder
uv run main.py --http        # serves streamable-http on http://127.0.0.1:8000/mcp
```

Then point the client's custom connector at the public HTTPS URL of your tunnel
(`setup-web-mobile.ps1` automates the ngrok side for Claude on the web/phone).

> The server also supports `--sse` and `--combined` (both SSE and streamable-http).
