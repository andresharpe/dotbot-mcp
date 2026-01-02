# Test state-set tool

Write-Host "Testing state-set..." -ForegroundColor Cyan

# Import helpers
$coreHelpersPath = Join-Path $PSScriptRoot '..\..\core-helpers.psm1'
$stateHelpersPath = Join-Path $PSScriptRoot '..\..\state-helpers.psm1'
Import-Module $coreHelpersPath -Force -DisableNameChecking
Import-Module $stateHelpersPath -Force -DisableNameChecking

# Load script
. $PSScriptRoot\script.ps1

# Clean up test state if exists
$testStateDir = Join-Path $PSScriptRoot "..\..\..\..\.bot\state"
if (Test-Path $testStateDir) {
    Remove-Item $testStateDir -Recurse -Force
}

# Test 1: Auto-initialize state
Write-Host "`nTest 1: Auto-initialize state" -ForegroundColor Yellow
$result = Invoke-StateSet -Arguments @{
    patch = @{
        current_feature = "test-feature"
        phase = "spec"
    }
}
if ($result.status -eq 'ok' -and $result.data.changed -eq $true) {
    Write-Host "✓ PASS: State auto-initialized" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Should auto-initialize state" -ForegroundColor Red
    $result | ConvertTo-Json -Depth 10
}

# Test 2: Update existing state
Write-Host "`nTest 2: Update existing state" -ForegroundColor Yellow
$result = Invoke-StateSet -Arguments @{
    patch = @{
        phase = "tasks"
        current_task_id = "T001"
    }
    reason = "Test update"
}
if ($result.status -eq 'ok' -and $result.data.state.phase -eq 'tasks') {
    Write-Host "✓ PASS: State updated successfully" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Should update state" -ForegroundColor Red
    $result | ConvertTo-Json -Depth 10
}

# Test 3: No changes detection
Write-Host "`nTest 3: No changes detection" -ForegroundColor Yellow
$result = Invoke-StateSet -Arguments @{
    patch = @{
        phase = "tasks"
    }
}
if ($result.status -eq 'ok' -and $result.data.changed -eq $false) {
    Write-Host "✓ PASS: Detected no changes" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Should detect no changes" -ForegroundColor Red
    $result | ConvertTo-Json -Depth 10
}

# Test 4: Invalid phase validation
Write-Host "`nTest 4: Invalid phase validation" -ForegroundColor Yellow
$result = Invoke-StateSet -Arguments @{
    patch = @{
        phase = "invalid-phase"
    }
}
if ($result.status -eq 'error' -and $result.errors[0].code -eq 'INVALID_STATE') {
    Write-Host "✓ PASS: Validation rejected invalid phase" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Should reject invalid phase" -ForegroundColor Red
    $result | ConvertTo-Json -Depth 10
}

# Test 5: Invalid commit SHA validation
Write-Host "`nTest 5: Invalid commit SHA validation" -ForegroundColor Yellow
$result = Invoke-StateSet -Arguments @{
    patch = @{
        last_commit = "invalid-sha"
    }
}
if ($result.status -eq 'error' -and $result.errors[0].code -eq 'INVALID_STATE') {
    Write-Host "✓ PASS: Validation rejected invalid SHA" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Should reject invalid commit SHA" -ForegroundColor Red
    $result | ConvertTo-Json -Depth 10
}

# Test 6: Valid commit SHA
Write-Host "`nTest 6: Valid commit SHA" -ForegroundColor Yellow
$result = Invoke-StateSet -Arguments @{
    patch = @{
        last_commit = "abc1234"
    }
}
if ($result.status -eq 'ok' -and $result.data.state.last_commit -eq 'abc1234') {
    Write-Host "✓ PASS: Accepted valid commit SHA" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Should accept valid commit SHA" -ForegroundColor Red
    $result | ConvertTo-Json -Depth 10
}

# Test 7: Correlation ID
Write-Host "`nTest 7: Correlation ID support" -ForegroundColor Yellow
$result = Invoke-StateSet -Arguments @{
    patch = @{
        phase = "implement"
    }
    correlation_id = "test-correlation-123"
    reason = "Test with correlation"
}
if ($result.status -eq 'ok' -and $result.data.changed -eq $true) {
    Write-Host "✓ PASS: Correlation ID accepted" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Should accept correlation ID" -ForegroundColor Red
    $result | ConvertTo-Json -Depth 10
}

# Clean up
if (Test-Path $testStateDir) {
    Remove-Item $testStateDir -Recurse -Force
}

Write-Host "`n✓ All tests complete" -ForegroundColor Green
Write-Host "Note: Full integration tests will be run in Phase 7" -ForegroundColor Gray
