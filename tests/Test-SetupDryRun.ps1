. "$PSScriptRoot\_assert.ps1"
$setup = "$PSScriptRoot\..\setup-revit-mcp.ps1"
Assert (Test-Path $setup) "setup-revit-mcp.ps1 exists"
$out = & powershell -ExecutionPolicy Bypass -File $setup -DryRun -ServerDir "C:\fake\server" 2>&1 | Out-String
Write-Host $out
Assert ($out -match "config path|Find-ClaudeConfig|claude_desktop_config") "reports config path step"
Assert ($out -match "pyRevit Routes") "reports pyRevit step"
Assert ($out -match "mcpServers|connector") "reports connector write step"
Assert ($out -notmatch "auth token") "ngrok auth token NOT in default path"
Assert ($out -match "DRY RUN|Dry run|would") "indicates dry-run (no changes made)"
EndTests
