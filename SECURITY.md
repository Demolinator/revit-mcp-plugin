# Security Policy

## Threat model in brief

- The bundled MCP server drives Revit through **pyRevit Routes on
  `localhost:48884`, which has no authentication**. The `execute_revit_code`
  tool runs arbitrary IronPython in Revit by design.
- The setup scripts **edit your Claude Desktop config** (with a backup) and
  change pyRevit's Routes settings.
- The optional **web/mobile (ngrok)** path exposes the MCP server on a public
  URL. Anyone with that URL can control your Revit session while it runs.
  Keep the URL private and stop the tunnel when you're done.

## Reporting a vulnerability

**Please do not open a public issue for security problems.**

Email **talal.ahmed.work@proton.me** with a description, reproduction steps, and
any suggested fix. You should get an acknowledgement within a few days.
Vulnerabilities in the server itself can also be reported per
[revit-mcp-server's SECURITY.md](https://github.com/Demolinator/revit-mcp-server/blob/master/SECURITY.md).
