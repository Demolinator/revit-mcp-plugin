. "$PSScriptRoot\_assert.ps1"
. "$PSScriptRoot\..\lib\Enable-PyRevitRoutes.ps1"
$r = Enable-PyRevitRoutes -Port 48884
Write-Host "Result: ok=$($r.ok) method=$($r.method) msg=$($r.message)"
Assert ($null -ne $r -and $r -is [hashtable]) "returns a hashtable result"
Assert ($null -ne $r -and $r.ContainsKey('ok')) "returns a result with 'ok'"
Assert ($r.ContainsKey('method')) "reports method (cli|manual|already)"
Assert ($r.ContainsKey('message')) "returns a message"
# Live check: if Revit is open, Routes should answer.
try {
  $resp = Invoke-RestMethod "http://localhost:48884/revit_mcp/status/" -TimeoutSec 4
  Assert ($resp.health -eq 'healthy') "Routes reachable on 48884 (Revit open)"
} catch { Write-Host "  [SKIP] Revit not open; Routes liveness not checked" -ForegroundColor Yellow }
EndTests
