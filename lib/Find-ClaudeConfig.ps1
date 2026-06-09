function Find-ClaudeConfig {
  # MSIX/Store build: config lives under the package's virtualized Roaming.
  $pkg = Get-AppxPackage -Name "*Claude*" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($pkg) {
    $fam = $pkg.PackageFamilyName
    $msix = Join-Path $env:LOCALAPPDATA "Packages\$fam\LocalCache\Roaming\Claude\claude_desktop_config.json"
    if (Test-Path (Split-Path $msix)) { return $msix }
  }
  # Standard installer build.
  $std = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"
  if (-not (Test-Path (Split-Path $std))) {
    New-Item -ItemType Directory -Path (Split-Path $std) -Force | Out-Null
  }
  return $std
}
