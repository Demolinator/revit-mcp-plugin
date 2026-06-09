# Minimal assertion helper for setup tests. Dot-source it, then use Assert/AssertEq.
$script:Failures = 0
function Assert($cond, $msg) {
  if ($cond) { Write-Host "  [PASS] $msg" -ForegroundColor Green }
  else { Write-Host "  [FAIL] $msg" -ForegroundColor Red; $script:Failures++ }
}
function AssertEq($actual, $expected, $msg) {
  Assert ($actual -eq $expected) "$msg (expected '$expected', got '$actual')"
}
function EndTests {
  if ($script:Failures -gt 0) { Write-Host "FAILED: $script:Failures" -ForegroundColor Red; exit 1 }
  Write-Host "ALL PASSED" -ForegroundColor Green; exit 0
}
