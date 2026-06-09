function Find-PyRevitCli {
  # pyRevit CLI is often NOT on PATH; check PATH then known install locations.
  $onPath = (Get-Command pyrevit -ErrorAction SilentlyContinue).Source
  if ($onPath) { return $onPath }
  $cands = @(
    "$env:APPDATA\pyRevit-Master\bin\pyrevit.exe",
    "$env:PROGRAMFILES\pyRevit-Master\bin\pyrevit.exe",
    "$env:PROGRAMFILES\pyRevit CLI\bin\pyrevit.exe",
    "${env:ProgramFiles(x86)}\pyRevit CLI\bin\pyrevit.exe",
    "$env:LOCALAPPDATA\pyRevit-Master\bin\pyrevit.exe"
  )
  foreach ($c in $cands) { if (Test-Path $c) { return $c } }
  return $null
}

function Enable-PyRevitRoutes {
  param([int] $Port = 48884)

  $cli = Find-PyRevitCli
  if (-not $cli) {
    return @{ ok = $false; method = 'manual'; message =
      "pyRevit CLI not found. Enable manually: pyRevit tab > Settings > Routes > Enable Routes Server (port $Port) > Save Settings, then restart Revit." }
  }

  # pyRevit writes to stderr; under a caller's ErrorActionPreference=Stop that
  # would be raised as a fatal NativeCommandError. Drop to Continue for the
  # native calls so this function behaves the same regardless of caller state.
  $prevEAP = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try {
    # Persistent config settings; once enabled, Routes loads with Revit.
    & $cli configs routes port $Port | Out-Null
    & $cli configs routes enable | Out-Null

    # Confirm the config now reports Enabled.
    $status = (& $cli configs routes | Out-String)
    if ($status -match 'Enabled') {
      return @{ ok = $true; method = 'cli'; message = "Routes enabled on port $Port (restart Revit to apply if it was off)." }
    }
    return @{ ok = $true; method = 'cli'; message = "Routes configured on port $Port; verify in pyRevit > Settings > Routes." }
  } catch {
    return @{ ok = $false; method = 'manual'; message =
      "pyRevit CLI call failed: $($_.Exception.Message). Enable manually via pyRevit > Settings > Routes." }
  } finally {
    $ErrorActionPreference = $prevEAP
  }
}
