# Test state-get tool

Write-Host "Testing state-get..." -ForegroundColor Cyan

# Load script
. $PSScriptRoot\script.ps1

# Test 1: State not initialized
Write-Host "`nTest 1: State not initialized" -ForegroundColor Yellow
$result = Invoke-StateGet -Arguments @{}
if ($result.status -eq 'error' -and $result.errors[0].code -eq 'STATE_NOT_INITIALIZED') {
    Write-Host "✓ PASS: Returns STATE_NOT_INITIALIZED when state missing" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Should return STATE_NOT_INITIALIZED" -ForegroundColor Red
}

Write-Host "`n✓ Basic tests complete" -ForegroundColor Green
Write-Host "Note: Full integration tests will be run in Phase 7" -ForegroundColor Gray
