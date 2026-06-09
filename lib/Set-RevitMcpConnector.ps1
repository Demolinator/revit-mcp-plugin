function Set-RevitMcpConnector {
  param(
    [Parameter(Mandatory)] [string] $ConfigPath,
    [Parameter(Mandatory)] [string] $ServerDir,
    [string] $Name = "revit"
  )
  $py   = Join-Path $ServerDir ".venv\Scripts\python.exe"
  $main = Join-Path $ServerDir "main.py"

  if (Test-Path $ConfigPath) {
    $stamp = Get-Date -Format "yyyyMMddHHmmss"
    Copy-Item $ConfigPath "$ConfigPath.bak-$stamp" -Force
    $raw = Get-Content $ConfigPath -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { $obj = [pscustomobject]@{} }
    else { $obj = $raw | ConvertFrom-Json }
  } else {
    $obj = [pscustomobject]@{}
  }

  # Rebuild mcpServers as a hashtable so adding/overwriting a key is trivial
  # and re-runs never produce duplicates.
  $servers = @{}
  if (($obj.PSObject.Properties.Name -contains 'mcpServers') -and $obj.mcpServers) {
    foreach ($p in $obj.mcpServers.PSObject.Properties) { $servers[$p.Name] = $p.Value }
  }
  $servers[$Name] = [pscustomobject]@{ command = $py; args = @($main) }

  if ($obj.PSObject.Properties.Name -contains 'mcpServers') { $obj.mcpServers = $servers }
  else { $obj | Add-Member -NotePropertyName mcpServers -NotePropertyValue $servers }

  $json = $obj | ConvertTo-Json -Depth 12
  [System.IO.File]::WriteAllText($ConfigPath, $json, (New-Object System.Text.UTF8Encoding $false))
}
