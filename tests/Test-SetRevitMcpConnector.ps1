. "$PSScriptRoot\_assert.ps1"
. "$PSScriptRoot\..\lib\Set-RevitMcpConnector.ps1"

$tmp = Join-Path $env:TEMP "rmc_test_config.json"
'{ "preferences": { "keep": "me" } }' | Set-Content $tmp -Encoding UTF8

$server = "C:\fake\server"
Set-RevitMcpConnector -ConfigPath $tmp -ServerDir $server

$j = Get-Content $tmp -Raw | ConvertFrom-Json
Assert ($null -ne $j.mcpServers.revit) "revit server added"
Assert ($j.mcpServers.revit.command -like "*python.exe") "command points to python"
AssertEq $j.preferences.keep "me" "existing preferences preserved"
Assert ((Get-ChildItem "$($tmp).bak-*" -ErrorAction SilentlyContinue).Count -ge 1) "backup created"

# Idempotency: run again, must not duplicate or error
Set-RevitMcpConnector -ConfigPath $tmp -ServerDir $server
$j2 = Get-Content $tmp -Raw | ConvertFrom-Json
Assert ($null -ne $j2.mcpServers.revit) "still present after re-run"
AssertEq @($j2.mcpServers.PSObject.Properties.Name).Count 1 "no duplicate server keys"

Remove-Item $tmp -Force -ErrorAction SilentlyContinue
Get-ChildItem "$($tmp).bak-*" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
EndTests
