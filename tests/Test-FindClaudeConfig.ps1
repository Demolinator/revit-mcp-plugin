. "$PSScriptRoot\_assert.ps1"
. "$PSScriptRoot\..\lib\Find-ClaudeConfig.ps1"
$p = Find-ClaudeConfig
Write-Host "Resolved: $p"
Assert ($null -ne $p) "returns a path"
Assert ($p -like "*claude_desktop_config.json") "path ends in claude_desktop_config.json"
Assert (Test-Path (Split-Path $p)) "parent directory exists"
EndTests
